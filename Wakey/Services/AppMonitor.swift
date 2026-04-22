//
//  AppMonitor.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import Foundation
import AppKit
import Combine

@MainActor
final class AppMonitor: ObservableObject {
	@Published private(set) var isActive = false
	
	private enum DefaultsKey {
		static let watchedApps = "watchedApps"
	}
	
	private var watchedApps: Set<String>
	private let defaults = UserDefaults.standard
	private var timerCancellable: AnyCancellable?
	private let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
	private let appActivityNotifications: [Notification.Name] = [
		NSWorkspace.didLaunchApplicationNotification,
		NSWorkspace.didTerminateApplicationNotification
	]
	
	init() {
		watchedApps = Set(defaults.stringArray(forKey: DefaultsKey.watchedApps) ?? [])
		startMonitoring()
		checkRunningApps()
	}
	
	var currentWatchedApps: Set<String> {
		watchedApps
	}
	
	func setWatchedApps(_ apps: Set<String>) {
		watchedApps = apps
		saveWatchedApps()
		checkRunningApps()
	}
	
	private func startMonitoring() {
		registerWorkspaceObservers()
		
		timerCancellable = Timer.publish(every: 5, on: .main, in: .common)
			.autoconnect()
			.sink { [weak self] _ in
				self?.checkRunningApps()
			}
	}
	
	@objc private func appActivityChanged(_ notification: Notification) {
		checkRunningApps()
	}
	
	private func checkRunningApps() {
		let runningBundleIDs = Set(
			NSWorkspace.shared.runningApplications
				.compactMap { $0.bundleIdentifier }
		)
		
		isActive = !watchedApps.intersection(runningBundleIDs).isEmpty
	}
	
	private func saveWatchedApps() {
		defaults.set(Array(watchedApps), forKey: DefaultsKey.watchedApps)
	}
	
	private func registerWorkspaceObservers() {
		for notification in appActivityNotifications {
			workspaceNotificationCenter.addObserver(
				self,
				selector: #selector(appActivityChanged),
				name: notification,
				object: nil
			)
		}
	}
	
	deinit {
		for notification in appActivityNotifications {
			NSWorkspace.shared.notificationCenter.removeObserver(
				self,
				name: notification,
				object: nil
			)
		}
		timerCancellable?.cancel()
	}
}
