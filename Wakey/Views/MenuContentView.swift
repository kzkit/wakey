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
	
	private let wakeyGreen = Color(red: 0.4, green: 0.6, blue: 0.4)
	
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			statusRow
			
			Divider()
			controlsSection
			
			Divider()
			plainMenuButton(title: "Settings", action: openSettings)
			plainMenuButton(title: "Quit") {
				NSApplication.shared.terminate(nil)
			}
		}
		.padding()
		.frame(width: 180)
	}
	
	private var statusRow: some View {
		HStack(spacing: 6) {
			Image(systemName: viewModel.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
				.foregroundColor(wakeyGreen)
			Text(viewModel.statusText)
		}
		.font(.headline)
		.padding(.bottom, 4)
	}
	
	@ViewBuilder
	private var controlsSection: some View {
		if viewModel.isActive {
			activeControl
		} else {
			timerControls
		}
	}
	
	@ViewBuilder
	private var activeControl: some View {
		if viewModel.canStop {
			plainMenuButton(
				title: "Stop",
				systemImage: "stop.fill",
				foregroundColor: .red,
				action: viewModel.stop
			)
		} else {
			Label("Stop", systemImage: "stop.fill")
				.foregroundColor(.gray)
		}
	}
	
	private var timerControls: some View {
		ForEach(TimerDuration.allCases) { duration in
			plainMenuButton {
				HStack(spacing: 6) {
					Image(systemName: "timer")
						.foregroundColor(wakeyGreen)
					Text(duration.displayName)
				}
			} action: {
				viewModel.start(duration: duration)
			}
		}
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
	
	private func plainMenuButton(
		title: String,
		systemImage: String? = nil,
		foregroundColor: Color? = nil,
		action: @escaping () -> Void
	) -> some View {
		plainMenuButton {
			if let systemImage {
				Label(title, systemImage: systemImage)
			} else {
				Text(title)
			}
		} action: {
			action()
		}
		.foregroundColor(foregroundColor)
	}
	
	private func plainMenuButton<LabelContent: View>(
		@ViewBuilder label: () -> LabelContent,
		action: @escaping () -> Void
	) -> some View {
		Button {
			performAndDismissMenu(action)
		} label: {
			label()
		}
		.buttonStyle(.plain)
	}
	
	private func performAndDismissMenu(_ action: () -> Void) {
		action()
		dismiss()
	}
}
