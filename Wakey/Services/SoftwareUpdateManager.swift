//
//  SoftwareUpdateManager.swift
//  Wakey
//
//  Created by Codex on 06/05/2026.
//

import Combine
import Foundation
#if DIRECT_DISTRIBUTION
import Sparkle
#endif

@MainActor
final class SoftwareUpdateManager: NSObject, ObservableObject {
	static let shared = SoftwareUpdateManager()
	
	@Published private(set) var isUpdateAvailable = false
	
#if DIRECT_DISTRIBUTION
	private lazy var updaterController = SPUStandardUpdaterController(
		startingUpdater: true,
		updaterDelegate: self,
		userDriverDelegate: nil
	)
	private var didFindUpdateInCurrentCycle = false
#endif
	
	private override init() {
		super.init()
	}
	
	func start() {
#if DIRECT_DISTRIBUTION
		_ = updaterController
		checkForUpdateInformation()
#endif
	}
	
	func showUpdate() {
#if DIRECT_DISTRIBUTION
		updaterController.checkForUpdates(nil)
#endif
	}
	
#if DIRECT_DISTRIBUTION
	private func checkForUpdateInformation() {
		updaterController.updater.checkForUpdateInformation()
	}
	
	private func setUpdateAvailable(_ isAvailable: Bool) {
		isUpdateAvailable = isAvailable
	}
#endif
}

#if DIRECT_DISTRIBUTION
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
#endif
