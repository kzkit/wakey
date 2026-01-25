//
//  TimerDuration.swift
//  Matcha
//
//  Created by Zhen Kit Kong on 25/01/2026.
//

import Foundation

enum TimerDuration: Int, CaseIterable, Identifiable {
	case oneMinute = 60
	case fiveMinutes = 300
	case tenMinutes = 600
	case forever = 0
	
	var id: Self { self }
	
	var seconds: TimeInterval? {
		rawValue > 0 ? TimeInterval(rawValue) : nil
	}
	
	var displayName: String {
		switch self {
		case .oneMinute: return "1 minute"
		case .fiveMinutes: return "5 minutes"
		case .tenMinutes: return "10 minutes"
		case .forever: return "Forever"
		}
	}
}
