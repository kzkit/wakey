import XCTest
@testable import Wakey

@MainActor
final class SchedulerManagerTests: XCTestCase {
	private let scheduleKey = "schedule"
	private var defaultsSuiteName: String!
	private var defaults: UserDefaults!
	private var now: Date!
	
	override func setUp() {
		super.setUp()
		defaultsSuiteName = "WakeyTests.\(UUID().uuidString)"
		defaults = UserDefaults(suiteName: defaultsSuiteName)
		defaults.removePersistentDomain(forName: defaultsSuiteName)
		now = Self.date(hour: 10)
	}
	
	override func tearDown() {
		defaults.removePersistentDomain(forName: defaultsSuiteName)
		defaults = nil
		defaultsSuiteName = nil
		now = nil
		super.tearDown()
	}
	
	func testLoadsDefaultScheduleWhenNothingIsPersisted() {
		let manager = makeManager()
		
		XCTAssertEqual(manager.currentSchedule, .default)
		XCTAssertFalse(manager.isActive)
	}
	
	func testLoadsPersistedScheduleAndCalculatesActiveState() throws {
		let schedule = Schedule(isEnabled: true, startHour: 9, endHour: 17)
		defaults.set(try JSONEncoder().encode(schedule), forKey: scheduleKey)
		
		let manager = makeManager()
		
		XCTAssertEqual(manager.currentSchedule, schedule)
		XCTAssertTrue(manager.isActive)
	}
	
	func testInvalidPersistedScheduleFallsBackToDefault() {
		defaults.set(Data("not json".utf8), forKey: scheduleKey)
		
		let manager = makeManager()
		
		XCTAssertEqual(manager.currentSchedule, .default)
		XCTAssertFalse(manager.isActive)
	}
	
	func testUpdateSchedulePersistsAndRecalculatesActiveState() throws {
		let manager = makeManager()
		let schedule = Schedule(isEnabled: true, startHour: 12, endHour: 18)
		
		manager.updateSchedule(schedule)
		
		XCTAssertEqual(manager.currentSchedule, schedule)
		XCTAssertFalse(manager.isActive)
		let stored = try XCTUnwrap(defaults.data(forKey: scheduleKey))
		XCTAssertEqual(try JSONDecoder().decode(Schedule.self, from: stored), schedule)
	}
	
	func testUpdateScheduleUsesInjectedClock() {
		let manager = makeManager()
		
		now = Self.date(hour: 23)
		manager.updateSchedule(Schedule(isEnabled: true, startHour: 22, endHour: 6))
		XCTAssertTrue(manager.isActive)
		
		now = Self.date(hour: 12)
		manager.updateSchedule(manager.currentSchedule)
		XCTAssertFalse(manager.isActive)
	}
	
	func testLoadsScheduleSavedByEarlierVersionsAsEveryDay() {
		defaults.set(Data(#"{"isEnabled":true,"startHour":9,"endHour":17}"#.utf8), forKey: scheduleKey)

		let manager = makeManager()

		XCTAssertEqual(manager.currentSchedule, Schedule(isEnabled: true, startHour: 9, endHour: 17, weekdays: Schedule.allWeekdays))
		XCTAssertTrue(manager.isActive)
	}

	func testScheduleIsInactiveOnUnselectedWeekday() {
		let manager = makeManager()
		let weekday = Calendar.current.component(.weekday, from: now)

		manager.updateSchedule(Schedule(isEnabled: true, startHour: 9, endHour: 17, weekdays: Schedule.allWeekdays.subtracting([weekday])))
		XCTAssertFalse(manager.isActive)

		manager.updateSchedule(Schedule(isEnabled: true, startHour: 9, endHour: 17, weekdays: [weekday]))
		XCTAssertTrue(manager.isActive)
	}

	func testDelayUntilNextMinuteLandsJustAfterTheMinuteBoundary() {
		let minuteStart = Date(timeIntervalSinceReferenceDate: 60 * 1_000_000)

		XCTAssertEqual(SchedulerManager.delayUntilNextMinute(from: minuteStart.addingTimeInterval(15)), 45.5, accuracy: 0.001)
		XCTAssertEqual(SchedulerManager.delayUntilNextMinute(from: minuteStart.addingTimeInterval(59.9)), 0.6, accuracy: 0.001)
		XCTAssertEqual(SchedulerManager.delayUntilNextMinute(from: minuteStart), 60.5, accuracy: 0.001)
	}

	private func makeManager() -> SchedulerManager {
		SchedulerManager(defaults: defaults, dateProvider: { self.now }, startsMonitoring: false)
	}
	
	private static func date(hour: Int) -> Date {
		Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 25, hour: hour))!
	}
}
