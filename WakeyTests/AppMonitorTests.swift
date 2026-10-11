import Combine
import XCTest
@testable import Wakey

@MainActor
final class AppMonitorTests: XCTestCase {
	private let watchedAppsKey = "watchedApps"
	private var defaults: UserDefaults!
	private var applicationProvider: MockRunningApplicationProvider!
	
	override func setUp() {
		super.setUp()
		defaults = makeTestDefaults()
		applicationProvider = MockRunningApplicationProvider()
	}
	
	override func tearDown() {
		defaults = nil
		applicationProvider = nil
		super.tearDown()
	}
	
	func testLoadsEmptyWatchedAppsByDefault() {
		let monitor = makeMonitor()
		
		XCTAssertEqual(monitor.currentWatchedApps, [])
		XCTAssertFalse(monitor.isActive)
	}
	
	func testLoadsPersistedWatchedAppsAndCalculatesActiveState() {
		defaults.set(["com.example.Editor", "com.example.Browser"], forKey: watchedAppsKey)
		applicationProvider.runningApplicationBundleIdentifiers = ["com.example.Editor"]
		
		let monitor = makeMonitor()
		
		XCTAssertEqual(monitor.currentWatchedApps, ["com.example.Editor", "com.example.Browser"])
		XCTAssertTrue(monitor.isActive)
	}
	
	func testSetWatchedAppsPersistsAndUpdatesInactiveState() {
		applicationProvider.runningApplicationBundleIdentifiers = ["com.example.Terminal"]
		let monitor = makeMonitor()
		
		monitor.setWatchedApps(["com.example.Editor"])
		
		XCTAssertEqual(monitor.currentWatchedApps, ["com.example.Editor"])
		XCTAssertEqual(Set(defaults.stringArray(forKey: watchedAppsKey) ?? []), ["com.example.Editor"])
		XCTAssertFalse(monitor.isActive)
	}
	
	func testSetWatchedAppsUpdatesActiveStateWhenRunningAppMatches() {
		applicationProvider.runningApplicationBundleIdentifiers = ["com.example.Editor"]
		let monitor = makeMonitor()
		
		monitor.setWatchedApps(["com.example.Editor"])
		
		XCTAssertTrue(monitor.isActive)
	}

	func testRecheckingUnchangedAppsDoesNotPublishChanges() {
		applicationProvider.runningApplicationBundleIdentifiers = ["com.example.Editor"]
		let monitor = makeMonitor()
		monitor.setWatchedApps(["com.example.Editor"])
		var changeCount = 0
		let cancellable = monitor.objectWillChange.sink { changeCount += 1 }

		monitor.setWatchedApps(["com.example.Editor"])

		XCTAssertEqual(changeCount, 0)
		cancellable.cancel()
	}

	private func makeMonitor() -> AppMonitor {
		AppMonitor(defaults: defaults, applicationProvider: applicationProvider, startsMonitoring: false)
	}
}

private final class MockRunningApplicationProvider: RunningApplicationProviding {
	var runningApplicationBundleIdentifiers: Set<String> = []
}
