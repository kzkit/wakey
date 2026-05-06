//
//  LaunchAtLoginManager.swift
//  Wakey
//
//  Created by Zhen Kit Kong on 06/05/2026.
//

import Foundation
import Combine
import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
	case notRegistered
	case enabled
	case requiresApproval
	case notFound
}

protocol LaunchAtLoginServicing {
	var status: LaunchAtLoginStatus { get }
	func register() throws
	func unregister() throws
	func openSystemSettingsLoginItems()
}

struct MainAppLaunchAtLoginService: LaunchAtLoginServicing {
	var status: LaunchAtLoginStatus {
		switch SMAppService.mainApp.status {
		case .notRegistered:
			return .notRegistered
		case .enabled:
			return .enabled
		case .requiresApproval:
			return .requiresApproval
		case .notFound:
			return .notFound
		@unknown default:
			return .notFound
		}
	}
	
	func register() throws {
		try SMAppService.mainApp.register()
	}
	
	func unregister() throws {
		try SMAppService.mainApp.unregister()
	}
	
	func openSystemSettingsLoginItems() {
		SMAppService.openSystemSettingsLoginItems()
	}
}

@MainActor
final class LaunchAtLoginManager: ObservableObject {
	@Published private(set) var status: LaunchAtLoginStatus
	@Published private(set) var errorMessage: String?
	
	private let service: LaunchAtLoginServicing
	
	convenience init() {
		self.init(service: MainAppLaunchAtLoginService())
	}
	
	init(service: LaunchAtLoginServicing) {
		self.service = service
		status = service.status
	}
	
	var isEnabled: Bool {
		status == .enabled || status == .requiresApproval
	}
	
	var requiresApproval: Bool {
		status == .requiresApproval
	}
	
	func setEnabled(_ enabled: Bool) {
		errorMessage = nil
		
		do {
			if enabled {
				try service.register()
			} else {
				try service.unregister()
			}
		} catch {
			errorMessage = "Couldn't update launch at login."
		}
		
		refreshStatus()
	}
	
	func refreshStatus() {
		status = service.status
	}
	
	func openSystemSettings() {
		service.openSystemSettingsLoginItems()
		refreshStatus()
	}
}
