//
//  SettingsWindowCoordinator.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 22/04/2026.
//

import AppKit

@MainActor
final class SettingsWindowCoordinator {
	static let shared = SettingsWindowCoordinator()
	
	private weak var settingsWindow: NSWindow?
	private var pendingRaiseAttempts = 0
	private var settingsWindowTitle: String { L10n.string("Settings") }
	private var restoreWindowLevelWorkItem: DispatchWorkItem?
	
	private init() {}
	
	func openSettingsWindow() {
		NSApp.activate(ignoringOtherApps: true)
		
		if let settingsWindow {
			configure(window: settingsWindow)
			return
		}
		
		NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
		scheduleRaiseAttempts()
	}
	
	func register(window: NSWindow) {
		settingsWindow = window
		configure(window: window)
	}
	
	func raiseRegisteredWindowIfNeeded() {
		guard let settingsWindow else {
			return
		}
		
		configure(window: settingsWindow)
	}
	
	private func scheduleRaiseAttempts() {
		pendingRaiseAttempts = 5
		raiseSettingsWindowIfNeeded()
	}
	
	private func raiseSettingsWindowIfNeeded() {
		if let settingsWindow = settingsWindow ?? findSettingsWindow() {
			configure(window: settingsWindow)
			return
		}
		
		guard pendingRaiseAttempts > 0 else {
			return
		}
		
		pendingRaiseAttempts -= 1
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
			Task { @MainActor in
				self?.raiseSettingsWindowIfNeeded()
			}
		}
	}
	
	private func findSettingsWindow() -> NSWindow? {
		NSApp.windows.first { window in
			window.title == settingsWindowTitle
		}
	}
	
	private func configure(window: NSWindow) {
		settingsWindow = window
		restoreWindowLevelWorkItem?.cancel()
		window.level = .floating
		window.collectionBehavior.insert(.moveToActiveSpace)
		window.makeKeyAndOrderFront(nil)
		window.orderFrontRegardless()
		
		let restoreWorkItem = DispatchWorkItem { [weak self, weak window] in
			guard let self, let window else {
				return
			}
			
			guard self.settingsWindow === window else {
				return
			}
			
			window.level = .normal
		}
		
		restoreWindowLevelWorkItem = restoreWorkItem
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: restoreWorkItem)
	}
}
