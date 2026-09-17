import XCTest

@testable import foqos

final class StopwatchFormatterTests: XCTestCase {
  func testFormatsElapsedClock() {
    XCTAssertEqual(StopwatchFormatter.elapsed(0), "0:00:00")
    XCTAssertEqual(StopwatchFormatter.elapsed(24 * 60 + 32), "0:24:32")
    XCTAssertEqual(StopwatchFormatter.elapsed(3600 + 2 * 60 + 5), "1:02:05")
    XCTAssertEqual(StopwatchFormatter.elapsed(12 * 3600), "12:00:00")
  }

  func testClampsNegativeInputToZero() {
    XCTAssertEqual(StopwatchFormatter.elapsed(-5), "0:00:00")
  }
}
