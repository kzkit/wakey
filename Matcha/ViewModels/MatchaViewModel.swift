//
//  MatchaViewModel.swift
//  Matcha
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import Foundation
import Combine

@MainActor
final class MatchaViewModel: ObservableObject {
	@Published private(set) var isActive = false
	@Published private(set) var remainingSeconds: TimeInterval?
	
	let scheduleManager = ScheduleManager()
	let appMonitor = AppMonitor()
	private let sleepManager = SleepManager()
	private var timerCancellable: AnyCancellable?
	private var cancellables = Set<AnyCancellable>()
	private var manualTimerActive = false
	
	init() {
		scheduleManager.$isActive
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
		guard isActive else { return "Inactive" }
		
		if let remaining = remainingSeconds {
			let mins = Int(remaining) / 60
			let secs = Int(remaining) % 60
			return String(format: "%d:%02d", mins, secs)
		}
		
		if scheduleManager.isActive {
			return "Active (Schedule)"
		}
		
		if appMonitor.isActive {
			return "Active (App)"
		}
		
		return "Forever"
	}
	
	func start(duration: TimerDuration) {
		manualTimerActive = true
		remainingSeconds = duration.seconds
		
		if duration.seconds != nil {
			timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
				.autoconnect()
				.sink { [weak self] _ in
					self?.tick()
				}
		}
		
		updateSleepState()
	}
	
	func stop() {
		timerCancellable?.cancel()
		timerCancellable = nil
		manualTimerActive = false
		remainingSeconds = nil
		updateSleepState()
	}
	
	private func tick() {
		guard let remaining = remainingSeconds else { return }
		
		if remaining <= 1 {
			NotificationManager.shared.sendTimerEndedNotification()
			stop()
		} else {
			remainingSeconds = remaining - 1
		}
	}
	
	func refreshState() {
		updateSleepState()
	}
	
	private func updateSleepState() {
		let shouldBeActive = manualTimerActive || scheduleManager.isActive || appMonitor.isActive
		
		if shouldBeActive && !sleepManager.isActive {
			_ = sleepManager.preventSleep()
		} else if !shouldBeActive && sleepManager.isActive {
			sleepManager.allowSleep()
		}
		
		isActive = shouldBeActive
	}
}

