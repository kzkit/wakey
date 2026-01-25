//
//  MatchaApp.swift
//  Matcha
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import SwiftUI

@main
struct MatchaApp: App {
	@StateObject private var viewModel = MatchaViewModel()
	@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	
	var body: some Scene {
		MenuBarExtra {
			MenuContentView(viewModel: viewModel)
		} label: {
			Image(systemName: viewModel.isActive ? "leaf.fill" : "leaf")
				.symbolRenderingMode(.palette)
				.foregroundStyle(viewModel.isActive ? Color.green : Color.primary)
		}
		.menuBarExtraStyle(.window)
		
		Window("Matcha Settings", id: "settings") {
			SettingsView(viewModel: viewModel)
		}
		.windowResizability(.contentSize)
		.defaultPosition(.center)
	}
}
