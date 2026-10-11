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
	}
	
	private var hours: Int {
		get { Int(hoursText) ?? 0 }
		nonmutating set { hoursText = String(newValue) }
	}
	
	private var minutes: Int {
		get { Int(minutesText) ?? 0 }
		nonmutating set { minutesText = String(newValue) }
	}
	
	private var totalMinutes: Int? {
		guard let duration = TimerDuration.custom(hours: hours, minutes: minutes), let seconds = duration.seconds else { return nil }
		
		return Int(seconds) / 60
	}
	
	private func start() {
		guard let totalMinutes else { return }
		
		onStart(totalMinutes)
	}
	
	private func numberField(text: Binding<String>, field: Field, accessibilityLabel: String) -> some View {
		let upperBound = field == .hours ? Self.maxHours : Self.maxMinutes
		
		return TextField("", text: text, prompt: Text(verbatim: "0"))
			.labelsHidden()
			.accessibilityLabel(accessibilityLabel)
			.multilineTextAlignment(.trailing)
			.monospacedDigit()
			.frame(width: 34)
			.focused($focusedField, equals: field)
			.onSubmit(start)
			.onChange(of: text.wrappedValue) { _, newValue in
				let sanitized = Self.sanitizedNumber(newValue, upperBound: upperBound)
				if sanitized != newValue {
					text.wrappedValue = sanitized
				}
			}
	}
	
	private func unitLabel(_ title: String) -> some View {
		Text(title)
			.font(.system(size: 12))
			.foregroundStyle(.secondary)
			.fixedSize()
			.padding(.trailing, 8)
	}
	
	/// Keeps at most two digits (accepting full-width digits from input methods) and clamps them to `upperBound`.
	static func sanitizedNumber(_ text: String, upperBound: Int) -> String {
		let digits = text.compactMap(\.wholeNumberValue).filter { $0 < 10 }.prefix(2)
		guard !digits.isEmpty else { return "" }
		
		let value = digits.reduce(0) { $0 * 10 + $1 }
		return String(min(value, upperBound))
	}
}
