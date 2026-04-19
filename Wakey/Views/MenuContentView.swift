//
//  MenuContentView.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import SwiftUI

struct MenuContentView: View {
	@ObservedObject var viewModel: WakeyViewModel
	@Environment(\.openWindow) private var openWindow
	@Environment(\.dismiss) private var dismiss
	
	private let WakeyGreen = Color(red: 0.4, green: 0.6, blue: 0.4)
	
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(spacing: 6) {
				Image(systemName: viewModel.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
					.foregroundColor(WakeyGreen)
				Text(viewModel.statusText)
			}
			.font(.headline)
			.padding(.bottom, 4)
			
			Divider()
			
				if viewModel.isActive {
					if viewModel.canStop {
						Button {
							performAndDismissMenu(viewModel.stop)
						} label: {
							Label("Stop", systemImage: "stop.fill")
						}
						.buttonStyle(.plain)
						.foregroundColor(.red)
					} else {
					Label("Stop", systemImage: "stop.fill")
						.foregroundColor(.gray)
				}
				} else {
					ForEach(TimerDuration.allCases) { duration in
						Button {
							performAndDismissMenu {
								viewModel.start(duration: duration)
							}
						} label: {
							HStack(spacing: 6) {
								Image(systemName: "timer")
									.foregroundColor(WakeyGreen)
								Text(duration.displayName)
						}
					}
					.buttonStyle(.plain)
				}
			}
			
				Divider()
				
				Button("Settings") {
					performAndDismissMenu {
						openSettings()
					}
				}
				.buttonStyle(.plain)
				
				Button("Quit") {
					performAndDismissMenu {
						NSApplication.shared.terminate(nil)
					}
				}
				.buttonStyle(.plain)
			}
		.padding()
		.frame(width: 180)
	}
	
	private func openSettings() {
		openWindow(id: "settings")
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
			for window in NSApplication.shared.windows {
				if window.identifier?.rawValue == "settings" ||
						window.title == "Wakey Settings" {
					window.orderFrontRegardless()
					NSApp.activate(ignoringOtherApps: true)
					break
				}
			}
		}
	}
	
	private func performAndDismissMenu(_ action: () -> Void) {
		action()
		dismiss()
	}
}
