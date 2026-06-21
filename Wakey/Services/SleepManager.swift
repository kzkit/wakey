//
//  SleepManager.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import Foundation
import IOKit.pwr_mgt

protocol SleepManaging: AnyObject {
	var isActive: Bool { get }
	func preventSleep(reason: String) -> Bool
	func allowSleep()
}

extension SleepManaging {
	func preventSleep() -> Bool {
		preventSleep(reason: L10n.string("Wakey is keeping your Mac awake"))
	}
}

final class SleepManager: SleepManaging {
	private var assertionID: IOPMAssertionID = IOPMAssertionID(0)
	private(set) var isActive: Bool = false
	
	/// Prevents system sleep. Returns success/failure.
	func preventSleep(reason: String = L10n.string("Wakey is keeping your Mac awake")) -> Bool {
		guard !isActive else { return true }
		
		let result = IOPMAssertionCreateWithName(
			kIOPMAssertPreventUserIdleDisplaySleep as CFString,
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
