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
	
	let schedulerManager: SchedulerManager
	let appMonitor: AppMonitor
	let launchAtLoginManager: LaunchAtLoginManager
	private let sleepManager: SleepManaging
	private let notificationSender: NotificationSending
	private let startsCountdownTimers: Bool
	private let defaults: UserDefaults
	private let now: () -> ContinuousClock.Instant
	private var countdownDeadline: ContinuousClock.Instant?
	private var timerCancellable: AnyCancellable?
	private var cancellables = Set<AnyCancellable>()
	private var manualTimerActive = false

	private enum DefaultsKey {
		static let letsDisplayTurnOff = "letsDisplayTurnOff"
	}
	
	convenience init() {
		self.init(
			schedulerManager: SchedulerManager(),
			appMonitor: AppMonitor(),
			launchAtLoginManager: LaunchAtLoginManager(),
			sleepManager: SleepManager(),
			notificationSender: NotificationManager.shared,
			startsCountdownTimers: true
		)
	}
	
	init(
		schedulerManager: SchedulerManager,
		appMonitor: AppMonitor,
		launchAtLoginManager: LaunchAtLoginManager,
		sleepManager: SleepManaging,
		notificationSender: NotificationSending,
		startsCountdownTimers: Bool,
		defaults: UserDefaults = .standard,
		now: @escaping () -> ContinuousClock.Instant = { ContinuousClock.now }
	) {
		self.schedulerManager = schedulerManager
		self.appMonitor = appMonitor
		self.launchAtLoginManager = launchAtLoginManager
		self.sleepManager = sleepManager
		self.notificationSender = notificationSender
		self.startsCountdownTimers = startsCountdownTimers
		self.defaults = defaults
		self.now = now
		letsDisplayTurnOff = defaults.bool(forKey: DefaultsKey.letsDisplayTurnOff)
		
		schedulerManager.$isActive
			.combineLatest(appMonitor.$isActive)
			.sink { [weak self] isScheduleActive, isAppActive in
				// `@Published` emits before the new value is stored, so use the emitted values instead of reading the managers.
				// The status text also depends on which source is active, so publish even when `isActive` itself doesn't change.
				self?.objectWillChange.send()
				self?.updateSleepState(isScheduleActive: isScheduleActive, isAppActive: isAppActive)
			}
			.store(in: &cancellables)
	}
	
	var canStop: Bool {
		manualTimerActive
	}
	
	var statusText: String {
		guard isActive else { return L10n.string("Inactive") }
		
		return remainingSeconds.map(formattedStatusTime) ?? nonTimedStatusText
	}
	
	func start(duration: TimerDuration) {
		let seconds = duration.seconds

		resetTimer()
		manualTimerActive = true
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
	
	private func updateSleepState(
		forceRefresh: Bool = false,
		isScheduleActive: Bool? = nil,
		isAppActive: Bool? = nil
	) {
		let shouldBeActive = manualTimerActive
			|| (isScheduleActive ?? schedulerManager.isActive)
			|| (isAppActive ?? appMonitor.isActive)
		
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
		if schedulerManager.isActive {
			return L10n.string("Scheduled run")
		}
		
		if appMonitor.isActive {
			return L10n.string("App running")
		}
		
		return L10n.string("Forever")
	}

	private var sleepDisplayBehavior: SleepDisplayBehavior {
		letsDisplayTurnOff ? .allowDisplayOff : .keepDisplayAwake
	}
	
	private func formattedStatusTime(_ remaining: TimeInterval) -> String {
		let mins = Int(remaining) / 60
		let secs = Int(remaining) % 60
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
