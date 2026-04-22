//
//  SettingsView.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import SwiftUI
import AppKit

struct SettingsView: View {
	@ObservedObject var viewModel: WakeyViewModel
	
	@State private var schedule: Schedule
	@State private var pendingWatchedApps: Set<String>
	
	private let wakeyGreen = Color(red: 0.4, green: 0.6, blue: 0.4)
	
	init(viewModel: WakeyViewModel) {
		self.viewModel = viewModel
		_schedule = State(initialValue: viewModel.schedulerManager.currentSchedule)
		_pendingWatchedApps = State(initialValue: viewModel.appMonitor.currentWatchedApps)
	}
	
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Settings")
				.font(.title2)
				.bold()
				.padding(.top, 8)
			
			Divider()
			
			scheduleSection
			Divider()
			appSection
			
			Spacer()
			
			saveButtonRow
		}
		.padding(20)
		.frame(width: 400, height: 500)
		.onAppear {
			resetToSavedValues()
		}
	}
	
	private var scheduleSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			sectionHeader(icon: "clock", title: "Schedule Mode")
			
			Toggle("Enable schedule", isOn: $schedule.isEnabled)
			
			activeHoursRow
			
			Label("Schedule active now", systemImage: "checkmark.circle.fill")
				.foregroundColor(.green)
				.font(.caption)
				.opacity(viewModel.schedulerManager.isActive ? 1 : 0)
		}
	}
	
	private var appSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			sectionHeader(icon: "apple.intelligence", title: "App Aware Mode")
			
			Text("Select from running apps. Open an app first if you don't see it here.")
				.font(.caption)
				.foregroundColor(.secondary)
			
			ScrollView {
				VStack(spacing: 8) {
					ForEach(runningApps, id: \.bundleIdentifier) { app in
						appRow(app)
					}
				}
			}
			.frame(height: 200)
			.border(Color.gray.opacity(0.2))
		}
	}
	
	private func appRow(_ app: InstalledApp) -> some View {
		let isWatched = pendingWatchedApps.contains(app.bundleIdentifier)
		
		return HStack {
			if let icon = app.icon {
				Image(nsImage: icon)
					.resizable()
					.frame(width: 24, height: 24)
			}
			
			Text(app.name)
				.font(.body)
			
			Spacer()
			
			Button(isWatched ? "Remove" : "Add") {
				toggleWatchedApp(bundleIdentifier: app.bundleIdentifier, isWatched: isWatched)
			}
			.buttonStyle(.bordered)
			.tint(isWatched ? .red : wakeyGreen)
		}
		.padding(.horizontal, 8)
		.padding(.vertical, 4)
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
		.padding(.bottom, 8)
	}
	
	private var activeHoursRow: some View {
		HStack {
			Text("Active hours:")
			
			hourMenu(selectedHour: schedule.startHour) { selectedHour in
				schedule.startHour = selectedHour
			}
			
			Text("to")
			
			hourMenu(selectedHour: schedule.endHour) { selectedHour in
				schedule.endHour = selectedHour
			}
		}
	}
	
	private func sectionHeader(icon: String, title: String) -> some View {
		HStack(spacing: 6) {
			Image(systemName: icon)
				.foregroundColor(wakeyGreen)
			Text(title)
		}
		.font(.headline)
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
			Text(String(format: "%02d:00", selectedHour))
				.frame(width: 50)
		}
	}
	
	private var runningApps: [InstalledApp] {
		var apps: [String: InstalledApp] = [:]
		
		// Add all running apps
		NSWorkspace.shared.runningApplications
			.filter { $0.activationPolicy == .regular }
			.forEach { app in
				guard let bundleID = app.bundleIdentifier,
							let name = app.localizedName else {
					return
				}
				let icon = app.icon
				apps[bundleID] = InstalledApp(name: name, bundleIdentifier: bundleID, icon: icon)
			}
		
		// Add watched apps that aren't currently running
		for bundleID in pendingWatchedApps where apps[bundleID] == nil {
			if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
				 let bundle = Bundle(url: appURL),
				 let name = bundle.infoDictionary?["CFBundleName"] as? String ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String {
				let icon = NSWorkspace.shared.icon(forFile: appURL.path)
				apps[bundleID] = InstalledApp(name: name, bundleIdentifier: bundleID, icon: icon)
			}
		}
		
		return apps.values.sorted {
			let firstInWatched = pendingWatchedApps.contains($0.bundleIdentifier)
			let secondInWatched = pendingWatchedApps.contains($1.bundleIdentifier)
			
			if firstInWatched != secondInWatched {
				return firstInWatched
			}
			return $0.name < $1.name
		}
	}
	
	private var hasChanges: Bool {
		schedule != viewModel.schedulerManager.currentSchedule ||
		pendingWatchedApps != viewModel.appMonitor.currentWatchedApps
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
