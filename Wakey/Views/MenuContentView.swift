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
	@ObservedObject private var softwareUpdateManager = SoftwareUpdateManager.shared
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			header
			statusSection
				.padding(.top, 10)
			
			menuDivider
			
			if viewModel.isActive {
				if viewModel.canStop {
					activeControl
					menuDivider
				}
			} else {
				timerSection
				menuDivider
			}
			
			footerSection
		}
		.padding(.vertical, 14)
		.frame(width: 300)
		.background(.regularMaterial)
	}
	
	private var header: some View {
		HStack(alignment: .center, spacing: 12) {
			Text("Wakey")
				.font(.system(size: 14, weight: .bold))
				.foregroundStyle(.primary)
		}
		.padding(.horizontal, 16)
	}
	
	private var menuDivider: some View {
		Divider()
			.padding(.horizontal, 16)
			.padding(.vertical, 8)
	}

	private var statusSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			NativeMenuRow(
				title: statusTitle,
				detail: statusDetail,
				systemImage: viewModel.isActive ? "bolt.fill" : "moon.zzz.fill",
				tint: viewModel.isActive ? .yellow : .secondary
			)
		}
	}
	
	private var timerSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			sectionTitle(L10n.string("Quick Start"))
			
			timerControls
		}
	}
	
	private var activeControl: some View {
		NativeMenuRowButton(
			title: L10n.string("Stop"),
			detail: L10n.string("Allow your Mac to sleep normally."),
			systemImage: "stop.fill",
			tint: .red,
			action: {
				performAndDismissMenu(viewModel.stop)
			}
		)
	}
	
	private var timerControls: some View {
		VStack(spacing: 2) {
			ForEach(TimerDuration.allCases) { duration in
				NativeMenuRowButton(
					title: duration.displayName,
					detail: timerDetail(for: duration),
					systemImage: duration == .forever ? "infinity" : "timer",
					tint: .primary,
					action: {
						performAndDismissMenu {
							viewModel.start(duration: duration)
						}
					}
				)
			}
		}
	}
	
	private var footerSection: some View {
		VStack(spacing: 2) {
			SettingsLink {
				FooterMenuRow(title: L10n.string("Settings"))
			}
			.buttonStyle(NativeRowButtonStyle())
			.simultaneousGesture(
				TapGesture().onEnded {
					dismiss()
					DispatchQueue.main.async {
						SettingsWindowCoordinator.shared.raiseRegisteredWindowIfNeeded()
					}
				}
			)
			
			FooterMenuRowButton(
				title: L10n.string("About"),
				action: {
					dismiss()
					DispatchQueue.main.async {
						AboutWindowCoordinator.shared.openAboutWindow()
					}
				}
			)
			
			if softwareUpdateManager.isUpdateAvailable {
				FooterMenuRowButton(
					title: L10n.string("Update"),
					action: {
						dismiss()
						DispatchQueue.main.async {
							softwareUpdateManager.showUpdate()
						}
					}
				)
			}
			
			FooterMenuRowButton(
				title: L10n.string("Quit"),
				action: {
					performAndDismissMenu {
						NSApplication.shared.terminate(nil)
					}
				}
			)
		}
	}
	
	private var statusTitle: String {
		guard viewModel.isActive else {
			return L10n.string("Inactive")
		}
		
		if viewModel.canStop {
			return L10n.string("Manual session running")
		}
		
		return L10n.string("Keeping Mac awake")
	}
	
	private var statusDetail: String? {
		guard viewModel.isActive else {
			return L10n.string("Choose a duration to keep your Mac awake.")
		}
		
		return viewModel.statusText
	}
	
	private func sectionTitle(_ title: String) -> some View {
		Text(title)
			.font(.system(size: 13, weight: .semibold))
			.foregroundStyle(.primary)
			.padding(.horizontal, 16)
	}
	
	private func timerDetail(for duration: TimerDuration) -> String? {
		duration == .forever ? L10n.string("Until you stop it.") : nil
	}
	
	private func performAndDismissMenu(_ action: () -> Void) {
		action()
		dismiss()
	}
}

private struct FooterMenuRowButton: View {
	let title: String
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			FooterMenuRow(title: title)
		}
		.buttonStyle(NativeRowButtonStyle())
	}
}

private struct FooterMenuRow: View {
	let title: String
	
	var body: some View {
		Text(title)
			.font(.system(size: 14))
			.foregroundStyle(.primary)
			.lineLimit(1)
			.padding(.horizontal, 16)
			.padding(.vertical, 4)
			.frame(maxWidth: .infinity, alignment: .leading)
			.contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
	}
}

private struct NativeMenuRowButton: View {
	let title: String
	let detail: String?
	let systemImage: String
	let tint: Color
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			NativeMenuRow(
				title: title,
				detail: detail,
				systemImage: systemImage,
				tint: tint
			)
		}
		.buttonStyle(NativeRowButtonStyle())
	}
}

private struct NativeMenuRow: View {
	let title: String
	let detail: String?
	let systemImage: String
	let tint: Color
	
	var body: some View {
		HStack(spacing: 12) {
			Image(systemName: systemImage)
				.font(.system(size: 12, weight: .bold))
				.foregroundStyle(tint)
				.symbolRenderingMode(.hierarchical)
				.frame(width: 24, height: 24)
			
			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.system(size: 14))
					.foregroundStyle(.primary)
					.lineLimit(1)
				
				if let detail {
					Text(detail)
						.font(.system(size: 12))
						.foregroundStyle(.secondary)
						.lineLimit(2)
				}
			}
			.fixedSize(horizontal: false, vertical: true)
			.layoutPriority(1)
			
			Spacer(minLength: 0)
		}
		.padding(.horizontal, 16)
		.padding(.vertical, 5)
		.frame(maxWidth: .infinity, alignment: .leading)
		.contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
	}
}

private struct NativeRowButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		NativeRowButtonBody(configuration: configuration)
	}
	
	private struct NativeRowButtonBody: View {
		let configuration: Configuration
		@State private var isHovered = false
		
		var body: some View {
			configuration.label
				.background(
					RoundedRectangle(cornerRadius: 12, style: .continuous)
						.fill(backgroundColor)
						.padding(.horizontal, 8)
				)
				.scaleEffect(configuration.isPressed ? 0.985 : 1)
				.animation(.snappy(duration: 0.14), value: configuration.isPressed)
				.animation(.easeInOut(duration: 0.12), value: isHovered)
				.onHover { isHovered = $0 }
		}
		
		private var backgroundColor: Color {
			if configuration.isPressed {
				return Color.primary.opacity(0.12)
			}
			
			return isHovered ? Color.primary.opacity(0.08) : .clear
		}
	}
}
