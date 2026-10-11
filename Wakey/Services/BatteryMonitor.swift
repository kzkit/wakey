//
//  BatteryMonitor.swift
//  Wakey
//
//  Created by Claude on 11/10/2026.
//

import Foundation
import Combine
import IOKit.ps

protocol BatteryStateProviding {
	func currentBatteryState() -> BatteryState
}

struct PowerSourceBatteryStateProvider: BatteryStateProviding {
	func currentBatteryState() -> BatteryState {
		let isLowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

		guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
					let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
					let battery = internalBatteryDescription(in: snapshot, sources: sources) else {
			var state = BatteryState.noBattery
			state.isLowPowerModeEnabled = isLowPowerModeEnabled
			return state
		}

		let providingType = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() as String?
		let batteryPowerState = battery[kIOPSPowerSourceStateKey] as? String

		return BatteryState(
			hasBattery: true,
			isOnBatteryPower: (providingType ?? batteryPowerState) == kIOPSBatteryPowerValue,
			levelPercent: levelPercent(of: battery),
			isLowPowerModeEnabled: isLowPowerModeEnabled
		)
	}

	private func internalBatteryDescription(in snapshot: CFTypeRef, sources: [CFTypeRef]) -> [String: Any]? {
		for source in sources {
			guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
						description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
						description[kIOPSIsPresentKey] as? Bool ?? true else {
				continue
			}

			return description
		}

		return nil
	}

	/// Capacities are usually already a percentage on Macs, but `kIOPSMaxCapacityKey` isn't guaranteed to be 100.
	private func levelPercent(of battery: [String: Any]) -> Int? {
		guard let current = battery[kIOPSCurrentCapacityKey] as? Int,
					let max = battery[kIOPSMaxCapacityKey] as? Int,
					max > 0 else {
			return nil
		}

		return Int((Double(current) / Double(max) * 100).rounded())
	}
}

@MainActor
final class BatteryMonitor: ObservableObject {
	@Published private(set) var state: BatteryState

	private let stateProvider: BatteryStateProviding
	private var powerSourceRunLoopSource: CFRunLoopSource?
	private var cancellables = Set<AnyCancellable>()

	convenience init() {
		self.init(stateProvider: PowerSourceBatteryStateProvider(), startsMonitoring: true)
	}

	init(stateProvider: BatteryStateProviding, startsMonitoring: Bool) {
		self.stateProvider = stateProvider
		state = stateProvider.currentBatteryState()
		if startsMonitoring {
			startMonitoring()
		}
	}

	func refresh() {
		let state = stateProvider.currentBatteryState()
		if self.state != state {
			self.state = state
		}
	}

	private func startMonitoring() {
		// IOKit fires this on the main run loop when the power source or charge level changes.
		if let source = IOPSNotificationCreateRunLoopSource(powerSourcesDidChange, nil)?.takeRetainedValue() {
			CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
			powerSourceRunLoopSource = source
		}

		// Low Power Mode changes are posted on an arbitrary thread.
		NotificationCenter.default.publisher(for: .wakeyPowerSourcesDidChange)
			.merge(with: NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange))
			.receive(on: DispatchQueue.main)
			.sink { [weak self] _ in
				self?.refresh()
			}
			.store(in: &cancellables)
	}

	deinit {
		if let powerSourceRunLoopSource {
			CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSourceRunLoopSource, .commonModes)
			CFRunLoopSourceInvalidate(powerSourceRunLoopSource)
		}
	}
}

/// The C callback can't capture the monitor, so it relays through `NotificationCenter` rather than an unretained
/// context pointer that could outlive the monitor.
private nonisolated func powerSourcesDidChange(_ context: UnsafeMutableRawPointer?) {
	NotificationCenter.default.post(name: .wakeyPowerSourcesDidChange, object: nil)
}

private extension Notification.Name {
	nonisolated static let wakeyPowerSourcesDidChange = Notification.Name("WakeyPowerSourcesDidChange")
}
