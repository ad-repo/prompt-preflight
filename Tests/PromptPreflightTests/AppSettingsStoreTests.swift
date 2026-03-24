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

    @MainActor
    func testLegacyOpenAIModelIsMigratedToCurrentDefault() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("gpt-4.1-mini", forKey: "settings.openAIModel")

        let store = AppSettingsStore(defaults: defaults)

        XCTAssertEqual(store.openAIModel, "gpt-4o-mini")
        XCTAssertEqual(defaults.string(forKey: "settings.openAIModel"), "gpt-4o-mini")
    }

    @MainActor
    func testCustomOpenAIModelIsPreserved() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set("gpt-4.1", forKey: "settings.openAIModel")

        let store = AppSettingsStore(defaults: defaults)

        XCTAssertEqual(store.openAIModel, "gpt-4.1")
        XCTAssertEqual(defaults.string(forKey: "settings.openAIModel"), "gpt-4.1")
    }

    @MainActor
    func testOllamaTimeoutIsLoadedAndPersisted() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(240, forKey: "settings.ollamaTimeoutSeconds")

        let store = AppSettingsStore(defaults: defaults)

        XCTAssertEqual(store.ollamaTimeoutSeconds, 240)
        XCTAssertEqual(store.snapshot().ollamaTimeoutSeconds, 240)

        store.ollamaTimeoutSeconds = 300
        XCTAssertEqual(defaults.object(forKey: "settings.ollamaTimeoutSeconds") as? Int, 300)
    }
}
