//
//  Schedule.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import Foundation

struct Schedule: Equatable {
	static let minutesPerDay = 24 * 60
	/// `Calendar` weekday numbers: 1 = Sunday … 7 = Saturday.
	static let allWeekdays: Set<Int> = Set(1...7)
	static let workWeekdays: Set<Int> = Set(2...6)
	
	var isEnabled: Bool
	/// Minutes since midnight.
	var startMinute: Int
	/// Minutes since midnight. A window ending at or before its start runs past midnight; start == end means a full 24 hours.
	var endMinute: Int
	/// Days the window starts on. Overnight windows belong to the day they start.
	var weekdays: Set<Int>
	
	static let `default` = Schedule(isEnabled: false, startHour: 9, endHour: 17, weekdays: workWeekdays)
	
	/// `weekdays` defaults to every day, matching schedules saved before weekdays existed.
	init(isEnabled: Bool, startMinute: Int, endMinute: Int, weekdays: Set<Int> = Schedule.allWeekdays) {
		self.isEnabled = isEnabled
		self.startMinute = startMinute
		self.endMinute = endMinute
		self.weekdays = weekdays
	}
	
	init(isEnabled: Bool, startHour: Int, endHour: Int, weekdays: Set<Int> = Schedule.allWeekdays) {
		self.init(isEnabled: isEnabled, startMinute: startHour * 60, endMinute: endHour * 60, weekdays: weekdays)
	}
	
	/// The time zone time-of-day pickers work in. UTC has no daylight-saving gaps, so every minute of the day
	/// round-trips through `timeOfDayDate(forMinute:)` and `minute(ofTimeOfDay:)`.
	static let timeOfDayTimeZone = TimeZone(identifier: "UTC")!
	
	/// A date whose time of day, in `timeOfDayTimeZone`, is `minute` minutes past midnight.
	static func timeOfDayDate(forMinute minute: Int) -> Date {
		Date(timeIntervalSinceReferenceDate: TimeInterval(minute * 60))
	}
	
	/// Minutes since midnight of `date`'s time of day in `timeOfDayTimeZone`.
	static func minute(ofTimeOfDay date: Date) -> Int {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = timeOfDayTimeZone
		let components = calendar.dateComponents([.hour, .minute], from: date)
		return (components.hour ?? 0) * 60 + (components.minute ?? 0)
	}
	
	/// Weekday numbers in display order, starting from the calendar's first weekday.
	static func orderedWeekdays(firstWeekday: Int) -> [Int] {
		(0..<7).map { (firstWeekday - 1 + $0) % 7 + 1 }
	}
	
	func isWithinSchedule(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
		guard isEnabled else { return false }
		
		let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
		guard let weekday = components.weekday else { return false }
		let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
		let previousWeekday = (weekday + 5) % 7 + 1
		
		if startMinute < endMinute {
			return weekdays.contains(weekday) && minute >= startMinute && minute < endMinute
		} else {
			// Runs past midnight: the early-morning part belongs to the previous day's window.
			return (weekdays.contains(weekday) && minute >= startMinute)
				|| (weekdays.contains(previousWeekday) && minute < endMinute)
		}
	}
}

extension Schedule: Codable {
	private enum CodingKeys: String, CodingKey {
		case isEnabled
		case startMinute
		case endMinute
		case weekdays
		// Read-only: written by earlier versions, which had whole hours and no weekdays.
		case startHour
		case endHour
	}
	
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
		
		if let startMinute = try container.decodeIfPresent(Int.self, forKey: .startMinute) {
			self.startMinute = startMinute
		} else {
			startMinute = try container.decode(Int.self, forKey: .startHour) * 60
		}
		
		if let endMinute = try container.decodeIfPresent(Int.self, forKey: .endMinute) {
			self.endMinute = endMinute
		} else {
			endMinute = try container.decode(Int.self, forKey: .endHour) * 60
		}
		
		weekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .weekdays) ?? Self.allWeekdays
	}
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(isEnabled, forKey: .isEnabled)
		try container.encode(startMinute, forKey: .startMinute)
		try container.encode(endMinute, forKey: .endMinute)
		try container.encode(weekdays.sorted(), forKey: .weekdays)
	}
}
