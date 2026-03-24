import Foundation

protocol LLMService: Sendable {
    func send(provider: LLMProvider, model: String, systemPrompt: String, inputMarkdown: String, settings: AppSettingsSnapshot) async throws -> String
}

final class LLMGateway: LLMService, @unchecked Sendable {
    private let keychain: KeychainProviding
    private let remoteTransport: HTTPTransporting
    private let ollamaTransportFactory: @Sendable (TimeInterval) -> HTTPTransporting

    init(
        keychain: KeychainProviding,
        transport: HTTPTransporting = HTTPTransport(),
        ollamaTransportFactory: @escaping @Sendable (TimeInterval) -> HTTPTransporting = { HTTPTransport(timeout: $0) }
    ) {
        self.keychain = keychain
        self.remoteTransport = transport
        self.ollamaTransportFactory = ollamaTransportFactory
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
            return OpenAIClient(apiKey: key, transport: remoteTransport)

        case .gemini:
            guard let key = try keychain.read(account: provider.keychainAccount), !key.isEmpty else {
                throw LLMError.missingAPIKey(provider)
            }
            return GeminiClient(apiKey: key, transport: remoteTransport)

        case .anthropic:
            guard let key = try keychain.read(account: provider.keychainAccount), !key.isEmpty else {
                throw LLMError.missingAPIKey(provider)
            }
            return AnthropicClient(apiKey: key, transport: remoteTransport)

        case .ollama:
            guard let baseURL = URL(string: settings.ollamaBaseURL) else {
                throw LLMError.invalidURL(settings.ollamaBaseURL)
            }
            let token = try keychain.read(account: provider.keychainAccount)
            let timeout = TimeInterval(
                min(
                    max(settings.ollamaTimeoutSeconds, AppConstants.minOllamaRequestTimeoutSeconds),
                    AppConstants.maxOllamaRequestTimeoutSeconds
                )
            )
            let transport = ollamaTransportFactory(timeout)
            return OllamaClient(baseURL: baseURL, token: token, transport: transport)
        }
    }
}
