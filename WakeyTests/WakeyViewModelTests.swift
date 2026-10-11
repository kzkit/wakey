import Combine
import XCTest
@testable import Wakey

@MainActor
final class WakeyViewModelTests: XCTestCase {
	private var schedulerDefaultsSuiteName: String!
	private var appDefaultsSuiteName: String!
	private var viewModelDefaultsSuiteName: String!
	private var schedulerDefaults: UserDefaults!
	private var appDefaults: UserDefaults!
	private var viewModelDefaults: UserDefaults!
	private var now: Date!
	private var clockNow: ContinuousClock.Instant!
	private var runningApplications: MockRunningApplicationProvider!
	private var launchAtLoginService: MockViewModelLaunchAtLoginService!
	private var sleepManager: MockSleepManager!
	private var notificationSender: MockNotificationSender!
	
	override func setUp() {
		super.setUp()
		schedulerDefaultsSuiteName = "WakeyTests.scheduler.\(UUID().uuidString)"
		appDefaultsSuiteName = "WakeyTests.apps.\(UUID().uuidString)"
		viewModelDefaultsSuiteName = "WakeyTests.viewModel.\(UUID().uuidString)"
		schedulerDefaults = UserDefaults(suiteName: schedulerDefaultsSuiteName)
		appDefaults = UserDefaults(suiteName: appDefaultsSuiteName)
		viewModelDefaults = UserDefaults(suiteName: viewModelDefaultsSuiteName)
		schedulerDefaults.removePersistentDomain(forName: schedulerDefaultsSuiteName)
		appDefaults.removePersistentDomain(forName: appDefaultsSuiteName)
		viewModelDefaults.removePersistentDomain(forName: viewModelDefaultsSuiteName)
		now = Self.date(hour: 10)
		clockNow = ContinuousClock.now
		runningApplications = MockRunningApplicationProvider()
		launchAtLoginService = MockViewModelLaunchAtLoginService()
		sleepManager = MockSleepManager()
		notificationSender = MockNotificationSender()
	}
	
	override func tearDown() {
		schedulerDefaults.removePersistentDomain(forName: schedulerDefaultsSuiteName)
		appDefaults.removePersistentDomain(forName: appDefaultsSuiteName)
		viewModelDefaults.removePersistentDomain(forName: viewModelDefaultsSuiteName)
		schedulerDefaults = nil
		appDefaults = nil
		viewModelDefaults = nil
		schedulerDefaultsSuiteName = nil
		appDefaultsSuiteName = nil
		viewModelDefaultsSuiteName = nil
		now = nil
		clockNow = nil
		runningApplications = nil
		launchAtLoginService = nil
		sleepManager = nil
		notificationSender = nil
		super.tearDown()
	}
	
	func testInitialStateIsInactive() {
		let viewModel = makeViewModel()
		
		XCTAssertFalse(viewModel.isActive)
		XCTAssertFalse(viewModel.canStop)
		XCTAssertEqual(viewModel.statusText, "Inactive")
		XCTAssertEqual(sleepManager.preventSleepCallCount, 0)
	}
	
	func testStartForeverActivatesUntilStopped() {
		let viewModel = makeViewModel()
		
		viewModel.start(duration: .forever)
		
		XCTAssertTrue(viewModel.isActive)
		XCTAssertTrue(viewModel.canStop)
		XCTAssertNil(viewModel.remainingSeconds)
		XCTAssertEqual(viewModel.statusText, "Forever")
		XCTAssertEqual(sleepManager.preventSleepCallCount, 1)
		XCTAssertEqual(sleepManager.displayBehaviors, [.keepDisplayAwake])
		
		viewModel.stop()
		
		XCTAssertFalse(viewModel.isActive)
		XCTAssertFalse(viewModel.canStop)
		XCTAssertNil(viewModel.remainingSeconds)
		XCTAssertEqual(sleepManager.allowSleepCallCount, 1)
	}

	func testStartAllowsDisplayOffWhenSettingIsEnabled() {
		let viewModel = makeViewModel()

		viewModel.setLetsDisplayTurnOff(true)
		viewModel.start(duration: .forever)

		XCTAssertTrue(viewModel.isActive)
		XCTAssertEqual(sleepManager.preventSleepCallCount, 1)
		XCTAssertEqual(sleepManager.displayBehaviors, [.allowDisplayOff])
	}

	func testDisplayOffSettingPersists() {
		let viewModel = makeViewModel()

		viewModel.setLetsDisplayTurnOff(true)
		let reloadedViewModel = makeViewModel()

		XCTAssertTrue(reloadedViewModel.letsDisplayTurnOff)
	}

	func testChangingDisplayOffSettingWhileActiveRefreshesAssertion() {
		let viewModel = makeViewModel()

		viewModel.start(duration: .forever)
		viewModel.setLetsDisplayTurnOff(true)

		XCTAssertTrue(viewModel.isActive)
		XCTAssertEqual(sleepManager.allowSleepCallCount, 1)
		XCTAssertEqual(sleepManager.preventSleepCallCount, 2)
		XCTAssertEqual(sleepManager.displayBehaviors, [.keepDisplayAwake, .allowDisplayOff])
	}
	
