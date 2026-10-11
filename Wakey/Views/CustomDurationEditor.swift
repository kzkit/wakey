//
//  CustomDurationEditor.swift
//  Wakey
//
//  Created by Claude on 11/10/2026.
//

import SwiftUI

/// Inline hours + minutes editor shown in the menu for starting a session of any length.
struct CustomDurationEditor: View {
	let onStart: (Int) -> Void
	let onCancel: () -> Void
	
	@State private var hoursText: String
	@State private var minutesText: String
	@FocusState private var focusedField: Field?
	
	private enum Field {
		case hours
		case minutes
	}
	
	private static let maxHours = TimerDuration.customMinutesRange.upperBound / 60
	private static let maxMinutes = 59
	private static let minuteStep = 5
	
	/// `onStart` receives the total number of minutes, which is always within `TimerDuration.customMinutesRange`.
	init(initialMinutes: Int, onStart: @escaping (Int) -> Void, onCancel: @escaping () -> Void) {
		self.onStart = onStart
		self.onCancel = onCancel
		_hoursText = State(initialValue: String(initialMinutes / 60))
		_minutesText = State(initialValue: String(initialMinutes % 60))
	}
	
	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(spacing: 4) {
				numberField(text: $hoursText, field: .hours, accessibilityLabel: L10n.string("Hours"))
				Stepper(
					L10n.string("Hours"),
					onIncrement: { hours = min(hours + 1, Self.maxHours) },
					onDecrement: { hours = max(hours - 1, 0) }
				)
				.labelsHidden()
				unitLabel(L10n.string("hr"))
				
				numberField(text: $minutesText, field: .minutes, accessibilityLabel: L10n.string("Minutes"))
				Stepper(
					L10n.string("Minutes"),
					onIncrement: { minutes = min((minutes / Self.minuteStep + 1) * Self.minuteStep, Self.maxMinutes) },
					onDecrement: { minutes = max(((minutes + Self.minuteStep - 1) / Self.minuteStep - 1) * Self.minuteStep, 0) }
				)
				.labelsHidden()
				unitLabel(L10n.string("min"))
				
				Spacer(minLength: 0)
			}
			
			GlassGroup {
				HStack(spacing: 8) {
					Spacer(minLength: 0)
					
					Button(L10n.string("Cancel"), action: onCancel)
						.secondaryActionButtonStyle()
					
					Button(L10n.string("Start"), action: start)
						.primaryActionButtonStyle()
						.disabled(totalMinutes == nil)
				}
			}
		}
		// Line the fields up with the row titles above (row padding + icon width + spacing).
		.padding(.leading, 52)
		.padding(.trailing, 16)
		.padding(.top, 2)
		.padding(.bottom, 6)
		.onAppear {
			// Focus can't be moved while the editor is still being inserted, so wait a run loop turn.
			DispatchQueue.main.async {
				focusedField = .hours
			}
		}
		.onExitCommand(perform: onCancel)
		.onChange(of: focusedField) {
			normalizeFields()
		}
	}
	
	private var hours: Int {
		get { Self.parsedNumber(hoursText, upperBound: Self.maxHours) }
		nonmutating set { hoursText = String(newValue) }
	}
	
	private var minutes: Int {
		get { Self.parsedNumber(minutesText, upperBound: Self.maxMinutes) }
		nonmutating set { minutesText = String(newValue) }
	}
	
	private var totalMinutes: Int? {
		guard let duration = TimerDuration.custom(hours: hours, minutes: minutes), let seconds = duration.seconds else { return nil }
		
		return Int(seconds) / 60
	}
	
	private func start() {
		normalizeFields()
		guard let totalMinutes else { return }
		
		onStart(totalMinutes)
	}
	
	/// Rewrites both fields to their clamped digits. This only runs on submit or when focus moves, never while typing,
	/// so text an input method is still composing (e.g. full-width digits in Japanese) is left alone.
	private func normalizeFields() {
		let sanitizedHours = Self.sanitizedNumber(hoursText, upperBound: Self.maxHours)
		if sanitizedHours != hoursText {
			hoursText = sanitizedHours
		}
		
		let sanitizedMinutes = Self.sanitizedNumber(minutesText, upperBound: Self.maxMinutes)
		if sanitizedMinutes != minutesText {
			minutesText = sanitizedMinutes
		}
	}
	
	private func numberField(text: Binding<String>, field: Field, accessibilityLabel: String) -> some View {
		TextField("", text: text, prompt: Text(verbatim: "0"))
			.labelsHidden()
			.accessibilityLabel(accessibilityLabel)
			.multilineTextAlignment(.trailing)
			.monospacedDigit()
			.frame(width: 34)
			.focused($focusedField, equals: field)
			.onSubmit(start)
	}
	
	private func unitLabel(_ title: String) -> some View {
		Text(title)
			.font(.system(size: 12))
			.foregroundStyle(.secondary)
			.fixedSize()
			.padding(.trailing, 8)
	}
	
	static func parsedNumber(_ text: String, upperBound: Int) -> Int {
		Int(sanitizedNumber(text, upperBound: upperBound)) ?? 0
	}
	
	/// Keeps at most two digits (accepting full-width digits from input methods) and clamps them to `upperBound`.
	static func sanitizedNumber(_ text: String, upperBound: Int) -> String {
		let digits = text.compactMap(\.wholeNumberValue).filter { $0 < 10 }.prefix(2)
		guard !digits.isEmpty else { return "" }
		
		let value = digits.reduce(0) { $0 * 10 + $1 }
		return String(min(value, upperBound))
	}
}
