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
		defaults: UserDefaults = .standard
	) {
		self.schedulerManager = schedulerManager
		self.appMonitor = appMonitor
		self.launchAtLoginManager = launchAtLoginManager
		self.sleepManager = sleepManager
		self.notificationSender = notificationSender
		self.startsCountdownTimers = startsCountdownTimers
		self.defaults = defaults
		letsDisplayTurnOff = defaults.bool(forKey: DefaultsKey.letsDisplayTurnOff)
		
		schedulerManager.$isActive
			.combineLatest(appMonitor.$isActive)
			.sink { [weak self] _, _ in
				self?.updateSleepState()
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
		remainingSeconds = seconds
		
		if seconds != nil && startsCountdownTimers {
			startCountdownTimer()
		}
		
		updateSleepState()
	}
	
	func stop() {
		resetTimer()
		manualTimerActive = false
		remainingSeconds = nil
		updateSleepState()
	}
	
	private func tick() {
		guard let remaining = remainingSeconds else { return }
		
		if remaining <= 1 {
			notificationSender.sendTimerEndedNotification()
			stop()
		} else {
			remainingSeconds = remaining - 1
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
	
	private func updateSleepState(forceRefresh: Bool = false) {
		let shouldBeActive = manualTimerActive || schedulerManager.isActive || appMonitor.isActive
		
		if shouldBeActive {
			if sleepManager.isActive && forceRefresh {
				sleepManager.allowSleep()
			}
			if !sleepManager.isActive {
				_ = sleepManager.preventSleep(displayBehavior: sleepDisplayBehavior)
			}
		} else if !shouldBeActive && sleepManager.isActive {
			sleepManager.allowSleep()
		}
		
		isActive = shouldBeActive
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
