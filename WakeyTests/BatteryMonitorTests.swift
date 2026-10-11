import Combine
import XCTest
@testable import Wakey

@MainActor
final class BatteryMonitorTests: XCTestCase {
	func testLoadsInitialStateFromProvider() {
		let provider = MockBatteryStateProvider()
		provider.state = BatteryState(hasBattery: true, isOnBatteryPower: true, levelPercent: 42, isLowPowerModeEnabled: true)

		let monitor = BatteryMonitor(stateProvider: provider, startsMonitoring: false)

		XCTAssertEqual(monitor.state, provider.state)
	}

	func testRefreshPublishesOnlyWhenStateChanges() {
		let provider = MockBatteryStateProvider()
		let monitor = BatteryMonitor(stateProvider: provider, startsMonitoring: false)
		var changeCount = 0
		let cancellable = monitor.objectWillChange.sink { changeCount += 1 }

		monitor.refresh()
		XCTAssertEqual(changeCount, 0)

		provider.state.levelPercent = 79
		monitor.refresh()

		XCTAssertEqual(changeCount, 1)
		XCTAssertEqual(monitor.state.levelPercent, 79)
		cancellable.cancel()
	}

	/// Reads the real power sources so a broken IOKit read shows up, without depending on this Mac's hardware.
	func testPowerSourceProviderReadsCurrentState() {
		let state = PowerSourceBatteryStateProvider().currentBatteryState()
		print("Battery state on this Mac: \(state)")

		if state.hasBattery, let level = state.levelPercent {
			XCTAssertTrue((0...100).contains(level))
		} else if !state.hasBattery {
			XCTAssertFalse(state.isOnBatteryPower)
			XCTAssertNil(state.levelPercent)
		}
	}

	func testLiveMonitorStartsAndTearsDown() {
		var monitor: BatteryMonitor? = BatteryMonitor()
		XCTAssertNotNil(monitor?.state)

		monitor = nil
		NotificationCenter.default.post(name: .NSProcessInfoPowerStateDidChange, object: nil)
		RunLoop.main.run(until: Date().addingTimeInterval(0.05))
	}
}

private final class MockBatteryStateProvider: BatteryStateProviding {
	var state = BatteryState(hasBattery: true, isOnBatteryPower: false, levelPercent: 80, isLowPowerModeEnabled: false)

	func currentBatteryState() -> BatteryState {
		state
	}
}
