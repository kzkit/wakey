//
//  SleepManager.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import Foundation
import IOKit.pwr_mgt

enum SleepDisplayBehavior {
	case keepDisplayAwake
	case allowDisplayOff
}

protocol SleepManaging: AnyObject {
	var isActive: Bool { get }
	func preventSleep(displayBehavior: SleepDisplayBehavior, reason: String) -> Bool
	func allowSleep()
}

extension SleepManaging {
	func preventSleep(displayBehavior: SleepDisplayBehavior = .keepDisplayAwake) -> Bool {
		preventSleep(
			displayBehavior: displayBehavior,
			reason: L10n.string("Wakey is keeping your Mac awake")
		)
	}
}

final class SleepManager: SleepManaging {
	private var assertionID: IOPMAssertionID = IOPMAssertionID(0)
	private(set) var isActive: Bool = false
	
	/// Prevents system sleep. Returns success/failure.
	func preventSleep(
		displayBehavior: SleepDisplayBehavior = .keepDisplayAwake,
		reason: String = L10n.string("Wakey is keeping your Mac awake")
	) -> Bool {
		guard !isActive else { return true }
		
		let result = IOPMAssertionCreateWithName(
			displayBehavior.assertionType,
			IOPMAssertionLevel(kIOPMAssertionLevelOn),
			reason as CFString,
			&assertionID
		)
		
		isActive = (result == kIOReturnSuccess)
		return isActive
	}
	
	/// Allows system sleep again.
	func allowSleep() {
		guard isActive else { return }
		
		IOPMAssertionRelease(assertionID)
		assertionID = IOPMAssertionID(0)
		isActive = false
	}
	
	deinit {
		allowSleep()
	}
}

private extension SleepDisplayBehavior {
	var assertionType: CFString {
		switch self {
		case .keepDisplayAwake:
			return kIOPMAssertPreventUserIdleDisplaySleep as CFString
		case .allowDisplayOff:
			return kIOPMAssertPreventUserIdleSystemSleep as CFString
		}
	}
}
