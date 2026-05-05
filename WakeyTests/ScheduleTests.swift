import XCTest
@testable import Wakey

final class ScheduleTests: XCTestCase {
	private var calendar: Calendar!
	
	override func setUp() {
		super.setUp()
		calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0)!
	}
	
	func testDefaultScheduleIsDisabledBusinessHours() {
		XCTAssertEqual(Schedule.default, Schedule(isEnabled: false, startHour: 9, endHour: 17))
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
	
	func testCodableRoundTrip() throws {
		let schedule = Schedule(isEnabled: true, startHour: 7, endHour: 15)
		
		let data = try JSONEncoder().encode(schedule)
		let decoded = try JSONDecoder().decode(Schedule.self, from: data)
		
		XCTAssertEqual(decoded, schedule)
	}
	
	private func date(hour: Int) -> Date {
		DateComponents(calendar: calendar, timeZone: calendar.timeZone, year: 2026, month: 1, day: 25, hour: hour).date!
	}
}
