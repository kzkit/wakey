//
//  AppMonitor.swift
//  Matcha
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
		NSWorkspace.shared.notificationCenter.addObserver(
			self,
			selector: #selector(appLaunched),
			name: NSWorkspace.didLaunchApplicationNotification,
			object: nil
		)
		
		NSWorkspace.shared.notificationCenter.addObserver(
			self,
			selector: #selector(appTerminated),
			name: NSWorkspace.didTerminateApplicationNotification,
			object: nil
		)
		
		timerCancellable = Timer.publish(every: 5, on: .main, in: .common)
			.autoconnect()
			.sink { [weak self] _ in
				self?.checkRunningApps()
			}
	}
	
	@objc private func appLaunched(_ notification: Notification) {
		checkRunningApps()
	}
	
	@objc private func appTerminated(_ notification: Notification) {
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
	
	deinit {
		NSWorkspace.shared.notificationCenter.removeObserver(
			self,
			name: NSWorkspace.didLaunchApplicationNotification,
			object: nil
		)
		NSWorkspace.shared.notificationCenter.removeObserver(
			self,
			name: NSWorkspace.didTerminateApplicationNotification,
			object: nil
		)
		timerCancellable?.cancel()
	}
}
