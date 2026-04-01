//
//  SchedulerManager.swift
//  Matcha
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import Foundation
import Combine

@MainActor
final class ScheduleManager: ObservableObject {
	@Published private(set) var isActive = false
	
	private enum DefaultsKey {
		static let schedule = "schedule"
	}
	
	private var schedule: Schedule
	private var timerCancellable: AnyCancellable?
	private let defaults = UserDefaults.standard
	
	init() {
		if let data = defaults.data(forKey: DefaultsKey.schedule),
			 let decoded = try? JSONDecoder().decode(Schedule.self, from: data) {
			schedule = decoded
		} else {
			schedule = .default
		}
		
		checkSchedule()
		startMonitoring()
	}
	
	var currentSchedule: Schedule {
		schedule
	}
	
	func updateSchedule(_ newSchedule: Schedule) {
		schedule = newSchedule
		if let encoded = try? JSONEncoder().encode(schedule) {
			defaults.set(encoded, forKey: DefaultsKey.schedule)
		}
		checkSchedule()
	}
	
	private func startMonitoring() {
		timerCancellable = Timer.publish(every: 60, on: .main, in: .common)
			.autoconnect()
			.sink { [weak self] _ in
				self?.checkSchedule()
			}
	}
	
	private func checkSchedule() {
		isActive = schedule.isWithinSchedule()
	}
}
