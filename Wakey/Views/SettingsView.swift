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
	@ObservedObject private var launchAtLoginManager: LaunchAtLoginManager
	
	@State private var schedule: Schedule
	@State private var watchedApps: Set<String>
	@State private var listedApps: [String: InstalledApp] = [:]
	
	private let wakeyColor = Color.blue
	
	init(viewModel: WakeyViewModel) {
		self.viewModel = viewModel
		_launchAtLoginManager = ObservedObject(initialValue: viewModel.launchAtLoginManager)
		_schedule = State(initialValue: viewModel.schedulerManager.currentSchedule)
		_watchedApps = State(initialValue: viewModel.appMonitor.currentWatchedApps)
	}
	
	var body: some View {
		VStack(spacing: 0) {
			ScrollView {
				VStack(alignment: .leading, spacing: 22) {
					generalSection
					scheduleSection
					appSection
				}
				.padding(.horizontal, 24)
				.padding(.vertical, 22)
			}
		}
		.frame(width: 460, height: 560)
		.menuPanelWindowBackground()
		.background(SettingsWindowAccessor())
		.onAppear {
			syncSavedValues()
		}
		.onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { _ in
			refreshListedApps()
		}
		.onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in
			refreshListedApps()
		}
	}
	
	private var generalSection: some View {
		VStack(alignment: .leading, spacing: 10) {
			sectionHeader(
				icon: "gearshape.fill",
				title: "General",
				description: "Choose how Wakey starts and stays available."
			)
			
			SettingsGroup {
				launchAtLoginRow

				SettingsDivider()
				displayTurnOffRow
				
				if viewModel.hasBattery {
					SettingsDivider()
					batteryGuardRow
					
					if viewModel.isBatteryGuardEnabled {
						SettingsDivider()
						batteryThresholdRow
					}
				}
				
				if launchAtLoginManager.requiresApproval {
					SettingsDivider()
					launchAtLoginApprovalRow
				}
				
				if let errorMessage = launchAtLoginManager.errorMessage {
					SettingsDivider()
					statusMessageRow(
						systemImage: "exclamationmark.triangle.fill",
						tint: .orange,
						title: errorMessage,
						message: "Open System Settings if macOS needs your approval."
					)
				}
			}
		}
	}
	
	private var launchAtLoginRow: some View {
		HStack(spacing: 12) {
			Image(systemName: "power")
				.font(.system(size: 15, weight: .semibold))
				.frame(width: 24, height: 24)
			
			VStack(alignment: .leading, spacing: 2) {
				Text("Launch at login")
					.font(.callout)
				
				Text("Open Wakey automatically when you sign in.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			
			Spacer(minLength: 0)
			
			Toggle("", isOn: Binding(
				get: { launchAtLoginManager.isEnabled },
				set: { launchAtLoginManager.setEnabled($0) }
			))
			.labelsHidden()
			.toggleStyle(.switch)
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
	}

	private var displayTurnOffRow: some View {
		HStack(spacing: 12) {
			Image(systemName: "display")
				.font(.system(size: 15, weight: .semibold))
				.frame(width: 24, height: 24)

			VStack(alignment: .leading, spacing: 2) {
				Text("Let display turn off")
					.font(.callout)

				Text("Your Mac stays awake; the screen follows macOS display settings.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			Spacer(minLength: 0)

			Toggle("", isOn: Binding(
				get: { viewModel.letsDisplayTurnOff },
				set: { viewModel.setLetsDisplayTurnOff($0) }
			))
			.labelsHidden()
			.toggleStyle(.switch)
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
	}
	
	private var batteryGuardRow: some View {
		HStack(spacing: 12) {
			Image(systemName: "battery.25")
				.font(.system(size: 15, weight: .semibold))
				.frame(width: 24, height: 24)

			VStack(alignment: .leading, spacing: 2) {
				Text("Battery guard")
					.font(.callout)

				Text("Let your Mac sleep when the battery is low or Low Power Mode is on.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			Spacer(minLength: 0)

			Toggle("", isOn: Binding(
				get: { viewModel.isBatteryGuardEnabled },
				set: { viewModel.setBatteryGuardEnabled($0) }
			))
			.labelsHidden()
			.toggleStyle(.switch)
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
	}

	private var batteryThresholdRow: some View {
		HStack(spacing: 12) {
			Image(systemName: "gauge.with.dots.needle.33percent")
				.font(.system(size: 15, weight: .semibold))
				.frame(width: 24, height: 24)

			Text("Low battery level")
				.font(.callout)

			Spacer(minLength: 0)

			ValueMenu(title: L10n.format("%lld%%", viewModel.batteryGuardThreshold)) {
				ForEach(BatteryGuard.thresholdOptions, id: \.self) { threshold in
					Button(L10n.format("%lld%%", threshold)) {
						viewModel.setBatteryGuardThreshold(threshold)
					}
				}
			}
			.fixedSize()
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
		.transition(.opacity.combined(with: .move(edge: .top)))
	}
	
	private var launchAtLoginApprovalRow: some View {
		HStack(spacing: 12) {
			Image(systemName: "checkmark.shield.fill")
				.font(.system(size: 15, weight: .semibold))
				.frame(width: 24, height: 24)
			VStack(alignment: .leading, spacing: 2) {
				Text("Approval required")
					.font(.callout)
				
				Text("macOS needs approval before Wakey can launch at login.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			
			Spacer(minLength: 0)
			
			Button("Open System Settings") {
				launchAtLoginManager.openSystemSettings()
			}
			.buttonStyle(.borderless)
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
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
					activeDaysRow
					
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
			
			Toggle("", isOn: Binding(
				get: { schedule.isEnabled },
				set: { updateSchedule(isEnabled: $0) }
			))
			.labelsHidden()
			.toggleStyle(.switch)
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
	}
	
	private var activeHoursRow: some View {
		HStack(spacing: 12) {
			Image(systemName: "timer")
				.font(.system(size: 15, weight: .semibold))
				.frame(width: 24, height: 24)
			
			Text("Active hours")
				.font(.callout)
			
			Spacer(minLength: 0)
			
			HStack(spacing: 8) {
				timeField(minute: schedule.startMinute, accessibilityLabel: L10n.string("Start time")) { minute in
					updateSchedule(startMinute: minute)
				}
				
				Text("to")
					.font(.callout)
					.foregroundStyle(.secondary)
					.fixedSize()
				
				timeField(minute: schedule.endMinute, accessibilityLabel: L10n.string("End time")) { minute in
					updateSchedule(endMinute: minute)
				}
			}
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
		.transition(.opacity.combined(with: .move(edge: .top)))
	}
	
	private var activeDaysRow: some View {
		HStack(alignment: .top, spacing: 12) {
			Image(systemName: "calendar")
				.font(.system(size: 15, weight: .semibold))
				.frame(width: 24, height: 24)
			
			VStack(alignment: .leading, spacing: 8) {
				Text("Active days")
					.font(.callout)
					.frame(minHeight: 24)
				
				// Zero spacing keeps neighbouring chips from melting into each other at rest.
				GlassGroup(spacing: 0) {
					HStack(spacing: 6) {
						ForEach(Schedule.orderedWeekdays(firstWeekday: Calendar.current.firstWeekday), id: \.self) { weekday in
							weekdayChip(weekday)
						}
					}
				}
				
				if schedule.weekdays.isEmpty {
					Text("Choose at least one day, or the schedule won't run.")
						.font(.caption)
						.foregroundStyle(.orange)
						.fixedSize(horizontal: false, vertical: true)
				}
			}
			.frame(maxWidth: .infinity, alignment: .leading)
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
		.transition(.opacity.combined(with: .move(edge: .top)))
	}
	
	/// Names days in Wakey's own language, which can differ from the region's when a per-app language is set.
	/// The order of days still follows the region via `Calendar.current.firstWeekday`.
	private var weekdaySymbolCalendar: Calendar {
		var calendar = Calendar.current
		if let language = Bundle.main.preferredLocalizations.first {
			calendar.locale = Locale(identifier: language)
		}
		return calendar
	}
	
	private func weekdayChip(_ weekday: Int) -> some View {
		let calendar = weekdaySymbolCalendar
		let isSelected = schedule.weekdays.contains(weekday)
		
		return Button {
			toggleWeekday(weekday)
		} label: {
			Text(calendar.shortStandaloneWeekdaySymbols[weekday - 1])
				.font(.subheadline.weight(isSelected ? .semibold : .regular))
				.lineLimit(1)
				.frame(maxWidth: .infinity, minHeight: 26)
				.chipStyle(isSelected: isSelected, tint: wakeyColor)
				.contentShape(Capsule(style: .continuous))
		}
		.buttonStyle(.plain)
		.accessibilityLabel(calendar.standaloneWeekdaySymbols[weekday - 1])
		.accessibilityAddTraits(isSelected ? .isSelected : [])
		.animation(.snappy(duration: 0.16), value: isSelected)
	}
	
	private var scheduleActiveRow: some View {
		let isPausedForLowBattery = viewModel.batteryGuardReason != nil
		
		return HStack(spacing: 12) {
			Image(systemName: isPausedForLowBattery ? "pause.fill" : "checkmark")
				.font(.system(size: 15, weight: .semibold))
				.frame(width: 24, height: 24)
			VStack(alignment: .leading, spacing: 2) {
				Text(L10n.string(isPausedForLowBattery ? "Schedule paused — low battery" : "Schedule active now"))
					.font(.callout)
				
				Text(L10n.string(isPausedForLowBattery ? "Resumes automatically when the battery is no longer low." : "Wakey is currently preventing sleep from this rule."))
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			
			Spacer(minLength: 0)
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
	}
	
	private var appSection: some View {
		let appSections = categorizedApps
		
		return VStack(alignment: .leading, spacing: 10) {
			sectionHeader(
				icon: "bolt.badge.automatic.fill",
				title: "Watched Apps",
				description: "Selected apps keep your Mac awake while they are open."
			)
			
			SettingsGroup {
				if appSections.isEmpty {
					emptyAppsRow
				} else {
					if !appSections.watched.isEmpty {
						appGroup(title: "Watching", apps: appSections.watched)
					}
					appGroup(
						title: appSections.watched.isEmpty ? "Available Apps" : "Available While Open",
						apps: appSections.available
					)
				}
			}
		}
	}
	
	private var emptyAppsRow: some View {
		HStack(spacing: 12) {
			Image(systemName: "app.dashed")
				.font(.system(size: 15, weight: .semibold))
				.frame(width: 24, height: 24)
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
		let isWatched = watchedApps.contains(app.bundleIdentifier)
		
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
	
	private func sectionHeader(icon: String, title: String, description: String) -> some View {
		HStack(alignment: .top, spacing: 10) {
			Image(systemName: icon)
				.font(.system(size: 15, weight: .semibold))
				.foregroundStyle(wakeyColor)
				.frame(width: 22, height: 22)
			
			VStack(alignment: .leading, spacing: 2) {
				Text(L10n.string(title))
					.font(.subheadline.weight(.semibold))
				
				Text(L10n.string(description))
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}
	
	private func updateSchedule(
		isEnabled: Bool? = nil,
		startMinute: Int? = nil,
		endMinute: Int? = nil,
		weekdays: Set<Int>? = nil
	) {
		var updatedSchedule = schedule
		if let isEnabled {
			updatedSchedule.isEnabled = isEnabled
		}
		if let startMinute {
			updatedSchedule.startMinute = startMinute
		}
		if let endMinute {
			updatedSchedule.endMinute = endMinute
		}
		if let weekdays {
			updatedSchedule.weekdays = weekdays
		}
		
		schedule = updatedSchedule
		viewModel.schedulerManager.updateSchedule(updatedSchedule)
		viewModel.refreshState()
	}
	
	private func toggleWeekday(_ weekday: Int) {
		var weekdays = schedule.weekdays
		if weekdays.contains(weekday) {
			weekdays.remove(weekday)
		} else {
			weekdays.insert(weekday)
		}
		
		updateSchedule(weekdays: weekdays)
	}
	
	private func toggleWatchedApp(bundleIdentifier: String, isWatched: Bool) {
		if isWatched {
			watchedApps.remove(bundleIdentifier)
		} else {
			watchedApps.insert(bundleIdentifier)
		}
		
		viewModel.appMonitor.setWatchedApps(watchedApps)
		viewModel.refreshState()
		refreshListedApps()
	}
	
	private func timeField(minute: Int, accessibilityLabel: String, onChange: @escaping (Int) -> Void) -> some View {
		TimeOfDayField(minute: minute, accessibilityLabel: accessibilityLabel, onChange: onChange)
			.fixedSize()
			.padding(.horizontal, 8)
			.padding(.vertical, 4)
			.background(
				RoundedRectangle(cornerRadius: 7, style: .continuous)
					.fill(SystemFill.secondary.color(fallbackOpacity: 0.06))
			)
	}
	
	private var categorizedApps: (watched: [InstalledApp], available: [InstalledApp], isEmpty: Bool) {
		let sortedApps = sortApps(listedApps.values)
		
		return (
			watched: sortedApps.filter { watchedApps.contains($0.bundleIdentifier) },
			available: sortedApps.filter { !watchedApps.contains($0.bundleIdentifier) },
			isEmpty: sortedApps.isEmpty
		)
	}
	
	private func appGroup(title: String, apps: [InstalledApp]) -> some View {
		VStack(alignment: .leading, spacing: 0) {
			Text(L10n.string(title))
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
					appRow(app)
				}
			}
		}
	}
	
	/// Looking up apps and their icons is expensive, so it happens on launch/quit events rather than on every view update.
	private func refreshListedApps() {
		var apps = runningAppsByBundleIdentifier()
		addStoppedWatchedApps(to: &apps)
		listedApps = apps
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
		for bundleID in watchedApps where apps[bundleID] == nil {
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
			let firstInWatched = watchedApps.contains($0.bundleIdentifier)
			let secondInWatched = watchedApps.contains($1.bundleIdentifier)
			
			if firstInWatched != secondInWatched {
				return firstInWatched
			}
			
			return $0.name < $1.name
		}
	}
	
	private func syncSavedValues() {
		schedule = viewModel.schedulerManager.currentSchedule
		watchedApps = viewModel.appMonitor.currentWatchedApps
		refreshListedApps()
		launchAtLoginManager.refreshStatus()
	}
	
	private func statusMessageRow(systemImage: String, tint: Color, title: String, message: String) -> some View {
		HStack(spacing: 12) {
			Image(systemName: systemImage)
				.font(.system(size: 15, weight: .semibold))
				.frame(width: 24, height: 24)
			VStack(alignment: .leading, spacing: 2) {
				Text(title)
					.font(.callout)
				
				Text(L10n.string(message))
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			
			Spacer(minLength: 0)
		}
		.padding(.horizontal, 14)
		.padding(.vertical, 10)
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
		.groupBackground(cornerRadius: 14, fallbackOpacity: 0.045)
	}
}

/// A time typed in place: click the hour or minute and type, or step it with the arrow keys. It's the system time
/// field, following the 12/24-hour setting, drawn without its bezel and background so it sits on the settings pill.
private struct TimeOfDayField: NSViewRepresentable {
	let minute: Int
	let accessibilityLabel: String
	let onChange: (Int) -> Void
	
	func makeCoordinator() -> Coordinator {
		Coordinator(onChange: onChange)
	}
	
	func makeNSView(context: Context) -> TimeOfDayPicker {
		let picker = TimeOfDayPicker()
		picker.datePickerStyle = .textField
		picker.datePickerElements = .hourMinute
		picker.isBezeled = false
		picker.isBordered = false
		picker.drawsBackground = false
		picker.timeZone = Schedule.timeOfDayTimeZone
		picker.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
		picker.target = context.coordinator
		picker.action = #selector(Coordinator.dateChanged(_:))
		picker.onResignFirstResponder = { [weak coordinator = context.coordinator, weak picker] in
			guard let picker else { return }
			coordinator?.commitPendingChange(from: picker)
		}
		return picker
	}
	
	func updateNSView(_ picker: TimeOfDayPicker, context: Context) {
		context.coordinator.onChange = onChange
		picker.setAccessibilityLabel(accessibilityLabel)
		
		// Don't overwrite a time that's still being typed with the saved one.
		guard !context.coordinator.hasPendingChange else { return }
		
		let date = Schedule.timeOfDayDate(forMinute: minute)
		if picker.dateValue != date {
			picker.dateValue = date
		}
	}
	
	static func dismantleNSView(_ picker: TimeOfDayPicker, coordinator: Coordinator) {
		// Teardown happens during a view update, which mustn't change state, so save on the next turn.
		DispatchQueue.main.async {
			coordinator.commitPendingChange(from: picker)
		}
	}
	
	final class Coordinator: NSObject {
		/// The picker reports the hour and the minute separately, so an hour and minute typed in a row are saved once.
		private static let commitDelay: TimeInterval = 0.8
		
		var onChange: (Int) -> Void
		private var pendingChange: DispatchWorkItem?
		
		var hasPendingChange: Bool {
			pendingChange != nil
		}
		
		init(onChange: @escaping (Int) -> Void) {
			self.onChange = onChange
		}
		
		/// The picker reports every keystroke. Save once typing pauses, or as soon as the field loses focus.
		@objc func dateChanged(_ picker: NSDatePicker) {
			pendingChange?.cancel()
			let change = DispatchWorkItem { [weak self, weak picker] in
				guard let self, let picker else { return }
				self.commitPendingChange(from: picker)
			}
			pendingChange = change
			DispatchQueue.main.asyncAfter(deadline: .now() + Self.commitDelay, execute: change)
		}
		
		func commitPendingChange(from picker: NSDatePicker) {
			guard let pendingChange else { return }
			
			pendingChange.cancel()
			self.pendingChange = nil
			onChange(Schedule.minute(ofTimeOfDay: picker.dateValue))
		}
	}
}

private final class TimeOfDayPicker: NSDatePicker {
	var onResignFirstResponder: (() -> Void)?
	private var outsideClickMonitor: Any?
	private var windowCloseObserver: NSObjectProtocol?
	
	/// Only reachable with Tab when Full Keyboard Access is on, like the switches around it. Otherwise AppKit would pick
	/// it as the first field when Settings opens and a stray keypress would change the schedule.
	override var canBecomeKeyView: Bool {
		NSApp.isFullKeyboardAccessEnabled && super.canBecomeKeyView
	}
	
	override func becomeFirstResponder() -> Bool {
		let didBecome = super.becomeFirstResponder()
		if didBecome {
			startEndingEditingOnOutsideClicks()
		}
		return didBecome
	}
	
	override func resignFirstResponder() -> Bool {
		let didResign = super.resignFirstResponder()
		if didResign {
			stopEndingEditingOnOutsideClicks()
			onResignFirstResponder?()
		}
		return didResign
	}
	
	override func viewWillMove(toWindow newWindow: NSWindow?) {
		super.viewWillMove(toWindow: newWindow)
		if newWindow == nil {
			stopEndingEditingOnOutsideClicks()
		}
	}
	
	/// Closing a window doesn't take focus from its field, so a reopened Settings window would come back with the time
	/// still being edited. End editing (and save) as the window closes instead.
	override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()
		
		if let windowCloseObserver {
			NotificationCenter.default.removeObserver(windowCloseObserver)
			self.windowCloseObserver = nil
		}
		guard let window else { return }
		
		windowCloseObserver = NotificationCenter.default.addObserver(
			forName: NSWindow.willCloseNotification,
			object: window,
			queue: .main
		) { [weak self] _ in
			guard let self, let window = self.window, window.firstResponder === self else { return }
			window.makeFirstResponder(nil)
		}
	}
	
	/// Return finishes editing, like it does in a text field.
	override func keyDown(with event: NSEvent) {
		if event.keyCode == 36 || event.keyCode == 76 {
			window?.makeFirstResponder(nil)
		} else {
			super.keyDown(with: event)
		}
	}
	
	/// Clicking elsewhere in a window doesn't take focus from a field by itself, so the hour or minute would stay
	/// highlighted. While editing, any click outside the field ends editing; the click itself still goes through.
	private func startEndingEditingOnOutsideClicks() {
		guard outsideClickMonitor == nil else { return }
		
		outsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
			guard let self, let window, event.window === window else { return event }
			
			if !bounds.contains(convert(event.locationInWindow, from: nil)) {
				window.makeFirstResponder(nil)
			}
			return event
		}
	}
	
	private func stopEndingEditingOnOutsideClicks() {
		if let outsideClickMonitor {
			NSEvent.removeMonitor(outsideClickMonitor)
			self.outsideClickMonitor = nil
		}
	}
}

/// A compact menu showing the selected value. On macOS 26+ it's the system menu button, which draws its own bezel
/// and indicator; a borderless menu there drops the hand-drawn pill and shows the chevron next to the system one.
private struct ValueMenu<Items: View>: View {
	let title: String
	@ViewBuilder let items: Items
	
	var body: some View {
		if #available(macOS 26.0, *) {
			Menu {
				items
			} label: {
				Text(title)
					.monospacedDigit()
			}
			.fixedSize()
		} else {
			Menu {
				items
			} label: {
				HStack(spacing: 6) {
					Text(title)
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
	}
}

private struct SettingsDivider: View {
	var body: some View {
		Divider()
			.padding(.leading, 60)
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
			// On macOS 26+ the highlight is concentric with the group (its 14 pt radius minus the 6 pt inset).
			.rowHighlight(rowBackground, cornerRadius: 10, minimumConcentricRadius: 8, horizontalInset: 6, verticalInset: 3)
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
			Image(systemName: "app")
				.font(.system(size: 15, weight: .semibold))
				.frame(width: 24, height: 24)
		}
	}
	
	private var rowBackground: Color {
		if isWatched {
			return accentColor.opacity(isHovered ? 0.16 : 0.11)
		}
		
		return isHovered ? SystemFill.secondary.color(fallbackOpacity: 0.07) : .clear
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
			window.title = L10n.string("Settings")
			SettingsWindowCoordinator.shared.register(window: window)
		}
	}
}
