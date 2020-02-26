import XCTest
@testable import CloudSync

final class CloudSyncTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(CloudSync().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
