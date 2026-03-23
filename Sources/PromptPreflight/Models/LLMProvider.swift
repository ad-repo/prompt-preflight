import Foundation

enum LLMProvider: String, CaseIterable, Identifiable, Codable {
    case openAI
    case gemini
    case anthropic
    case ollama

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .gemini:
            return "Gemini"
        case .anthropic:
            return "Anthropic"
        case .ollama:
            return "Ollama"
        }
    }

    var keychainAccount: String {
        switch self {
        case .openAI:
            return "openai-api-key"
        case .gemini:
            return "gemini-api-key"
        case .anthropic:
            return "anthropic-api-key"
        case .ollama:
            return "ollama-token"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI:
            return "gpt-4o-mini"
        case .gemini:
            return "gemini-2.0-flash"
        case .anthropic:
            return "claude-3-5-sonnet-latest"
        case .ollama:
            return "llama3.2"
        }
    }

    var defaultTokenLimit: Int {
        switch self {
        case .openAI:
            return 128_000
        case .gemini:
            return 1_000_000
        case .anthropic:
            return 200_000
        case .ollama:
            return 8_192
        }
    }
}
