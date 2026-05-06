import XCTest
@testable import Wakey

@MainActor
final class LaunchAtLoginManagerTests: XCTestCase {
	private var service: MockLaunchAtLoginService!
	
	override func setUp() {
		super.setUp()
		service = MockLaunchAtLoginService()
	}
	
	override func tearDown() {
		service = nil
		super.tearDown()
	}
	
	func testEnabledStatusMapsToEnabledToggle() {
		service.status = .enabled
		let manager = makeManager()
		
		XCTAssertTrue(manager.isEnabled)
		XCTAssertFalse(manager.requiresApproval)
	}
	
	func testNotRegisteredStatusMapsToDisabledToggle() {
		service.status = .notRegistered
		let manager = makeManager()
		
		XCTAssertFalse(manager.isEnabled)
		XCTAssertFalse(manager.requiresApproval)
	}
	
	func testRequiresApprovalStatusMapsToEnabledToggleAndApprovalState() {
		service.status = .requiresApproval
		let manager = makeManager()
		
		XCTAssertTrue(manager.isEnabled)
		XCTAssertTrue(manager.requiresApproval)
	}
	
	func testNotFoundStatusMapsToDisabledToggle() {
		service.status = .notFound
		let manager = makeManager()
		
		XCTAssertFalse(manager.isEnabled)
		XCTAssertFalse(manager.requiresApproval)
	}
	
	func testSetEnabledRegistersAndRefreshesStatus() {
		let manager = makeManager()
		service.status = .enabled
		
		manager.setEnabled(true)
		
		XCTAssertEqual(service.registerCallCount, 1)
		XCTAssertEqual(service.unregisterCallCount, 0)
		XCTAssertEqual(manager.status, .enabled)
		XCTAssertNil(manager.errorMessage)
	}
	
	func testSetDisabledUnregistersAndRefreshesStatus() {
		service.status = .enabled
		let manager = makeManager()
		service.status = .notRegistered
		
		manager.setEnabled(false)
		
		XCTAssertEqual(service.registerCallCount, 0)
		XCTAssertEqual(service.unregisterCallCount, 1)
		XCTAssertEqual(manager.status, .notRegistered)
		XCTAssertNil(manager.errorMessage)
	}
	
	func testRegisterErrorIsSurfacedAndStatusIsRefreshed() {
		let manager = makeManager()
		service.registerError = MockLaunchAtLoginError.failed
		service.status = .notRegistered
		
		manager.setEnabled(true)
		
		XCTAssertEqual(service.registerCallCount, 1)
		XCTAssertEqual(manager.status, .notRegistered)
		XCTAssertEqual(manager.errorMessage, "Couldn't update launch at login.")
	}
	
	func testOpenSystemSettingsDelegatesAndRefreshesStatus() {
		let manager = makeManager()
		service.status = .requiresApproval
		
		manager.openSystemSettings()
		
		XCTAssertEqual(service.openSystemSettingsCallCount, 1)
		XCTAssertEqual(manager.status, .requiresApproval)
	}
	
	private func makeManager() -> LaunchAtLoginManager {
		LaunchAtLoginManager(service: service)
	}
}

private enum MockLaunchAtLoginError: Error {
	case failed
}

private final class MockLaunchAtLoginService: LaunchAtLoginServicing {
	var status: LaunchAtLoginStatus = .notRegistered
	var registerError: Error?
	var unregisterError: Error?
	private(set) var registerCallCount = 0
	private(set) var unregisterCallCount = 0
	private(set) var openSystemSettingsCallCount = 0
	
	func register() throws {
		registerCallCount += 1
		if let registerError {
			throw registerError
		}
	}
	
	func unregister() throws {
		unregisterCallCount += 1
		if let unregisterError {
			throw unregisterError
		}
	}
	
	func openSystemSettingsLoginItems() {
		openSystemSettingsCallCount += 1
	}
}
