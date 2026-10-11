//
//  AppDelegate.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
	private var hasCompletedInitialLaunch = false
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		UNUserNotificationCenter.current().delegate = self
		NotificationManager.shared.requestAuthorization()
		SoftwareUpdateManager.shared.start()
		hasCompletedInitialLaunch = true
	}
	
	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
		guard hasCompletedInitialLaunch else {
			return false
		}
		
		Self.reopenSettingsFromAppActivation()
		return true
	}
	
	/// Used for app-level reactivation (for example Spotlight/Finder reopen), not SwiftUI menu actions.
	static func reopenSettingsFromAppActivation() {
		openSettingsWindow()
	}
	
	static func openSettingsWindow() {
		SettingsWindowCoordinator.shared.openSettingsWindow()
	}
}

extension AppDelegate: UNUserNotificationCenterDelegate {
	/// Without this, macOS hides the banner whenever Wakey is the frontmost app (for example while Settings is focused).
	nonisolated func userNotificationCenter(
		_ center: UNUserNotificationCenter,
		willPresent notification: UNNotification
	) async -> UNNotificationPresentationOptions {
		[.banner, .sound]
	}
}
