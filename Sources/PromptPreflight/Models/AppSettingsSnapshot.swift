import Foundation

struct AppSettingsSnapshot {
    var activeProvider: LLMProvider
    var modelByProvider: [LLMProvider: String]
    var promptOverride: String
    var saveHistory: Bool
    var retentionDays: Int
    var ollamaBaseURL: String
    var ollamaTimeoutSeconds: Int

    func model(for provider: LLMProvider) -> String {
        modelByProvider[provider, default: provider.defaultModel]
    }

    var effectiveSystemPrompt: String {
        let trimmed = promptOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? AppConstants.defaultSystemPrompt : trimmed
    }
}
