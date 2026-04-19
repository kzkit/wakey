//
//  NotificationManager.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import UserNotifications

final class NotificationManager {
	static let shared = NotificationManager()
	
	private init() {}
	
	func requestAuthorization() {
		UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
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
		
		UNUserNotificationCenter.current().add(request)
	}
}

