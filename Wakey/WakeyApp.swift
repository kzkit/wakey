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
			MenuBarIcon(isActive: viewModel.isActive)
		}
		.menuBarExtraStyle(.window)
		
		Settings {
			SettingsView(viewModel: viewModel)
		}
	}
}

private struct MenuBarIcon: View {
	let isActive: Bool
	@Environment(\.openSettings) private var openSettings
	
	var body: some View {
		Image(systemName: "bolt.fill")
			.symbolRenderingMode(.palette)
			.foregroundStyle(isActive ? Color.yellow : Color.primary)
			.onAppear {
				// The menu bar label lives for the whole app session, so it can hand `openSettings` to AppKit callers.
				SettingsWindowCoordinator.shared.setOpenSettingsAction { openSettings() }
			}
	}
}
