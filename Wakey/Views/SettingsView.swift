//
//  SettingsView.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import AppKit
import SwiftUI

struct SettingsView: View {
	@ObservedObject var viewModel: WakeyViewModel
	
	@State private var schedule: Schedule
	@State private var pendingWatchedApps: Set<String>
	
	private let wakeyColor = Color.blue
	
	init(viewModel: WakeyViewModel) {
		self.viewModel = viewModel
		_schedule = State(initialValue: viewModel.schedulerManager.currentSchedule)
		_pendingWatchedApps = State(initialValue: viewModel.appMonitor.currentWatchedApps)
	}
	
	var body: some View {
		VStack(spacing: 0) {
			header
			
			Divider()
			
			ScrollView {
				VStack(alignment: .leading, spacing: 22) {
					scheduleSection
					appSection
				}
				.padding(.horizontal, 24)
				.padding(.vertical, 22)
			}
			
			Divider()
			
			saveButtonRow
		}
		.frame(width: 460, height: 560)
		.background(.regularMaterial)
		.background(SettingsWindowAccessor())
		.onAppear {
			resetToSavedValues()
		}
	}
	
	private var header: some View {
		HStack(alignment: .center, spacing: 12) {
			VStack(alignment: .leading, spacing: 3) {
				Text("Wakey Settings")
					.font(.system(size: 20, weight: .semibold))
				
				Text("Choose when your Mac stays awake.")
					.font(.subheadline)
					.foregroundStyle(.secondary)
			}
			
			Spacer(minLength: 0)
			
			Label(viewModel.isActive ? "Active" : "Inactive", systemImage: viewModel.isActive ? "bolt.fill" : "moon.zzz.fill")
				.font(.caption.weight(.semibold))
				.foregroundStyle(viewModel.isActive ? wakeyColor : .secondary)
				.labelStyle(.titleAndIcon)
				.padding(.horizontal, 10)
				.padding(.vertical, 6)
				.background(
					Capsule()
						.fill(viewModel.isActive ? wakeyColor.opacity(0.12) : Color.secondary.opacity(0.12))
				)
		}
		.padding(.horizontal, 24)
		.padding(.vertical, 18)
	}
	
	private var scheduleSection: some View {
		VStack(alignment: .leading, spacing: 10) {
			sectionHeader(
				icon: "clock.fill",
				title: "Schedule",
				description: "Keep your Mac awake during a recurring time window."
			)
			
			SettingsGroup {
				scheduleToggleRow
				
				if schedule.isEnabled {
					SettingsDivider()
					activeHoursRow
				}
				
				if viewModel.schedulerManager.isActive {
					SettingsDivider()
					scheduleActiveRow
				}
			}
		}
	}
	
