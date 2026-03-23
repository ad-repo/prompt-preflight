import Foundation
import XCTest
@testable import PromptPreflight

final class RetryPolicyTests: XCTestCase {
    func testTransientStatusCodes() {
        XCTAssertTrue(HTTPRetryPolicy.isTransientStatus(429))
        XCTAssertTrue(HTTPRetryPolicy.isTransientStatus(503))
        XCTAssertFalse(HTTPRetryPolicy.isTransientStatus(404))
    }

    func testAuthStatusCodes() {
        XCTAssertTrue(HTTPRetryPolicy.isAuthStatus(401))
        XCTAssertTrue(HTTPRetryPolicy.isAuthStatus(403))
        XCTAssertFalse(HTTPRetryPolicy.isAuthStatus(500))
    }

    func testTransientURLErrorClassification() {
        XCTAssertTrue(HTTPRetryPolicy.isTransientError(URLError(.timedOut)))
        XCTAssertFalse(HTTPRetryPolicy.isTransientError(URLError(.badURL)))
    }
}