	func testStartTimedSessionShowsRemainingTimeAndCountsDown() {
		let viewModel = makeViewModel()
		
		viewModel.start(duration: .oneMinute)
		advanceCountdown(of: viewModel, by: 1)
		
		XCTAssertTrue(viewModel.isActive)
		XCTAssertEqual(viewModel.remainingSeconds, 59)
		XCTAssertEqual(viewModel.statusText, "0:59")
		XCTAssertEqual(notificationSender.timerEndedCallCount, 0)
	}
	
	func testCountdownEndingSendsNotificationAndStopsManualSession() {
		let viewModel = makeViewModel()
		
		viewModel.start(duration: .oneMinute)
		for _ in 0..<60 {
			advanceCountdown(of: viewModel, by: 1)
		}
		
		XCTAssertFalse(viewModel.isActive)
		XCTAssertFalse(viewModel.canStop)
		XCTAssertNil(viewModel.remainingSeconds)
		XCTAssertEqual(notificationSender.timerEndedCallCount, 1)
		XCTAssertEqual(notificationSender.lastIsStillAwake, false)
		XCTAssertEqual(sleepManager.allowSleepCallCount, 1)
	}
	
	func testCountdownFollowsWallClockWhenTicksAreDelayed() {
		let viewModel = makeViewModel()
		
		viewModel.start(duration: .oneMinute)
		advanceCountdown(of: viewModel, by: 19)
		
		XCTAssertEqual(viewModel.remainingSeconds, 41)
		XCTAssertEqual(viewModel.statusText, "0:41")
	}
	
	func testCountdownIgnoresWallClockMovingBackwards() {
		let viewModel = makeViewModel()
		
		viewModel.start(duration: .tenMinutes)
		advanceCountdown(of: viewModel, by: 60)
		now = now.addingTimeInterval(-3600)
		viewModel.advanceCountdownForTesting()
		
		XCTAssertEqual(viewModel.remainingSeconds, 540)
	}
	
	func testCountdownEndsOnFirstTickAfterDeadlinePasses() {
		let viewModel = makeViewModel()
		
		viewModel.start(duration: .fiveMinutes)
		advanceCountdown(of: viewModel, by: 600)
		
		XCTAssertFalse(viewModel.isActive)
		XCTAssertNil(viewModel.remainingSeconds)
		XCTAssertEqual(notificationSender.timerEndedCallCount, 1)
	}
	
	func testCountdownEndingWhileScheduleIsActiveReportsMacIsStillAwake() {
		let scheduler = makeSchedulerManager()
		let appMonitor = makeAppMonitor()
		let viewModel = makeViewModel(schedulerManager: scheduler, appMonitor: appMonitor)
		
		viewModel.start(duration: .oneMinute)
		scheduler.updateSchedule(Schedule(isEnabled: true, startHour: 9, endHour: 17))
		advanceCountdown(of: viewModel, by: 60)
		
		XCTAssertTrue(viewModel.isActive)
		XCTAssertFalse(viewModel.canStop)
		XCTAssertEqual(notificationSender.timerEndedCallCount, 1)
		XCTAssertEqual(notificationSender.lastIsStillAwake, true)
	}
	
	func testFailedSleepAssertionLeavesWakeyInactive() {
		sleepManager.failsToPreventSleep = true
		let viewModel = makeViewModel()
		
		viewModel.start(duration: .forever)
		
		XCTAssertFalse(viewModel.isActive)
		XCTAssertFalse(viewModel.canStop)
		XCTAssertEqual(viewModel.statusText, "Inactive")
	}
	
	func testSwitchingActiveSourcePublishesStatusChange() {
		let scheduler = makeSchedulerManager()
		let appMonitor = makeAppMonitor()
		let viewModel = makeViewModel(schedulerManager: scheduler, appMonitor: appMonitor)
		runningApplications.runningApplicationBundleIdentifiers = ["com.example.Editor"]
		appMonitor.setWatchedApps(["com.example.Editor"])
		XCTAssertEqual(viewModel.statusText, "App running")
		var changeCount = 0
		let cancellable = viewModel.objectWillChange.sink { changeCount += 1 }
		
		scheduler.updateSchedule(Schedule(isEnabled: true, startHour: 9, endHour: 17))
		
		XCTAssertTrue(viewModel.isActive)
		XCTAssertEqual(viewModel.statusText, "Scheduled run")
		XCTAssertGreaterThan(changeCount, 0)
		cancellable.cancel()
	}
	
	func testRefreshingUnchangedStateDoesNotPublishChanges() {
		let viewModel = makeViewModel()
		viewModel.start(duration: .forever)
		var changeCount = 0
		let cancellable = viewModel.objectWillChange.sink { changeCount += 1 }
		
		viewModel.refreshState()
		viewModel.refreshState()
		
		XCTAssertEqual(changeCount, 0)
		cancellable.cancel()
	}
	
