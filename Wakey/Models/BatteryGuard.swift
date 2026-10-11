//
//  BatteryGuard.swift
//  Wakey
//
//  Created by Claude on 11/10/2026.
//

import Foundation

struct BatteryState: Equatable {
	var hasBattery: Bool
	var isOnBatteryPower: Bool
	/// `nil` when macOS doesn't report a charge level.
	var levelPercent: Int?
	var isLowPowerModeEnabled: Bool

	static let noBattery = BatteryState(
		hasBattery: false,
		isOnBatteryPower: false,
		levelPercent: nil,
		isLowPowerModeEnabled: false
	)
}

enum BatteryGuardReason: Equatable {
	case batteryLevel(Int)
	case lowPowerMode

	var message: String {
		switch self {
		case .batteryLevel(let percent):
			return L10n.format("Battery is at %lld%%.", percent)
		case .lowPowerMode:
			return L10n.string("Low Power Mode is on.")
		}
	}
}

enum BatteryGuard {
	static let thresholdOptions = [10, 20, 30]
	static let defaultThreshold = 20

	/// Low battery means running on battery power with the charge below the threshold or Low Power Mode on.
	/// On a charger, or on a Mac without a battery, the guard never applies.
	static func lowBatteryReason(for state: BatteryState, threshold: Int) -> BatteryGuardReason? {
		guard state.hasBattery, state.isOnBatteryPower else { return nil }

		if let level = state.levelPercent, level < threshold {
			return .batteryLevel(level)
		}

		return state.isLowPowerModeEnabled ? .lowPowerMode : nil
	}
}
