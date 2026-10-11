import Foundation
import XCTest

extension XCTestCase {
	/// Returns a `UserDefaults` suite that is empty when the test starts and is cleared again when it finishes.
	///
	/// The suite name is fixed per test class rather than unique per test: cfprefsd writes removed domains back
	/// to disk as empty plists after the test process exits, so unique names would leave a new file behind on
	/// every run, while a fixed name keeps reusing the same one.
	func makeTestDefaults(_ component: String? = nil) -> UserDefaults {
		let suiteName = ["WakeyTests", String(describing: type(of: self)), component]
			.compactMap { $0 }
			.joined(separator: ".")
		let defaults = UserDefaults(suiteName: suiteName)!
		defaults.removePersistentDomain(forName: suiteName)
		addTeardownBlock {
			defaults.removePersistentDomain(forName: suiteName)
		}
		return defaults
	}
}
