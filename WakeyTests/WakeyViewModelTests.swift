import XCTest
@testable import Wakey

@MainActor
final class WakeyViewModelTests: XCTestCase {
	private var schedulerDefaultsSuiteName: String!
	private var appDefaultsSuiteName: String!
	private var schedulerDefaults: UserDefaults!
	private var appDefaults: UserDefaults!
	private var now: Date!
	private var runningApplications: MockRunningApplicationProvider!
	private var sleepManager: MockSleepManager!
	private var notificationSender: MockNotificationSender!
	
	override func setUp() {
		super.setUp()
		schedulerDefaultsSuiteName = "WakeyTests.scheduler.\(UUID().uuidString)"
		appDefaultsSuiteName = "WakeyTests.apps.\(UUID().uuidString)"
		schedulerDefaults = UserDefaults(suiteName: schedulerDefaultsSuiteName)
		appDefaults = UserDefaults(suiteName: appDefaultsSuiteName)
		schedulerDefaults.removePersistentDomain(forName: schedulerDefaultsSuiteName)
		appDefaults.removePersistentDomain(forName: appDefaultsSuiteName)
		now = Self.date(hour: 10)
		runningApplications = MockRunningApplicationProvider()
		sleepManager = MockSleepManager()
		notificationSender = MockNotificationSender()
	}
	
	override func tearDown() {
		schedulerDefaults.removePersistentDomain(forName: schedulerDefaultsSuiteName)
		appDefaults.removePersistentDomain(forName: appDefaultsSuiteName)
		schedulerDefaults = nil
		appDefaults = nil
		schedulerDefaultsSuiteName = nil
		appDefaultsSuiteName = nil
		now = nil
		runningApplications = nil
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
		
		viewModel.stop()
		
		XCTAssertFalse(viewModel.isActive)
		XCTAssertFalse(viewModel.canStop)
		XCTAssertNil(viewModel.remainingSeconds)
		XCTAssertEqual(sleepManager.allowSleepCallCount, 1)
	}
	
	func testStartTimedSessionShowsRemainingTimeAndCountsDown() {
		let viewModel = makeViewModel()
		
		viewModel.start(duration: .oneMinute)
		viewModel.advanceCountdownForTesting()
		
		XCTAssertTrue(viewModel.isActive)
		XCTAssertEqual(viewModel.remainingSeconds, 59)
		XCTAssertEqual(viewModel.statusText, "0:59")
		XCTAssertEqual(notificationSender.timerEndedCallCount, 0)
	}
	
	func testCountdownEndingSendsNotificationAndStopsManualSession() {
		let viewModel = makeViewModel()
		
		viewModel.start(duration: .oneMinute)
		for _ in 0..<60 {
			viewModel.advanceCountdownForTesting()
		}
		
		XCTAssertFalse(viewModel.isActive)
		XCTAssertFalse(viewModel.canStop)
		XCTAssertNil(viewModel.remainingSeconds)
		XCTAssertEqual(notificationSender.timerEndedCallCount, 1)
		XCTAssertEqual(sleepManager.allowSleepCallCount, 1)
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
			sleepManager: sleepManager,
			notificationSender: notificationSender,
			startsCountdownTimers: false
		)
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
	
	func preventSleep(reason: String) -> Bool {
		preventSleepCallCount += 1
		isActive = true
		return true
	}
	
	func allowSleep() {
		allowSleepCallCount += 1
		isActive = false
	}
}

private final class MockNotificationSender: NotificationSending {
	private(set) var requestAuthorizationCallCount = 0
	private(set) var timerEndedCallCount = 0
	
	func requestAuthorization() {
		requestAuthorizationCallCount += 1
	}
	
	func sendTimerEndedNotification() {
		timerEndedCallCount += 1
	}
}

private final class MockRunningApplicationProvider: RunningApplicationProviding {
	var runningApplicationBundleIdentifiers: Set<String> = []
}
