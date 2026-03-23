import XCTest
@testable import PromptPreflight

final class KeychainServiceTests: XCTestCase {
    func testSaveReadDeleteRoundTrip() throws {
        let serviceName = "PromptPreflightTests.\(UUID().uuidString)"
        let keychain = KeychainService(service: serviceName)
        let account = "test-account"

        try keychain.save(value: "secret", account: account)
        let stored = try keychain.read(account: account)
        XCTAssertEqual(stored, "secret")

        try keychain.delete(account: account)
        let deleted = try keychain.read(account: account)
        XCTAssertNil(deleted)
    }
}
