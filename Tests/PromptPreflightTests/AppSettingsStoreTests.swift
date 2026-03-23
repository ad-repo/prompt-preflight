import XCTest
@testable import PromptPreflight

final class AppSettingsStoreTests: XCTestCase {
    @MainActor
    func testPromptOverrideIsLoadedVerbatim() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let prompt = "custom markdown prompt"
        defaults.set(prompt, forKey: "settings.promptOverride")

        let store = AppSettingsStore(defaults: defaults)

        XCTAssertEqual(store.promptOverride, prompt)
        XCTAssertEqual(defaults.string(forKey: "settings.promptOverride"), prompt)
    }

    @MainActor
    func testCustomPromptIsNotMigrated() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let custom = "custom prompt text"
        defaults.set(custom, forKey: "settings.promptOverride")

        let store = AppSettingsStore(defaults: defaults)

        XCTAssertEqual(store.promptOverride, custom)
        XCTAssertEqual(defaults.string(forKey: "settings.promptOverride"), custom)
    }
}
