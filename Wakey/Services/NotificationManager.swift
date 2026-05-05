//
//  NotificationManager.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import UserNotifications

protocol NotificationSending {
	func requestAuthorization()
	func sendTimerEndedNotification()
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
	
	func sendTimerEndedNotification() {
		let content = UNMutableNotificationContent()
		content.title = "Wakey"
		content.body = "Timer ended. Your Mac can sleep now."
		content.sound = .default
		
		let request = UNNotificationRequest(
			identifier: UUID().uuidString,
			content: content,
			trigger: nil
		)
		
		notificationCenter.add(request)
	}
}
