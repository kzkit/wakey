//
//  Schedule.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import Foundation

struct Schedule: Codable, Equatable {
	var isEnabled: Bool
	var startHour: Int
	var endHour: Int
	
	static let `default` = Schedule(isEnabled: false, startHour: 9, endHour: 17)
	
	func isWithinSchedule() -> Bool {
		guard isEnabled else { return false }
		
		let now = Date()
		let calendar = Calendar.current
		let hour = calendar.component(.hour, from: now)
		
		if startHour < endHour {
			return hour >= startHour && hour < endHour
		} else {
			return hour >= startHour || hour < endHour
		}
	}
}
