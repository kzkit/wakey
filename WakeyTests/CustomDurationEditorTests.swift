import XCTest
@testable import Wakey

final class CustomDurationEditorTests: XCTestCase {
	func testSanitizedNumberKeepsValidValues() {
		XCTAssertEqual(CustomDurationEditor.sanitizedNumber("", upperBound: 59), "")
		XCTAssertEqual(CustomDurationEditor.sanitizedNumber("0", upperBound: 59), "0")
		XCTAssertEqual(CustomDurationEditor.sanitizedNumber("45", upperBound: 59), "45")
	}
	
	func testSanitizedNumberDropsNonDigitsAndLeadingZeros() {
		XCTAssertEqual(CustomDurationEditor.sanitizedNumber("1a", upperBound: 23), "1")
		XCTAssertEqual(CustomDurationEditor.sanitizedNumber("abc", upperBound: 23), "")
		XCTAssertEqual(CustomDurationEditor.sanitizedNumber("07", upperBound: 59), "7")
	}
	
	func testSanitizedNumberClampsToUpperBoundAndTwoDigits() {
		XCTAssertEqual(CustomDurationEditor.sanitizedNumber("75", upperBound: 59), "59")
		XCTAssertEqual(CustomDurationEditor.sanitizedNumber("30", upperBound: 23), "23")
		XCTAssertEqual(CustomDurationEditor.sanitizedNumber("123", upperBound: 59), "12")
	}
	
	func testSanitizedNumberAcceptsFullWidthDigits() {
		XCTAssertEqual(CustomDurationEditor.sanitizedNumber("１２", upperBound: 23), "12")
	}
}
