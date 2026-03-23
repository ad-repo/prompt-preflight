import Foundation

protocol LLMService: Sendable {
    func send(provider: LLMProvider, model: String, systemPrompt: String, inputMarkdown: String, settings: AppSettingsSnapshot) async throws -> String
}

final class LLMGateway: LLMService, @unchecked Sendable {
    private let keychain: KeychainProviding
    private let transport: HTTPTransporting

    init(keychain: KeychainProviding, transport: HTTPTransporting = HTTPTransport()) {
        self.keychain = keychain
        self.transport = transport
    }

    func send(provider: LLMProvider, model: String, systemPrompt: String, inputMarkdown: String, settings: AppSettingsSnapshot) async throws -> String {
        let client = try clientFor(provider: provider, settings: settings)
        return try await client.send(inputMarkdown: inputMarkdown, systemPrompt: systemPrompt, model: model)
    }

    private func clientFor(provider: LLMProvider, settings: AppSettingsSnapshot) throws -> LLMClient {
        switch provider {
        case .openAI:
            guard let key = try keychain.read(account: provider.keychainAccount), !key.isEmpty else {
                throw LLMError.missingAPIKey(provider)
            }
            return OpenAIClient(apiKey: key, transport: transport)

        case .gemini:
            guard let key = try keychain.read(account: provider.keychainAccount), !key.isEmpty else {
                throw LLMError.missingAPIKey(provider)
            }
            return GeminiClient(apiKey: key, transport: transport)

        case .anthropic:
            guard let key = try keychain.read(account: provider.keychainAccount), !key.isEmpty else {
                throw LLMError.missingAPIKey(provider)
            }
            return AnthropicClient(apiKey: key, transport: transport)

        case .ollama:
            guard let baseURL = URL(string: settings.ollamaBaseURL) else {
                throw LLMError.invalidURL(settings.ollamaBaseURL)
            }
            let token = try keychain.read(account: provider.keychainAccount)
            return OllamaClient(baseURL: baseURL, token: token, transport: transport)
        }
    }
}
