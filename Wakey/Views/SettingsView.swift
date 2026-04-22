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

	private let wakeyGreen = Color(red: 0.4, green: 0.6, blue: 0.4)
	private let sectionBackground = Color(nsColor: .controlBackgroundColor)

	init(viewModel: WakeyViewModel) {
		self.viewModel = viewModel
		_schedule = State(initialValue: viewModel.schedulerManager.currentSchedule)
		_pendingWatchedApps = State(initialValue: viewModel.appMonitor.currentWatchedApps)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 18) {
			header
			scheduleSection
			appSection
			saveButtonRow
		}
		.padding(20)
		.frame(width: 400, height: 500)
		.background(SettingsWindowAccessor())
		.onAppear {
			resetToSavedValues()
		}
	}

	private var header: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text("Settings")
				.font(.title2.weight(.semibold))
			Text("Choose when Wakey should keep your Mac awake.")
				.font(.subheadline)
				.foregroundStyle(.secondary)
		}
		.padding(.top, 4)
	}

	private var scheduleSection: some View {
		VStack(alignment: .leading, spacing: 14) {
			sectionHeader(
				icon: "clock",
				title: "Schedule",
				description: "Automatically keep your Mac awake during a time window."
			)

			Toggle("Enable schedule", isOn: $schedule.isEnabled)

			if schedule.isEnabled {
				activeHoursRow
			}

			if viewModel.schedulerManager.isActive {
				Label("Schedule active now", systemImage: "checkmark.circle.fill")
					.foregroundStyle(.green)
					.font(.caption)
			}
		}
		.padding(16)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(sectionCard)
	}

	private var appSection: some View {
		VStack(alignment: .leading, spacing: 14) {
			sectionHeader(
				icon: "app.connected.to.app.below.fill",
				title: "Watched Apps",
				description: "Select apps that should keep your Mac awake while they are open."
			)

			Text("Running apps appear automatically. Watched apps stay listed even when they are closed.")
				.font(.caption)
				.foregroundStyle(.secondary)

			ScrollView {
				VStack(alignment: .leading, spacing: 14) {
					if !watchedApps.isEmpty {
						appGroup(title: "Watching", apps: watchedApps)
					}

					appGroup(
						title: watchedApps.isEmpty ? "Available Apps" : "Available While Open",
						apps: availableApps
					)

					if runningApps.isEmpty {
						Text("Open an app to add it here.")
							.font(.caption)
							.foregroundStyle(.secondary)
							.padding(.top, 4)
					}
				}
				.padding(.vertical, 2)
			}
			.frame(maxHeight: .infinity)
		}
		.padding(16)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.background(sectionCard)
	}

	private func appRow(_ app: InstalledApp) -> some View {
		let isWatched = pendingWatchedApps.contains(app.bundleIdentifier)

		return Button {
			withAnimation(.easeInOut(duration: 0.15)) {
				toggleWatchedApp(bundleIdentifier: app.bundleIdentifier, isWatched: isWatched)
			}
		} label: {
			HStack(spacing: 12) {
				if let icon = app.icon {
					Image(nsImage: icon)
						.resizable()
						.frame(width: 24, height: 24)
						.clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
				}

				Text(app.name)
					.font(.body)
					.foregroundStyle(.primary)

				Spacer()

				Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
					.font(.system(size: 16, weight: .semibold))
					.foregroundStyle(isWatched ? wakeyGreen : .secondary)
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 9)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(
				RoundedRectangle(cornerRadius: 10, style: .continuous)
					.fill(isWatched ? wakeyGreen.opacity(0.12) : Color.clear)
			)
			.contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
		}
		.buttonStyle(.plain)
	}

	private var saveButtonRow: some View {
		HStack {
			Spacer()
			Button("Save") {
				saveChanges()
			}
			.buttonStyle(.borderedProminent)
			.tint(wakeyGreen)
			.disabled(!hasChanges)
		}
		.padding(.top, 2)
	}

	private var activeHoursRow: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Active hours")
				.font(.caption.weight(.semibold))
				.foregroundStyle(.secondary)

			HStack(spacing: 10) {
				hourMenu(selectedHour: schedule.startHour) { selectedHour in
					schedule.startHour = selectedHour
				}

				Text("to")
					.foregroundStyle(.secondary)

				hourMenu(selectedHour: schedule.endHour) { selectedHour in
					schedule.endHour = selectedHour
				}
			}
		}
	}

	private func sectionHeader(icon: String, title: String, description: String) -> some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack(spacing: 8) {
				Image(systemName: icon)
					.foregroundStyle(wakeyGreen)
				Text(title)
			}
			.font(.headline)

			Text(description)
				.font(.subheadline)
				.foregroundStyle(.secondary)
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
				Image(systemName: "chevron.up.chevron.down")
					.font(.caption2)
					.foregroundStyle(.secondary)
			}
			.padding(.horizontal, 10)
			.padding(.vertical, 6)
			.background(
				RoundedRectangle(cornerRadius: 8, style: .continuous)
					.fill(sectionBackground)
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

	private var sectionCard: some View {
		RoundedRectangle(cornerRadius: 14, style: .continuous)
			.fill(sectionBackground)
	}

	private func appGroup(title: String, apps: [InstalledApp]) -> some View {
		VStack(alignment: .leading, spacing: 8) {
			Text(title)
				.font(.caption.weight(.semibold))
				.foregroundStyle(.secondary)

			if apps.isEmpty {
				Text("No apps in this section.")
					.font(.caption)
					.foregroundStyle(.secondary)
					.padding(.vertical, 4)
			} else {
				ForEach(apps, id: \.bundleIdentifier) { app in
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