	private var scheduleToggleRow: some View {
		HStack(spacing: 12) {
			Image(systemName: "calendar.badge.clock")
				.font(.system(size: 15, weight: .semibold))
				.frame(width: 32, height: 32)
			
			Text("Enable schedule")
				.font(.callout)
			
			Spacer(minLength: 0)
			
			Toggle("", isOn: $schedule.isEnabled)
				.labelsHidden()
				.toggleStyle(.switch)
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
	}
	
	private var activeHoursRow: some View {
		HStack(spacing: 12) {
			IconWell(systemImage: "timer", tint: .secondary)
			
			Text("Active hours")
				.font(.callout)
			
			Spacer(minLength: 0)
			
			HStack(spacing: 8) {
				hourMenu(selectedHour: schedule.startHour) { selectedHour in
					schedule.startHour = selectedHour
				}
				
				Text("to")
					.font(.callout)
					.foregroundStyle(.secondary)
				
				hourMenu(selectedHour: schedule.endHour) { selectedHour in
					schedule.endHour = selectedHour
				}
			}
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
		.transition(.opacity.combined(with: .move(edge: .top)))
	}
	
	private var scheduleActiveRow: some View {
		HStack(spacing: 12) {
			IconWell(systemImage: "checkmark", tint: .green)
			
			VStack(alignment: .leading, spacing: 2) {
				Text("Schedule active now")
					.font(.callout)
				
				Text("Wakey is currently preventing sleep from this rule.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			
			Spacer(minLength: 0)
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
	}
	
	private var appSection: some View {
		VStack(alignment: .leading, spacing: 10) {
			sectionHeader(
				icon: "bolt.badge.automatic.fill",
				title: "Watched Apps",
				description: "Selected apps keep your Mac awake while they are open."
			)
			
			SettingsGroup {
				if runningApps.isEmpty {
					emptyAppsRow
				} else {
					if !watchedApps.isEmpty {
						appGroup(title: "Watching", apps: watchedApps)
					}
					
					if !watchedApps.isEmpty && !availableApps.isEmpty {
						SettingsDivider()
					}
					
					appGroup(
						title: watchedApps.isEmpty ? "Available Apps" : "Available While Open",
						apps: availableApps
					)
				}
			}
		}
	}
	
	private var emptyAppsRow: some View {
		HStack(spacing: 12) {
			IconWell(systemImage: "app.dashed", tint: .secondary)
			
			VStack(alignment: .leading, spacing: 2) {
				Text("No running apps")
					.font(.callout)
				
				Text("Open an app to add it here.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			
			Spacer(minLength: 0)
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 12)
	}
	
	private func appRow(_ app: InstalledApp) -> some View {
		let isWatched = pendingWatchedApps.contains(app.bundleIdentifier)
		
		return AppSelectionRow(
			app: app,
			isWatched: isWatched,
			accentColor: wakeyColor
		) {
			withAnimation(.snappy(duration: 0.16)) {
				toggleWatchedApp(bundleIdentifier: app.bundleIdentifier, isWatched: isWatched)
			}
		}
	}
	
	private var saveButtonRow: some View {
		HStack(spacing: 12) {
			if hasChanges {
				Text("Unsaved changes")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			
			Spacer(minLength: 0)
			
			Button("Save") {
				saveChanges()
			}
			.buttonStyle(.borderedProminent)
			.tint(wakeyColor)
			.disabled(!hasChanges)
			.keyboardShortcut(.defaultAction)
		}
		.padding(.horizontal, 24)
		.padding(.vertical, 14)
	}
	
	private func sectionHeader(icon: String, title: String, description: String) -> some View {
		HStack(alignment: .top, spacing: 10) {
			Image(systemName: icon)
				.font(.system(size: 15, weight: .semibold))
				.foregroundStyle(wakeyColor)
				.frame(width: 22, height: 22)
			
			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.subheadline.weight(.semibold))
				
				Text(description)
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}
	
	private func toggleWatchedApp(bundleIdentifier: String, isWatched: Bool) {
		if isWatched {
			pendingWatchedApps.remove(bundleIdentifier)
		} else {
			pendingWatchedApps.insert(bundleIdentifier)
		}
	}
	
	private func hourMenu(selectedHour: Int, onSelect: @escaping (Int) -> Void) -> some View {
		Menu {
			ForEach(0..<24, id: \.self) { hour in
				Button(String(format: "%02d:00", hour)) {
					onSelect(hour)
				}
			}
		} label: {
			HStack(spacing: 6) {
				Text(String(format: "%02d:00", selectedHour))
					.monospacedDigit()
				
				Image(systemName: "chevron.up.chevron.down")
					.font(.caption2.weight(.semibold))
					.foregroundStyle(.secondary)
			}
			.padding(.horizontal, 9)
			.padding(.vertical, 5)
			.background(
				RoundedRectangle(cornerRadius: 7, style: .continuous)
					.fill(Color.primary.opacity(0.06))
			)
		}
		.menuStyle(.borderlessButton)
	}
	
	private var runningApps: [InstalledApp] {
		var apps = runningAppsByBundleIdentifier()
		addStoppedWatchedApps(to: &apps)
		return sortApps(apps.values)
	}
	
	private var watchedApps: [InstalledApp] {
		runningApps.filter { pendingWatchedApps.contains($0.bundleIdentifier) }
	}
	
	private var availableApps: [InstalledApp] {
		runningApps.filter { !pendingWatchedApps.contains($0.bundleIdentifier) }
	}
	
	private var hasChanges: Bool {
		schedule != viewModel.schedulerManager.currentSchedule ||
		pendingWatchedApps != viewModel.appMonitor.currentWatchedApps
	}
	
	private func appGroup(title: String, apps: [InstalledApp]) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			Text(title)
				.font(.caption.weight(.semibold))
				.foregroundStyle(.secondary)
				.textCase(.uppercase)
				.padding(.horizontal, 14)
				.padding(.top, 12)
				.padding(.bottom, 6)
			
			if apps.isEmpty {
				Text("No apps in this section.")
					.font(.callout)
					.foregroundStyle(.secondary)
					.padding(.horizontal, 14)
					.padding(.bottom, 12)
			} else {
				ForEach(Array(apps.enumerated()), id: \.element.bundleIdentifier) { index, app in
					if index > 0 {
						SettingsDivider()
					}
					
					appRow(app)
				}
			}
		}
	}
	
	private func runningAppsByBundleIdentifier() -> [String: InstalledApp] {
		var apps: [String: InstalledApp] = [:]
		
		for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
			guard let bundleID = app.bundleIdentifier,
						let name = app.localizedName else {
				continue
			}
			
			apps[bundleID] = InstalledApp(name: name, bundleIdentifier: bundleID, icon: app.icon)
		}
		
		return apps
	}
	
	private func addStoppedWatchedApps(to apps: inout [String: InstalledApp]) {
		for bundleID in pendingWatchedApps where apps[bundleID] == nil {
			guard let app = installedApp(for: bundleID) else {
				continue
			}
			
			apps[bundleID] = app
		}
	}
	
	private func installedApp(for bundleIdentifier: String) -> InstalledApp? {
		guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
					let bundle = Bundle(url: appURL),
					let name = appDisplayName(from: bundle) else {
			return nil
		}
		
		let icon = NSWorkspace.shared.icon(forFile: appURL.path)
		return InstalledApp(name: name, bundleIdentifier: bundleIdentifier, icon: icon)
	}
	
	private func appDisplayName(from bundle: Bundle) -> String? {
		bundle.infoDictionary?["CFBundleName"] as? String ??
		bundle.infoDictionary?["CFBundleDisplayName"] as? String
	}
	
	private func sortApps(_ apps: Dictionary<String, InstalledApp>.Values) -> [InstalledApp] {
		apps.sorted {
			let firstInWatched = pendingWatchedApps.contains($0.bundleIdentifier)
			let secondInWatched = pendingWatchedApps.contains($1.bundleIdentifier)
			
			if firstInWatched != secondInWatched {
				return firstInWatched
			}
			
			return $0.name < $1.name
		}
	}
	
	private func saveChanges() {
		viewModel.schedulerManager.updateSchedule(schedule)
		viewModel.appMonitor.setWatchedApps(pendingWatchedApps)
		viewModel.refreshState()
	}
	
	private func resetToSavedValues() {
		schedule = viewModel.schedulerManager.currentSchedule
		pendingWatchedApps = viewModel.appMonitor.currentWatchedApps
	}
}

struct InstalledApp {
	let name: String
	let bundleIdentifier: String
	let icon: NSImage?
}

private struct SettingsGroup<Content: View>: View {
	@ViewBuilder let content: Content
	
	var body: some View {
		VStack(spacing: 0) {
			content
		}
		.background(
			RoundedRectangle(cornerRadius: 14, style: .continuous)
				.fill(Color.primary.opacity(0.045))
		)
		.clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
	}
}

private struct SettingsDivider: View {
	var body: some View {
		Divider()
			.padding(.leading, 60)
	}
}

private struct IconWell: View {
	let systemImage: String
	let tint: Color
	
	var body: some View {
		ZStack {
			Circle()
				.fill(tint == Color.secondary ? Color.secondary.opacity(0.2) : tint.opacity(0.16))
			
			Image(systemName: systemImage)
				.font(.system(size: 14, weight: .semibold))
				.foregroundStyle(tint)
				.symbolRenderingMode(.hierarchical)
		}
		.frame(width: 32, height: 32)
	}
}

private struct AppSelectionRow: View {
	let app: InstalledApp
	let isWatched: Bool
	let accentColor: Color
	let action: () -> Void
	
	@State private var isHovered = false
	
	var body: some View {
		Button(action: action) {
			HStack(spacing: 12) {
				appIcon
				
				Text(app.name)
					.font(.callout)
					.foregroundStyle(.primary)
					.lineLimit(1)
				
				Spacer(minLength: 0)
				
				Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
					.font(.system(size: 17, weight: .semibold))
					.foregroundStyle(isWatched ? accentColor : Color.secondary.opacity(0.55))
					.contentTransition(.symbolEffect(.replace))
			}
			.padding(.horizontal, 14)
			.padding(.vertical, 9)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(
				RoundedRectangle(cornerRadius: 10, style: .continuous)
					.fill(rowBackground)
					.padding(.horizontal, 6)
					.padding(.vertical, 3)
			)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.onHover { isHovered = $0 }
		.animation(.easeInOut(duration: 0.12), value: isHovered)
		.animation(.snappy(duration: 0.16), value: isWatched)
	}
	
	@ViewBuilder
	private var appIcon: some View {
		if let icon = app.icon {
			Image(nsImage: icon)
				.resizable()
				.frame(width: 30, height: 30)
				.clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
		} else {
			IconWell(systemImage: "app", tint: .secondary)
		}
	}
	
	private var rowBackground: Color {
		if isWatched {
			return accentColor.opacity(isHovered ? 0.16 : 0.11)
		}
		
		return isHovered ? Color.primary.opacity(0.07) : .clear
	}
}

private struct SettingsWindowAccessor: NSViewRepresentable {
	func makeNSView(context: Context) -> NSView {
		let view = NSView()
		registerWindow(from: view)
		return view
	}
	
	func updateNSView(_ nsView: NSView, context: Context) {
		registerWindow(from: nsView)
	}
	
	private func registerWindow(from view: NSView) {
		DispatchQueue.main.async {
			guard let window = view.window else {
				return
			}
			
			SettingsWindowCoordinator.shared.register(window: window)
		}
	}
}
