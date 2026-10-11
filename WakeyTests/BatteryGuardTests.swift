import XCTest
@testable import Wakey

final class BatteryGuardTests: XCTestCase {
	func testBatteryBelowThresholdIsLow() {
		let state = makeState(isOnBatteryPower: true, level: 19)

		XCTAssertEqual(BatteryGuard.lowBatteryReason(for: state, threshold: 20), .batteryLevel(19))
	}

	func testBatteryAtThresholdIsNotLow() {
		let state = makeState(isOnBatteryPower: true, level: 20)

		XCTAssertNil(BatteryGuard.lowBatteryReason(for: state, threshold: 20))
	}

	func testLowPowerModeOnBatteryIsLow() {
		let state = makeState(isOnBatteryPower: true, level: 80, isLowPowerModeEnabled: true)

		XCTAssertEqual(BatteryGuard.lowBatteryReason(for: state, threshold: 20), .lowPowerMode)
	}

	func testLowPowerModeWithUnknownLevelIsLow() {
		let state = makeState(isOnBatteryPower: true, level: nil, isLowPowerModeEnabled: true)

		XCTAssertEqual(BatteryGuard.lowBatteryReason(for: state, threshold: 20), .lowPowerMode)
	}

	func testBatteryLevelIsReportedBeforeLowPowerMode() {
		let state = makeState(isOnBatteryPower: true, level: 8, isLowPowerModeEnabled: true)

		XCTAssertEqual(BatteryGuard.lowBatteryReason(for: state, threshold: 10), .batteryLevel(8))
	}

	func testChargerNeverCountsAsLow() {
		let state = makeState(isOnBatteryPower: false, level: 3, isLowPowerModeEnabled: true)

		XCTAssertNil(BatteryGuard.lowBatteryReason(for: state, threshold: 30))
	}

	func testMacWithoutBatteryNeverCountsAsLow() {
		var state = BatteryState.noBattery
		state.isLowPowerModeEnabled = true

		XCTAssertNil(BatteryGuard.lowBatteryReason(for: state, threshold: 30))
	}

	func testThresholdOptions() {
		XCTAssertEqual(BatteryGuard.thresholdOptions, [10, 20, 30])
		XCTAssertTrue(BatteryGuard.thresholdOptions.contains(BatteryGuard.defaultThreshold))
	}

	func testReasonMessages() {
		XCTAssertEqual(BatteryGuardReason.batteryLevel(15).message, "Battery is at 15%.")
		XCTAssertEqual(BatteryGuardReason.lowPowerMode.message, "Low Power Mode is on.")
	}

	private func makeState(isOnBatteryPower: Bool, level: Int?, isLowPowerModeEnabled: Bool = false) -> BatteryState {
		BatteryState(
			hasBattery: true,
			isOnBatteryPower: isOnBatteryPower,
			levelPercent: level,
			isLowPowerModeEnabled: isLowPowerModeEnabled
		)
	}
}
