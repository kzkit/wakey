//
//  NotificationManager.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import UserNotifications

protocol NotificationSending {
	func requestAuthorization()
	func sendTimerEndedNotification(isStillAwake: Bool)
	func sendBatteryGuardStoppedNotification(reason: BatteryGuardReason)
}

protocol UserNotificationCentering {
	func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping @Sendable (Bool, Error?) -> Void)
	func add(_ request: UNNotificationRequest)
}

struct UserNotificationCenterAdapter: UserNotificationCentering {
	private let notificationCenter: UNUserNotificationCenter
	
	init(notificationCenter: UNUserNotificationCenter = .current()) {
		self.notificationCenter = notificationCenter
	}
	
	func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping @Sendable (Bool, Error?) -> Void) {
		notificationCenter.requestAuthorization(options: options, completionHandler: completionHandler)
	}
	
	func add(_ request: UNNotificationRequest) {
		notificationCenter.add(request, withCompletionHandler: nil)
	}
}

final class NotificationManager: NotificationSending {
	static let shared = NotificationManager()
	
	private let notificationCenter: UserNotificationCentering
	
	init(notificationCenter: UserNotificationCentering = UserNotificationCenterAdapter()) {
		self.notificationCenter = notificationCenter
	}
	
	func requestAuthorization() {
		notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, error in
			if let error = error {
				print("Notification authorization error: \(error)")
			}
		}
	}
	
	func sendTimerEndedNotification(isStillAwake: Bool) {
		let content = UNMutableNotificationContent()
		content.title = "Wakey"
		content.body = isStillAwake
			? L10n.string("Timer ended. A schedule or watched app is still keeping your Mac awake.")
			: L10n.string("Timer ended. Your Mac can sleep now.")
		content.sound = .default
		
		send(content)
	}
	
	func sendBatteryGuardStoppedNotification(reason: BatteryGuardReason) {
		let content = UNMutableNotificationContent()
		content.title = L10n.string("Wakey stopped")
		switch reason {
		case .batteryLevel(let percent):
			content.body = L10n.format("Battery is at %lld%%. Your Mac can sleep normally.", percent)
		case .lowPowerMode:
			content.body = L10n.string("Low Power Mode turned on. Your Mac can sleep normally.")
		}
		content.sound = .default
		
		send(content)
	}
	
	private func send(_ content: UNNotificationContent) {
		let request = UNNotificationRequest(
			identifier: UUID().uuidString,
			content: content,
			trigger: nil
		)
		
		notificationCenter.add(request)
	}
}
