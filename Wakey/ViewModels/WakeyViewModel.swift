//
//  WakeyViewModel.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import Foundation
import Combine

@MainActor
final class WakeyViewModel: ObservableObject {
	@Published private(set) var isActive = false
	@Published private(set) var remainingSeconds: TimeInterval?
	@Published private(set) var letsDisplayTurnOff: Bool
	@Published private(set) var isBatteryGuardEnabled: Bool
	@Published private(set) var batteryGuardThreshold: Int
	/// Prefills the custom duration editor with the last custom length the user started.
	@Published private(set) var lastCustomMinutes: Int
	
	let schedulerManager: SchedulerManager
	let appMonitor: AppMonitor
	let launchAtLoginManager: LaunchAtLoginManager
	let batteryMonitor: BatteryMonitor
	private let sleepManager: SleepManaging
	private let notificationSender: NotificationSending
	private let startsCountdownTimers: Bool
	private let defaults: UserDefaults
	private let now: () -> ContinuousClock.Instant
	private var countdownDeadline: ContinuousClock.Instant?
	private var timerCancellable: AnyCancellable?
	private var cancellables = Set<AnyCancellable>()
	private var manualTimerActive = false
	private var batteryState: BatteryState
	/// Set when the user started (or kept) a manual session while the battery guard already applied.
	private var manualSessionIgnoresBatteryGuard = false

	private enum DefaultsKey {
		static let letsDisplayTurnOff = "letsDisplayTurnOff"
		static let batteryGuardEnabled = "batteryGuardEnabled"
		static let batteryGuardThreshold = "batteryGuardThreshold"
		static let lastCustomMinutes = "lastCustomMinutes"
	}
	
	static let defaultCustomMinutes = 45
	
	convenience init() {
		self.init(
			schedulerManager: SchedulerManager(),
			appMonitor: AppMonitor(),
			launchAtLoginManager: LaunchAtLoginManager(),
			batteryMonitor: BatteryMonitor(),
			sleepManager: SleepManager(),
			notificationSender: NotificationManager.shared,
			startsCountdownTimers: true
		)
	}
	
	init(
		schedulerManager: SchedulerManager,
		appMonitor: AppMonitor,
		launchAtLoginManager: LaunchAtLoginManager,
		batteryMonitor: BatteryMonitor,
		sleepManager: SleepManaging,
		notificationSender: NotificationSending,
		startsCountdownTimers: Bool,
		defaults: UserDefaults = .standard,
		now: @escaping () -> ContinuousClock.Instant = { ContinuousClock.now }
	) {
		self.schedulerManager = schedulerManager
		self.appMonitor = appMonitor
		self.launchAtLoginManager = launchAtLoginManager
		self.batteryMonitor = batteryMonitor
		self.sleepManager = sleepManager
		self.notificationSender = notificationSender
		self.startsCountdownTimers = startsCountdownTimers
		self.defaults = defaults
		self.now = now
		letsDisplayTurnOff = defaults.bool(forKey: DefaultsKey.letsDisplayTurnOff)
		isBatteryGuardEnabled = defaults.bool(forKey: DefaultsKey.batteryGuardEnabled)
		let savedThreshold = defaults.integer(forKey: DefaultsKey.batteryGuardThreshold)
		batteryGuardThreshold = BatteryGuard.thresholdOptions.contains(savedThreshold) ? savedThreshold : BatteryGuard.defaultThreshold
		batteryState = batteryMonitor.state
		let storedCustomMinutes = defaults.integer(forKey: DefaultsKey.lastCustomMinutes)
		lastCustomMinutes = TimerDuration.customMinutesRange.contains(storedCustomMinutes)
			? storedCustomMinutes
			: Self.defaultCustomMinutes
		
		schedulerManager.$isActive
			.combineLatest(appMonitor.$isActive)
			.sink { [weak self] isScheduleActive, isAppActive in
				// `@Published` emits before the new value is stored, so use the emitted values instead of reading the managers.
				// The status text also depends on which source is active, so publish even when `isActive` itself doesn't change.
				self?.objectWillChange.send()
				self?.updateSleepState(isScheduleActive: isScheduleActive, isAppActive: isAppActive)
			}
			.store(in: &cancellables)
		
		batteryMonitor.$state
			.dropFirst()
			.sink { [weak self] state in
				self?.batteryStateDidChange(state)
			}
			.store(in: &cancellables)
	}
	
