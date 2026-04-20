//
//  WakeyApp.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import SwiftUI

@main
struct WakeyApp: App {
	@StateObject private var viewModel = WakeyViewModel()
	@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	
	var body: some Scene {
		MenuBarExtra {
			MenuContentView(viewModel: viewModel)
		} label: {
			Image(systemName: "bolt.fill")
				.symbolRenderingMode(.palette)
				.foregroundStyle(viewModel.isActive ? Color.yellow : Color.primary)
		}
		.menuBarExtraStyle(.window)
		
		Window("Wakey Settings", id: "settings") {
			SettingsView(viewModel: viewModel)
		}
		.windowResizability(.contentSize)
		.defaultPosition(.center)
	}
}
