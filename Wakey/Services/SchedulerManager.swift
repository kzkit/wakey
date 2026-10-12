//
//  SchedulerManager.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import Foundation
import AppKit
import Combine

@MainActor
final class SchedulerManager: ObservableObject {
	@Published private(set) var isActive = false
	
	private enum DefaultsKey {
		static let schedule = "schedule"
	}
	
	private var schedule: Schedule
	private var timerCancellable: AnyCancellable?
	private var cancellables = Set<AnyCancellable>()
	private let defaults: UserDefaults
	private let dateProvider: () -> Date
	
	convenience init() {
		self.init(defaults: .standard, dateProvider: Date.init, startsMonitoring: true)
	}
	
	init(
		defaults: UserDefaults,
		dateProvider: @escaping () -> Date,
		startsMonitoring: Bool
	) {
		self.defaults = defaults
		self.dateProvider = dateProvider
		schedule = Self.loadSchedule(from: defaults)
		
		checkSchedule()
		if startsMonitoring {
			startMonitoring()
		}
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
		startAlignedTimer()
		
		// A timer keeps its old phase across sleep and clock or time zone changes, so re-check and re-align after each.
		NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)
			.merge(with:
				NotificationCenter.default.publisher(for: .NSSystemClockDidChange),
				NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)
			)
			.receive(on: DispatchQueue.main)
			.sink { [weak self] _ in
				self?.checkSchedule()
				self?.startAlignedTimer()
			}
			.store(in: &cancellables)
	}
	
	private func startAlignedTimer() {
		// Align the 60 s check to the start of each minute so a schedule starts or ends within about a second of its minute.
		timerCancellable = Just(())
			.delay(for: .seconds(Self.delayUntilNextMinute(from: dateProvider())), scheduler: DispatchQueue.main)
			.flatMap { _ in
				Timer.publish(every: 60, on: .main, in: .common)
					.autoconnect()
					.map { _ in }
					.prepend(())
			}
			.sink { [weak self] in
				self?.checkSchedule()
			}
	}
	
	/// Seconds until just after the next wall-clock minute starts.
	static func delayUntilNextMinute(from date: Date) -> TimeInterval {
		let secondsIntoMinute = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 60)
		return 60 - secondsIntoMinute + 0.5
	}
	
	private func checkSchedule() {
		let isActive = schedule.isWithinSchedule(at: dateProvider())
		if self.isActive != isActive {
			self.isActive = isActive
		}
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
