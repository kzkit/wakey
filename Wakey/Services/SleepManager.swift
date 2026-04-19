//
//  SleepManager.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import Foundation
import IOKit.pwr_mgt

final class SleepManager {
	private var assertionID: IOPMAssertionID = IOPMAssertionID(0)
	private(set) var isActive: Bool = false
	
	/// Prevents system sleep. Returns success/failure.
	func preventSleep(reason: String = "Wakey is keeping your Mac awake") -> Bool {
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
