import UserNotifications
import XCTest
@testable import Wakey

final class NotificationManagerTests: XCTestCase {
	func testRequestAuthorizationUsesAlertAndSoundOptions() {
		let center = MockUserNotificationCenter()
		let manager = NotificationManager(notificationCenter: center)
		
		manager.requestAuthorization()
		
		XCTAssertEqual(center.authorizationOptions, [.alert, .sound])
	}
	
	func testSendTimerEndedNotificationCreatesExpectedRequest() throws {
		let center = MockUserNotificationCenter()
		let manager = NotificationManager(notificationCenter: center)
		
		manager.sendTimerEndedNotification(isStillAwake: false)
		
		let request = try XCTUnwrap(center.addedRequests.first)
		XCTAssertFalse(request.identifier.isEmpty)
		XCTAssertEqual(request.content.title, "Wakey")
		XCTAssertEqual(request.content.body, "Timer ended. Your Mac can sleep now.")
		XCTAssertEqual(request.content.sound, .default)
		XCTAssertNil(request.trigger)
	}
	
	func testSendTimerEndedNotificationMentionsWhenMacIsStillAwake() throws {
		let center = MockUserNotificationCenter()
		let manager = NotificationManager(notificationCenter: center)
		
		manager.sendTimerEndedNotification(isStillAwake: true)
		
		let request = try XCTUnwrap(center.addedRequests.first)
		XCTAssertEqual(request.content.body, "Timer ended. A schedule or watched app is still keeping your Mac awake.")
	}
}

private final class MockUserNotificationCenter: UserNotificationCentering {
	private(set) var authorizationOptions: UNAuthorizationOptions?
	private(set) var addedRequests: [UNNotificationRequest] = []
	
	func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping @Sendable (Bool, Error?) -> Void) {
		authorizationOptions = options
		completionHandler(true, nil)
	}
	
	func add(_ request: UNNotificationRequest) {
		addedRequests.append(request)
	}
}
