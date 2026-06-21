//
//  AboutWindowCoordinator.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 06/05/2026.
//

import AppKit
import SwiftUI

@MainActor
final class AboutWindowCoordinator: NSObject, NSWindowDelegate {
	static let shared = AboutWindowCoordinator()
	
	private var aboutWindow: NSWindow?
	
	private override init() {}
	
	func openAboutWindow() {
		NSApp.activate(ignoringOtherApps: true)
		
		if let aboutWindow {
			configure(window: aboutWindow)
			return
		}
		
		let window = NSWindow(
			contentRect: NSRect(x: 0, y: 0, width: 300, height: 300),
			styleMask: [.titled, .closable, .fullSizeContentView],
			backing: .buffered,
			defer: false
		)
		
		window.title = L10n.string("About Wakey")
		window.titleVisibility = .hidden
		window.titlebarAppearsTransparent = true
		window.isMovableByWindowBackground = true
		window.isReleasedWhenClosed = false
		window.contentViewController = NSHostingController(rootView: AboutView())
		window.delegate = self
		window.center()
		
		configure(window: window)
	}
	
	func windowWillClose(_ notification: Notification) {
		guard notification.object as? NSWindow === aboutWindow else {
			return
		}
		
		aboutWindow = nil
	}
	
	private func configure(window: NSWindow) {
		aboutWindow = window
		window.level = .floating
		window.collectionBehavior.insert(.moveToActiveSpace)
		window.makeKeyAndOrderFront(nil)
		window.orderFrontRegardless()
	}
}