	func testScheduleActivationPreventsSleepAndUsesScheduleStatus() {
		let scheduler = makeSchedulerManager()
		let appMonitor = makeAppMonitor()
		let viewModel = makeViewModel(schedulerManager: scheduler, appMonitor: appMonitor)
		
		scheduler.updateSchedule(Schedule(isEnabled: true, startHour: 9, endHour: 17))
		viewModel.refreshState()
		
		XCTAssertTrue(viewModel.isActive)
		XCTAssertFalse(viewModel.canStop)
		XCTAssertEqual(viewModel.statusText, "Scheduled run")
		XCTAssertEqual(sleepManager.preventSleepCallCount, 1)
	}
	
	func testWatchedAppActivationPreventsSleepAndUsesAppStatus() {
		let scheduler = makeSchedulerManager()
		let appMonitor = makeAppMonitor()
		let viewModel = makeViewModel(schedulerManager: scheduler, appMonitor: appMonitor)
		
		runningApplications.runningApplicationBundleIdentifiers = ["com.example.Editor"]
		appMonitor.setWatchedApps(["com.example.Editor"])
		viewModel.refreshState()
		
		XCTAssertTrue(viewModel.isActive)
		XCTAssertFalse(viewModel.canStop)
		XCTAssertEqual(viewModel.statusText, "App running")
		XCTAssertEqual(sleepManager.preventSleepCallCount, 1)
	}
	
	func testManualSessionKeepsSleepActiveWhenScheduleDeactivates() {
		let scheduler = makeSchedulerManager()
		let appMonitor = makeAppMonitor()
		let viewModel = makeViewModel(schedulerManager: scheduler, appMonitor: appMonitor)
		
		viewModel.start(duration: .forever)
		scheduler.updateSchedule(Schedule(isEnabled: false, startHour: 9, endHour: 17))
		viewModel.refreshState()
		
		XCTAssertTrue(viewModel.isActive)
		XCTAssertEqual(viewModel.statusText, "Forever")
		XCTAssertEqual(sleepManager.preventSleepCallCount, 1)
		XCTAssertEqual(sleepManager.allowSleepCallCount, 0)
	}
	
	private func makeViewModel(
		schedulerManager: SchedulerManager? = nil,
		appMonitor: AppMonitor? = nil
	) -> WakeyViewModel {
		WakeyViewModel(
			schedulerManager: schedulerManager ?? makeSchedulerManager(),
			appMonitor: appMonitor ?? makeAppMonitor(),
			launchAtLoginManager: LaunchAtLoginManager(service: launchAtLoginService),
			sleepManager: sleepManager,
			notificationSender: notificationSender,
			startsCountdownTimers: false,
			defaults: viewModelDefaults,
			now: { self.clockNow }
		)
	}
	
	private func advanceCountdown(of viewModel: WakeyViewModel, by seconds: TimeInterval) {
		clockNow = clockNow.advanced(by: .seconds(seconds))
		viewModel.advanceCountdownForTesting()
	}
	
	private func makeSchedulerManager() -> SchedulerManager {
		SchedulerManager(defaults: schedulerDefaults, dateProvider: { self.now }, startsMonitoring: false)
	}
	
	private func makeAppMonitor() -> AppMonitor {
		AppMonitor(defaults: appDefaults, applicationProvider: runningApplications, startsMonitoring: false)
	}
	
	private static func date(hour: Int) -> Date {
		Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 25, hour: hour))!
	}
}

private final class MockSleepManager: SleepManaging {
	private(set) var isActive = false
	private(set) var preventSleepCallCount = 0
	private(set) var allowSleepCallCount = 0
	private(set) var displayBehaviors: [SleepDisplayBehavior] = []
	var failsToPreventSleep = false
	
	func preventSleep(displayBehavior: SleepDisplayBehavior, reason: String) -> Bool {
		preventSleepCallCount += 1
		displayBehaviors.append(displayBehavior)
		isActive = !failsToPreventSleep
		return isActive
	}
	
	func allowSleep() {
		allowSleepCallCount += 1
		isActive = false
	}
}

private final class MockViewModelLaunchAtLoginService: LaunchAtLoginServicing {
	var status: LaunchAtLoginStatus = .notRegistered
	
	func register() throws {}
	func unregister() throws {}
	func openSystemSettingsLoginItems() {}
}

private final class MockNotificationSender: NotificationSending {
	private(set) var requestAuthorizationCallCount = 0
	private(set) var timerEndedCallCount = 0
	private(set) var lastIsStillAwake: Bool?
	
	func requestAuthorization() {
		requestAuthorizationCallCount += 1
	}
	
	func sendTimerEndedNotification(isStillAwake: Bool) {
		timerEndedCallCount += 1
		lastIsStillAwake = isStillAwake
	}
}

private final class MockRunningApplicationProvider: RunningApplicationProviding {
	var runningApplicationBundleIdentifiers: Set<String> = []
}
