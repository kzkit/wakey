//
//  SchedulerManager.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import Foundation
import Combine

@MainActor
final class SchedulerManager: ObservableObject {
	@Published private(set) var isActive = false
	
	private enum DefaultsKey {
		static let schedule = "schedule"
	}
	
	private var schedule: Schedule
	private var timerCancellable: AnyCancellable?
	private let defaults = UserDefaults.standard
	
	init() {
		schedule = Self.loadSchedule(from: defaults)
		
		checkSchedule()
		startMonitoring()
	}
	
	var currentSchedule: Schedule {
		schedule
	}
	
	func updateSchedule(_ newSchedule: Schedule) {
		schedule = newSchedule
		saveSchedule(schedule)
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
	
	private static func loadSchedule(from defaults: UserDefaults) -> Schedule {
		guard let data = defaults.data(forKey: DefaultsKey.schedule),
					let decoded = try? JSONDecoder().decode(Schedule.self, from: data) else {
			return .default
		}
		
		return decoded
	}
	
	private func saveSchedule(_ schedule: Schedule) {
		guard let encoded = try? JSONEncoder().encode(schedule) else {
			return
		}
		
		defaults.set(encoded, forKey: DefaultsKey.schedule)
	}
}
