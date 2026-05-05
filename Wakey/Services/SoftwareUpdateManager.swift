//
//  SoftwareUpdateManager.swift
//  Wakey
//
//  Created by Codex on 06/05/2026.
//

import Combine
import Foundation
import Sparkle

@MainActor
final class SoftwareUpdateManager: NSObject, ObservableObject {
	static let shared = SoftwareUpdateManager()
	
	@Published private(set) var isUpdateAvailable = false
	
	private lazy var updaterController = SPUStandardUpdaterController(
		startingUpdater: true,
		updaterDelegate: self,
		userDriverDelegate: nil
	)
	private var didFindUpdateInCurrentCycle = false
	
	private override init() {
		super.init()
	}
	
	func start() {
		_ = updaterController
	}
	
	func showUpdate() {
		updaterController.checkForUpdates(nil)
	}
	
	private func setUpdateAvailable(_ isAvailable: Bool) {
		isUpdateAvailable = isAvailable
	}
}

extension SoftwareUpdateManager: SPUUpdaterDelegate {
	func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
		didFindUpdateInCurrentCycle = true
		setUpdateAvailable(true)
	}
	
	func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: any Error) {
		didFindUpdateInCurrentCycle = false
		setUpdateAvailable(false)
	}
	
	func updater(_ updater: SPUUpdater, didAbortWithError error: any Error) {
		didFindUpdateInCurrentCycle = false
		setUpdateAvailable(false)
	}
	
	func updater(
		_ updater: SPUUpdater,
		didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
		error: (any Error)?
	) {
		if error != nil || !didFindUpdateInCurrentCycle {
			setUpdateAvailable(false)
		}
		
		didFindUpdateInCurrentCycle = false
	}
}