	var canStop: Bool {
		manualTimerActive
	}
	
	/// Why the battery guard currently stops automatic triggers, or `nil` when it doesn't apply.
	var batteryGuardReason: BatteryGuardReason? {
		guard isBatteryGuardEnabled else { return nil }
		
		return BatteryGuard.lowBatteryReason(for: batteryState, threshold: batteryGuardThreshold)
	}
	
	/// A manual start should ask before overriding the guard. Any start made while this is true is exempt from the guard,
	/// so the menu checks it first and only calls `start` once the user confirms.
	var needsBatteryConfirmation: Bool {
		batteryGuardReason != nil
	}
	
	/// The schedule or a watched app would keep the Mac awake, but the battery guard is holding them back.
	var isPausedForLowBattery: Bool {
		batteryGuardReason != nil && (schedulerManager.isActive || appMonitor.isActive)
	}
	
	/// The Mac has a battery, so the battery guard setting is relevant.
	var hasBattery: Bool {
		batteryState.hasBattery
	}
	
	var statusText: String {
		guard isActive else { return L10n.string("Inactive") }
		
		return remainingSeconds.map(formattedStatusTime) ?? nonTimedStatusText
	}
	
	/// The single entry point for manual sessions, whether started from a preset, a custom duration, or `forever`.
	func start(duration: TimerDuration) {
		let seconds = duration.seconds
		
		// A zero or negative countdown would end immediately, so treat it as a no-op rather than starting a session.
		if let seconds, seconds <= 0 {
			return
		}

		resetTimer()
		manualTimerActive = true
		manualSessionIgnoresBatteryGuard = needsBatteryConfirmation
		countdownDeadline = seconds.map { now().advanced(by: .seconds($0)) }
		remainingSeconds = seconds
		
		if seconds != nil && startsCountdownTimers {
			startCountdownTimer()
		}
		
		updateSleepState()
		
		// The sleep assertion couldn't be created, so don't leave a session running that does nothing.
		if !sleepManager.isActive {
			stop()
		}
	}
	
	func stop() {
		resetTimer()
		manualTimerActive = false
		manualSessionIgnoresBatteryGuard = false
		countdownDeadline = nil
		remainingSeconds = nil
		updateSleepState()
	}
	
	/// Derives the remaining time from `ContinuousClock`, which keeps counting through sleep and ignores system clock changes,
	/// so throttled timers, a manual sleep, or a clock adjustment can't shift the countdown.
	private func tick() {
		guard let countdownDeadline else { return }
		
		let remaining = (countdownDeadline - now()).timeInterval.rounded(.up)
		
		if remaining <= 0 {
			stop()
			notificationSender.sendTimerEndedNotification(isStillAwake: isActive)
		} else if remainingSeconds != remaining {
			remainingSeconds = remaining
		}
	}
	
	func advanceCountdownForTesting() {
		tick()
	}
	
	func refreshState() {
		updateSleepState()
	}

	func setLetsDisplayTurnOff(_ letsDisplayTurnOff: Bool) {
		guard self.letsDisplayTurnOff != letsDisplayTurnOff else { return }

		self.letsDisplayTurnOff = letsDisplayTurnOff
		defaults.set(letsDisplayTurnOff, forKey: DefaultsKey.letsDisplayTurnOff)
		updateSleepState(forceRefresh: true)
	}
	
	func setBatteryGuardEnabled(_ isEnabled: Bool) {
		guard isBatteryGuardEnabled != isEnabled else { return }
		
		isBatteryGuardEnabled = isEnabled
		defaults.set(isEnabled, forKey: DefaultsKey.batteryGuardEnabled)
		batteryGuardSettingsDidChange()
	}
	
