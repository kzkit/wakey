//
//  TimerDuration.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import Foundation

enum TimerDuration: Hashable, Identifiable {
	/// Keeps the Mac awake for a fixed number of seconds.
	case timed(seconds: Int)
	/// Keeps the Mac awake until the session is stopped.
	case forever
	
	static let fifteenMinutes = minutes(15)
	static let thirtyMinutes = minutes(30)
	static let oneHour = minutes(60)
	static let twoHours = minutes(120)
	
	/// The countdowns offered in the menu, shortest first. `forever` and custom durations are listed separately.
	static let timedPresets: [TimerDuration] = [.fifteenMinutes, .thirtyMinutes, .oneHour, .twoHours]
	
	/// Custom durations range from 1 minute to 23 h 59 m.
	static let customMinutesRange = 1...(23 * 60 + 59)
	
	var id: Self { self }
	
	static func minutes(_ minutes: Int) -> TimerDuration {
		.timed(seconds: minutes * 60)
	}
	
	/// Returns `nil` when the total falls outside `customMinutesRange`.
	static func custom(hours: Int, minutes: Int) -> TimerDuration? {
		let totalMinutes = hours * 60 + minutes
		guard hours >= 0, minutes >= 0, customMinutesRange.contains(totalMinutes) else { return nil }
		
		return .minutes(totalMinutes)
	}
	
	var seconds: TimeInterval? {
		switch self {
		case .timed(let seconds): return TimeInterval(seconds)
		case .forever: return nil
		}
	}
	
	var displayName: String {
		switch self {
		case .fifteenMinutes: return L10n.string("15 minutes")
		case .thirtyMinutes: return L10n.string("30 minutes")
		case .oneHour: return L10n.string("1 hour")
		case .twoHours: return L10n.string("2 hours")
		case .forever: return L10n.string("Forever")
		case .timed(let seconds):
			return Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
		}
	}
}
