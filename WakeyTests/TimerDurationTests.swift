import XCTest
@testable import Wakey

final class TimerDurationTests: XCTestCase {
	func testSecondsMapsTimedDurationsAndForever() {
		XCTAssertEqual(TimerDuration.fifteenMinutes.seconds, 900)
		XCTAssertEqual(TimerDuration.thirtyMinutes.seconds, 1800)
		XCTAssertEqual(TimerDuration.oneHour.seconds, 3600)
		XCTAssertEqual(TimerDuration.twoHours.seconds, 7200)
		XCTAssertEqual(TimerDuration.timed(seconds: 42).seconds, 42)
		XCTAssertNil(TimerDuration.forever.seconds)
	}
	
	func testDisplayNames() {
		XCTAssertEqual(TimerDuration.fifteenMinutes.displayName, "15 minutes")
		XCTAssertEqual(TimerDuration.thirtyMinutes.displayName, "30 minutes")
		XCTAssertEqual(TimerDuration.oneHour.displayName, "1 hour")
		XCTAssertEqual(TimerDuration.twoHours.displayName, "2 hours")
		XCTAssertEqual(TimerDuration.forever.displayName, "Forever")
	}
	
	func testCustomDisplayNamesUseFoundationFormatting() {
		XCTAssertEqual(TimerDuration.minutes(90).displayName, "1 hour, 30 minutes")
		XCTAssertEqual(TimerDuration.minutes(45).displayName, "45 minutes")
		XCTAssertEqual(TimerDuration.minutes(23 * 60 + 59).displayName, "23 hours, 59 minutes")
	}
	
	func testTimedPresetsOrdering() {
		XCTAssertEqual(TimerDuration.timedPresets, [.fifteenMinutes, .thirtyMinutes, .oneHour, .twoHours])
	}
	
	func testCustomDurationMatchingAPresetEqualsThePreset() {
		XCTAssertEqual(TimerDuration.custom(hours: 1, minutes: 0), .oneHour)
		XCTAssertEqual(TimerDuration.custom(hours: 0, minutes: 15), .fifteenMinutes)
	}
	
	func testCustomDurationAcceptsOneMinuteThroughTwentyThreeHoursFiftyNineMinutes() {
		XCTAssertEqual(TimerDuration.custom(hours: 0, minutes: 1)?.seconds, 60)
		XCTAssertEqual(TimerDuration.custom(hours: 1, minutes: 30)?.seconds, 5400)
		XCTAssertEqual(TimerDuration.custom(hours: 23, minutes: 59)?.seconds, 86_340)
	}
	
	func testCustomDurationRejectsOutOfRangeValues() {
		XCTAssertNil(TimerDuration.custom(hours: 0, minutes: 0))
		XCTAssertNil(TimerDuration.custom(hours: 24, minutes: 0))
		XCTAssertNil(TimerDuration.custom(hours: 1, minutes: -1))
		XCTAssertNil(TimerDuration.custom(hours: -1, minutes: 30))
	}
}