	func setBatteryGuardThreshold(_ threshold: Int) {
		guard batteryGuardThreshold != threshold, BatteryGuard.thresholdOptions.contains(threshold) else { return }
		
		batteryGuardThreshold = threshold
		defaults.set(threshold, forKey: DefaultsKey.batteryGuardThreshold)
		batteryGuardSettingsDidChange()
	}
	
	/// Changing a setting never stops a running manual session; if the guard now applies, that session is treated as confirmed.
	private func batteryGuardSettingsDidChange() {
		if manualTimerActive && needsBatteryConfirmation {
			manualSessionIgnoresBatteryGuard = true
		}
		updateSleepState()
	}
	
	private func batteryStateDidChange(_ state: BatteryState) {
		guard batteryState != state else { return }
		
		// `@Published` emits before the new value is stored, so keep our own copy of the emitted state.
		objectWillChange.send()
		let wasLowBattery = BatteryGuard.lowBatteryReason(for: batteryState, threshold: batteryGuardThreshold) != nil
		batteryState = state
		
		// Only the moment the battery becomes low stops a manual session; plugging back in doesn't restart it.
		if !wasLowBattery,
			 let reason = batteryGuardReason,
			 manualTimerActive,
			 !manualSessionIgnoresBatteryGuard {
			stop()
			notificationSender.sendBatteryGuardStoppedNotification(reason: reason)
			return
		}
		
		updateSleepState()
	}
	
	func setLastCustomMinutes(_ minutes: Int) {
		guard TimerDuration.customMinutesRange.contains(minutes), lastCustomMinutes != minutes else { return }
		
		lastCustomMinutes = minutes
		defaults.set(minutes, forKey: DefaultsKey.lastCustomMinutes)
	}
	
	private func updateSleepState(
		forceRefresh: Bool = false,
		isScheduleActive: Bool? = nil,
		isAppActive: Bool? = nil
	) {
		let isAutomaticTriggerActive = (isScheduleActive ?? schedulerManager.isActive)
			|| (isAppActive ?? appMonitor.isActive)
		let shouldBeActive = manualTimerActive
			|| (isAutomaticTriggerActive && batteryGuardReason == nil)
		
		if shouldBeActive {
			if sleepManager.isActive && forceRefresh {
				sleepManager.allowSleep()
			}
			if !sleepManager.isActive {
				_ = sleepManager.preventSleep(displayBehavior: sleepDisplayBehavior)
			}
		} else if sleepManager.isActive {
			sleepManager.allowSleep()
		}
		
		let isActive = shouldBeActive && sleepManager.isActive
		if self.isActive != isActive {
			self.isActive = isActive
		}
	}
	
	private var nonTimedStatusText: String {
		let areAutomaticTriggersAllowed = batteryGuardReason == nil
		
		if areAutomaticTriggersAllowed && schedulerManager.isActive {
			return L10n.string("Scheduled run")
		}
		
		if areAutomaticTriggersAllowed && appMonitor.isActive {
			return L10n.string("App running")
		}
		
		return L10n.string("Forever")
	}

	private var sleepDisplayBehavior: SleepDisplayBehavior {
		letsDisplayTurnOff ? .allowDisplayOff : .keepDisplayAwake
	}
	
	/// Shows `h:mm:ss` while an hour or more remains, `m:ss` otherwise.
	private func formattedStatusTime(_ remaining: TimeInterval) -> String {
		let totalSeconds = Int(remaining)
		let hours = totalSeconds / 3600
		let mins = totalSeconds % 3600 / 60
		let secs = totalSeconds % 60
		
		if hours > 0 {
			return String(format: "%d:%02d:%02d", hours, mins, secs)
		}
		
		return String(format: "%d:%02d", mins, secs)
	}
	
	private func startCountdownTimer() {
		timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
			.autoconnect()
			.sink { [weak self] _ in
				self?.tick()
			}
	}
	
	private func resetTimer() {
		timerCancellable?.cancel()
		timerCancellable = nil
	}
}

private extension Duration {
	var timeInterval: TimeInterval {
		let (seconds, attoseconds) = components
		return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
	}
}
