import XCTest
@testable import Wakey

final class ScheduleTests: XCTestCase {
	private var calendar: Calendar!
	
	// January 2026: the 23rd is a Friday, the 24th a Saturday, the 25th a Sunday and the 26th a Monday.
	private let friday = 23
	private let saturday = 24
	private let sunday = 25
	private let monday = 26
	
	override func setUp() {
		super.setUp()
		calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0)!
	}
	
	func testDefaultScheduleIsDisabledBusinessHoursOnWeekdays() {
		XCTAssertEqual(
			Schedule.default,
			Schedule(isEnabled: false, startMinute: 9 * 60, endMinute: 17 * 60, weekdays: [2, 3, 4, 5, 6])
		)
	}
	
	func testDisabledScheduleIsNeverWithinSchedule() {
		let schedule = Schedule(isEnabled: false, startHour: 9, endHour: 17)
		
		XCTAssertFalse(schedule.isWithinSchedule(at: date(hour: 10), calendar: calendar))
	}
	
	func testSameDayScheduleIncludesStartAndExcludesEnd() {
		let schedule = Schedule(isEnabled: true, startHour: 9, endHour: 17)
		
		XCTAssertFalse(schedule.isWithinSchedule(at: date(hour: 8), calendar: calendar))
		XCTAssertTrue(schedule.isWithinSchedule(at: date(hour: 9), calendar: calendar))
		XCTAssertTrue(schedule.isWithinSchedule(at: date(hour: 16), calendar: calendar))
		XCTAssertFalse(schedule.isWithinSchedule(at: date(hour: 17), calendar: calendar))
	}
	
	func testOvernightScheduleWrapsAcrossMidnight() {
		let schedule = Schedule(isEnabled: true, startHour: 22, endHour: 6)
		
		XCTAssertTrue(schedule.isWithinSchedule(at: date(hour: 22), calendar: calendar))
		XCTAssertTrue(schedule.isWithinSchedule(at: date(hour: 2), calendar: calendar))
		XCTAssertFalse(schedule.isWithinSchedule(at: date(hour: 6), calendar: calendar))
		XCTAssertFalse(schedule.isWithinSchedule(at: date(hour: 12), calendar: calendar))
	}
	
	func testHalfHourBoundaries() {
		let schedule = Schedule(isEnabled: true, startMinute: 9 * 60 + 30, endMinute: 17 * 60 + 30)
		
		XCTAssertFalse(schedule.isWithinSchedule(at: date(hour: 9, minute: 29), calendar: calendar))
		XCTAssertTrue(schedule.isWithinSchedule(at: date(hour: 9, minute: 30), calendar: calendar))
		XCTAssertTrue(schedule.isWithinSchedule(at: date(hour: 17, minute: 29), calendar: calendar))
		XCTAssertFalse(schedule.isWithinSchedule(at: date(hour: 17, minute: 30), calendar: calendar))
	}
	
	func testSameDayScheduleOnlyRunsOnSelectedWeekdays() {
		let schedule = Schedule(isEnabled: true, startHour: 9, endHour: 17, weekdays: Schedule.workWeekdays)
		
		XCTAssertTrue(schedule.isWithinSchedule(at: date(day: friday, hour: 10), calendar: calendar))
		XCTAssertFalse(schedule.isWithinSchedule(at: date(day: saturday, hour: 10), calendar: calendar))
		XCTAssertFalse(schedule.isWithinSchedule(at: date(day: sunday, hour: 10), calendar: calendar))
		XCTAssertTrue(schedule.isWithinSchedule(at: date(day: monday, hour: 10), calendar: calendar))
	}
	
	func testOvernightScheduleBelongsToTheDayItStarts() {
		let fridayNight = Schedule(isEnabled: true, startHour: 22, endHour: 2, weekdays: [6])
		
		XCTAssertFalse(fridayNight.isWithinSchedule(at: date(day: friday, hour: 1), calendar: calendar))
		XCTAssertTrue(fridayNight.isWithinSchedule(at: date(day: friday, hour: 22), calendar: calendar))
		XCTAssertTrue(fridayNight.isWithinSchedule(at: date(day: saturday, hour: 1, minute: 59), calendar: calendar))
		XCTAssertFalse(fridayNight.isWithinSchedule(at: date(day: saturday, hour: 2), calendar: calendar))
		XCTAssertFalse(fridayNight.isWithinSchedule(at: date(day: saturday, hour: 22), calendar: calendar))
		
		let saturdayNight = Schedule(isEnabled: true, startHour: 22, endHour: 2, weekdays: [7])
		
		XCTAssertFalse(saturdayNight.isWithinSchedule(at: date(day: saturday, hour: 1), calendar: calendar))
		XCTAssertTrue(saturdayNight.isWithinSchedule(at: date(day: saturday, hour: 22), calendar: calendar))
		XCTAssertTrue(saturdayNight.isWithinSchedule(at: date(day: sunday, hour: 1), calendar: calendar))
		XCTAssertFalse(saturdayNight.isWithinSchedule(at: date(day: sunday, hour: 2), calendar: calendar))
	}
	
	func testOvernightScheduleWrapsFromSaturdayIntoSunday() {
		let schedule = Schedule(isEnabled: true, startMinute: 23 * 60 + 30, endMinute: 30, weekdays: [7])
		
		XCTAssertTrue(schedule.isWithinSchedule(at: date(day: saturday, hour: 23, minute: 30), calendar: calendar))
		XCTAssertTrue(schedule.isWithinSchedule(at: date(day: sunday, hour: 0, minute: 29), calendar: calendar))
		XCTAssertFalse(schedule.isWithinSchedule(at: date(day: sunday, hour: 23, minute: 30), calendar: calendar))
	}
	
	func testMatchingStartAndEndRunsAllDayEveryDay() {
		let schedule = Schedule(isEnabled: true, startHour: 9, endHour: 9)
		
		for hour in 0..<24 {
			XCTAssertTrue(schedule.isWithinSchedule(at: date(hour: hour), calendar: calendar), "hour \(hour)")
		}
	}
	
	func testMatchingStartAndEndRunsTwentyFourHoursFromStartOfSelectedDay() {
		let schedule = Schedule(isEnabled: true, startHour: 9, endHour: 9, weekdays: [6])
		
		XCTAssertFalse(schedule.isWithinSchedule(at: date(day: friday, hour: 8, minute: 59), calendar: calendar))
		XCTAssertTrue(schedule.isWithinSchedule(at: date(day: friday, hour: 9), calendar: calendar))
		XCTAssertTrue(schedule.isWithinSchedule(at: date(day: saturday, hour: 8, minute: 59), calendar: calendar))
		XCTAssertFalse(schedule.isWithinSchedule(at: date(day: saturday, hour: 9), calendar: calendar))
	}
	
	func testMidnightToMidnightCoversExactlyTheSelectedDay() {
		let schedule = Schedule(isEnabled: true, startHour: 0, endHour: 0, weekdays: [7])
		
		XCTAssertFalse(schedule.isWithinSchedule(at: date(day: friday, hour: 23, minute: 59), calendar: calendar))
		XCTAssertTrue(schedule.isWithinSchedule(at: date(day: saturday, hour: 0), calendar: calendar))
		XCTAssertTrue(schedule.isWithinSchedule(at: date(day: saturday, hour: 23, minute: 59), calendar: calendar))
		XCTAssertFalse(schedule.isWithinSchedule(at: date(day: sunday, hour: 0), calendar: calendar))
	}
	
	func testNoSelectedWeekdaysIsNeverWithinSchedule() {
		let schedules = [
			Schedule(isEnabled: true, startHour: 9, endHour: 17, weekdays: []),
			Schedule(isEnabled: true, startHour: 22, endHour: 6, weekdays: []),
			Schedule(isEnabled: true, startHour: 0, endHour: 0, weekdays: []),
		]
		
		for schedule in schedules {
			for day in friday...monday {
				for hour in 0..<24 {
					XCTAssertFalse(schedule.isWithinSchedule(at: date(day: day, hour: hour), calendar: calendar))
				}
			}
		}
	}
	
	func testSelectableMinutesAreEveryHalfHour() {
		let minutes = Schedule.selectableMinutes
		
		XCTAssertEqual(minutes.count, 48)
		XCTAssertEqual(minutes.first, 0)
		XCTAssertEqual(minutes[1], 30)
		XCTAssertEqual(minutes.last, 23 * 60 + 30)
	}
	
	func testOrderedWeekdaysStartsFromFirstWeekday() {
		XCTAssertEqual(Schedule.orderedWeekdays(firstWeekday: 1), [1, 2, 3, 4, 5, 6, 7])
		XCTAssertEqual(Schedule.orderedWeekdays(firstWeekday: 2), [2, 3, 4, 5, 6, 7, 1])
		XCTAssertEqual(Schedule.orderedWeekdays(firstWeekday: 7), [7, 1, 2, 3, 4, 5, 6])
	}
	
	func testCodableRoundTrip() throws {
		let schedule = Schedule(isEnabled: true, startMinute: 7 * 60 + 30, endMinute: 15 * 60, weekdays: [1, 4, 7])
		
		let data = try JSONEncoder().encode(schedule)
		let decoded = try JSONDecoder().decode(Schedule.self, from: data)
		
		XCTAssertEqual(decoded, schedule)
	}
	
	func testCodableRoundTripPreservesEmptyWeekdays() throws {
		let schedule = Schedule(isEnabled: true, startHour: 9, endHour: 17, weekdays: [])
		
		let data = try JSONEncoder().encode(schedule)
		let decoded = try JSONDecoder().decode(Schedule.self, from: data)
		
		XCTAssertEqual(decoded.weekdays, [])
	}
	
	func testDecodesScheduleSavedByEarlierVersions() throws {
		let json = #"{"isEnabled":true,"startHour":22,"endHour":6}"#
		
		let decoded = try JSONDecoder().decode(Schedule.self, from: Data(json.utf8))
		
		XCTAssertEqual(
			decoded,
			Schedule(isEnabled: true, startMinute: 22 * 60, endMinute: 6 * 60, weekdays: [1, 2, 3, 4, 5, 6, 7])
		)
		for day in friday...monday {
			XCTAssertTrue(decoded.isWithinSchedule(at: date(day: day, hour: 23), calendar: calendar))
			XCTAssertTrue(decoded.isWithinSchedule(at: date(day: day, hour: 5, minute: 59), calendar: calendar))
			XCTAssertFalse(decoded.isWithinSchedule(at: date(day: day, hour: 12), calendar: calendar))
		}
	}
	
	func testDecodesDisabledScheduleSavedByEarlierVersions() throws {
		let json = #"{"isEnabled":false,"startHour":9,"endHour":17}"#
		
		let decoded = try JSONDecoder().decode(Schedule.self, from: Data(json.utf8))
		
		XCTAssertEqual(decoded, Schedule(isEnabled: false, startHour: 9, endHour: 17, weekdays: Schedule.allWeekdays))
	}
	
	private func date(day: Int = 25, hour: Int, minute: Int = 0) -> Date {
		DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 1, day: day, hour: hour, minute: minute).date!
	}
}
