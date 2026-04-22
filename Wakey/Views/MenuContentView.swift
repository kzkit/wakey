//
//  MenuContentView.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import AppKit
import SwiftUI

struct MenuContentView: View {
	@ObservedObject var viewModel: WakeyViewModel
	@Environment(\.dismiss) private var dismiss
	
	private let primaryColor = Color.blue
	private let sectionBackground = Color(nsColor: .controlBackgroundColor)
	
	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			statusSection
			controlsSection
			secondaryActionsSection
		}
		.padding(14)
		.frame(width: 280)
	}
	
	private var statusSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(alignment: .top, spacing: 10) {
				VStack(alignment: .leading, spacing: 2) {
					Text("Wakey")
						.font(.headline)
					Text(statusTitle)
						.font(.subheadline.weight(.medium))
					if let detail = statusDetail {
						Text(detail)
							.font(.caption)
							.foregroundStyle(.secondary)
							.lineLimit(2)
							.multilineTextAlignment(.leading)
							.fixedSize(horizontal: false, vertical: true)
					}
				}
				.layoutPriority(1)
				
				Spacer(minLength: 8)
				
				Image(systemName: "bolt.fill")
					.font(.title3)
					.foregroundStyle(viewModel.isActive ? primaryColor : .secondary)
					.frame(width: 24, alignment: .trailing)
			}
		}
		.padding(12)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.fill(sectionBackground)
		)
	}
	
	private var controlsSection: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text(viewModel.isActive ? "Current Session" : "Quick Start")
				.font(.caption.weight(.semibold))
				.foregroundStyle(.secondary)
				.padding(.horizontal, 4)
			
			VStack(spacing: 4) {
				if viewModel.isActive {
					activeControl
				} else {
					timerControls
				}
			}
		}
	}
	
	@ViewBuilder
	private var activeControl: some View {
		if viewModel.canStop {
			menuRowButton(
				title: "Stop",
				systemImage: "stop.fill",
				tint: .red,
				action: viewModel.stop
			)
		} else {
			menuRowLabel(
				title: "Managed by schedule or app rules",
				systemImage: "clock.arrow.circlepath"
			)
			.fixedSize(horizontal: false, vertical: true)
			.foregroundStyle(.secondary)
		}
	}
	
	private var timerControls: some View {
		VStack(spacing: 4) {
			ForEach(TimerDuration.allCases) { duration in
				menuRowButton(
					title: duration.displayName,
					systemImage: duration == .forever ? "infinity" : "timer",
					action: {
						viewModel.start(duration: duration)
					}
				)
			}
		}
	}
	
	private var secondaryActionsSection: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text("More")
				.font(.caption.weight(.semibold))
				.foregroundStyle(.secondary)
				.padding(.horizontal, 4)
			
			VStack(spacing: 2) {
				settingsMenuItem
				secondaryMenuButton(title: "Quit", systemImage: "power") {
					NSApplication.shared.terminate(nil)
				}
			}
		}
	}
	
	private var settingsMenuItem: some View {
		SettingsLink {
			secondaryMenuRow(title: "Settings", systemImage: "gearshape")
		}
		.buttonStyle(.plain)
		.simultaneousGesture(
			TapGesture().onEnded {
				dismiss()
				DispatchQueue.main.async {
					SettingsWindowCoordinator.shared.raiseRegisteredWindowIfNeeded()
				}
			}
		)
	}
	
	private var statusTitle: String {
		guard viewModel.isActive else {
			return "Inactive"
		}
		
		if viewModel.canStop {
			return "Manual session running"
		}
		
		return "Sleep prevention active"
	}
	
	private var statusDetail: String? {
		guard viewModel.isActive else {
			return "Choose a duration to keep your Mac awake."
		}
		
		return viewModel.statusText
	}
	
	private func menuRowButton(
		title: String,
		systemImage: String,
		tint: Color? = nil,
		action: @escaping () -> Void
	) -> some View {
		Button {
			performAndDismissMenu(action)
		} label: {
			menuRowLabel(title: title, systemImage: systemImage, tint: tint)
				.fixedSize(horizontal: false, vertical: true)
		}
		.buttonStyle(.plain)
	}
	
	private func menuRowLabel(
		title: String,
		systemImage: String,
		tint: Color? = nil
	) -> some View {
		HStack(spacing: 10) {
			Image(systemName: systemImage)
				.frame(width: 14)
				.foregroundStyle(tint ?? primaryColor)
			Text(title)
				.font(.body)
				.lineLimit(nil)
				.frame(maxWidth: .infinity, alignment: .leading)
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 8)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(
			RoundedRectangle(cornerRadius: 10, style: .continuous)
				.fill(sectionBackground)
		)
		.contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
	}
	
	private func secondaryMenuButton(
		title: String,
		systemImage: String,
		action: @escaping () -> Void
	) -> some View {
		Button {
			performAndDismissMenu(action)
		} label: {
			secondaryMenuRow(title: title, systemImage: systemImage)
		}
		.buttonStyle(.plain)
	}
	
	private func secondaryMenuRow(title: String, systemImage: String) -> some View {
		HStack(spacing: 10) {
			Image(systemName: systemImage)
				.frame(width: 14)
				.foregroundStyle(.secondary)
			Text(title)
				.font(.callout)
			Spacer(minLength: 0)
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 7)
		.frame(maxWidth: .infinity, alignment: .leading)
		.contentShape(Rectangle())
	}
	
	private func performAndDismissMenu(_ action: () -> Void) {
		action()
		dismiss()
	}
}
