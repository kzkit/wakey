import XCTest
@testable import Wakey

final class TimerDurationTests: XCTestCase {
	func testSecondsMapsTimedDurationsAndForever() {
		XCTAssertEqual(TimerDuration.oneMinute.seconds, 60)
		XCTAssertEqual(TimerDuration.fiveMinutes.seconds, 300)
		XCTAssertEqual(TimerDuration.tenMinutes.seconds, 600)
		XCTAssertNil(TimerDuration.forever.seconds)
	}
	
	func testDisplayNames() {
		XCTAssertEqual(TimerDuration.oneMinute.displayName, "1 minute")
		XCTAssertEqual(TimerDuration.fiveMinutes.displayName, "5 minutes")
		XCTAssertEqual(TimerDuration.tenMinutes.displayName, "10 minutes")
		XCTAssertEqual(TimerDuration.forever.displayName, "Forever")
	}
	
	func testAllCasesOrdering() {
		XCTAssertEqual(TimerDuration.allCases, [.oneMinute, .fiveMinutes, .tenMinutes, .forever])
	}
}
