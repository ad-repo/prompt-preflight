import Foundation
import XCTest
@testable import PromptPreflight

final class MainViewModelTests: XCTestCase {
    @MainActor
    func testSendUsesRawInputWithoutConversion() async {
        let service = MockLLMService(result: .success("formatted response"))
        let viewModel = MainViewModel(llmService: service)
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettingsStore(defaults: defaults)

        viewModel.inputText = "edited markdown"
        await viewModel.send(modelContext: nil, settings: settings)

        let sent = await service.sentRequests
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent.first?.inputMarkdown, "edited markdown")
        XCTAssertEqual(sent.first?.systemPrompt, AppConstants.defaultSystemPrompt)
        XCTAssertEqual(viewModel.responseMarkdown, "formatted response")
    }

    @MainActor
    func testSendBlocksWhenTokenLimitExceeded() async {
        let service = MockLLMService(result: .success("unused"))
        let viewModel = MainViewModel(llmService: service)
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettingsStore(defaults: defaults)

        settings.activeProvider = .ollama
        settings.ollamaModel = "llama3.2"
        viewModel.inputText = String(repeating: "x", count: 40_000)

        await viewModel.send(modelContext: nil, settings: settings)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("exceed") == true)
        let sent = await service.sentRequests
        XCTAssertTrue(sent.isEmpty)
    }

    @MainActor
    func testSendPreservesRawModelOutput() async {
        let service = MockLLMService(result: .success("""
        ### Original Query
        edited markdown

        ### Response
        **Condensed** result.
        """))
        let viewModel = MainViewModel(llmService: service)
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettingsStore(defaults: defaults)

        viewModel.inputText = "edited markdown"
        await viewModel.send(modelContext: nil, settings: settings)

        XCTAssertEqual(viewModel.responseMarkdown, """
        ### Original Query
        edited markdown

        ### Response
        **Condensed** result.
        """)
    }

    @MainActor
    func testSendStripsTopLevelMarkdownFence() async {
        let service = MockLLMService(result: .success("""
        ```markdown
        line one
        line two
        ```
        """))
        let viewModel = MainViewModel(llmService: service)
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettingsStore(defaults: defaults)

        viewModel.inputText = "any input"
        await viewModel.send(modelContext: nil, settings: settings)

        XCTAssertEqual(viewModel.responseMarkdown, """
        line one
        line two
        """)
    }
}

actor MockLLMService: LLMService {
    struct SentRequest {
        let provider: LLMProvider
        let model: String
        let systemPrompt: String
        let inputMarkdown: String
    }

    private(set) var sentRequests: [SentRequest] = []
    private let result: Result<String, Error>

    init(result: Result<String, Error>) {
        self.result = result
    }

    func send(provider: LLMProvider, model: String, systemPrompt: String, inputMarkdown: String, settings: AppSettingsSnapshot) async throws -> String {
        sentRequests.append(SentRequest(provider: provider, model: model, systemPrompt: systemPrompt, inputMarkdown: inputMarkdown))
        return try result.get()
    }
}
