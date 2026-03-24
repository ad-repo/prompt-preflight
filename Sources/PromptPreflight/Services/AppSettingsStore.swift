import Foundation
import Observation

@MainActor
@Observable
final class AppSettingsStore {
    var activeProvider: LLMProvider {
        didSet { defaults.set(activeProvider.rawValue, forKey: Keys.activeProvider) }
    }

    var openAIModel: String {
        didSet { defaults.set(openAIModel, forKey: Keys.openAIModel) }
    }

    var geminiModel: String {
        didSet { defaults.set(geminiModel, forKey: Keys.geminiModel) }
    }

    var anthropicModel: String {
        didSet { defaults.set(anthropicModel, forKey: Keys.anthropicModel) }
    }

    var ollamaModel: String {
        didSet { defaults.set(ollamaModel, forKey: Keys.ollamaModel) }
    }

    var promptOverride: String {
        didSet { defaults.set(promptOverride, forKey: Keys.promptOverride) }
    }

    var saveHistory: Bool {
        didSet { defaults.set(saveHistory, forKey: Keys.saveHistory) }
    }

    var retentionDays: Int {
        didSet { defaults.set(retentionDays, forKey: Keys.retentionDays) }
    }

    var ollamaBaseURL: String {
        didSet { defaults.set(ollamaBaseURL, forKey: Keys.ollamaBaseURL) }
    }

    var ollamaTimeoutSeconds: Int {
        didSet {
            let sanitized = Self.sanitizeOllamaTimeoutSeconds(ollamaTimeoutSeconds)
            if ollamaTimeoutSeconds != sanitized {
                ollamaTimeoutSeconds = sanitized
                return
            }
            defaults.set(ollamaTimeoutSeconds, forKey: Keys.ollamaTimeoutSeconds)
        }
    }

    var privateMode: Bool = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.activeProvider = LLMProvider(rawValue: defaults.string(forKey: Keys.activeProvider) ?? "") ?? .openAI
        let savedOpenAIModel = defaults.string(forKey: Keys.openAIModel)
        let resolvedOpenAIModel = Self.migrateOpenAIModel(savedOpenAIModel ?? LLMProvider.openAI.defaultModel)
        self.openAIModel = resolvedOpenAIModel
        self.geminiModel = defaults.string(forKey: Keys.geminiModel) ?? LLMProvider.gemini.defaultModel
        self.anthropicModel = defaults.string(forKey: Keys.anthropicModel) ?? LLMProvider.anthropic.defaultModel
        self.ollamaModel = defaults.string(forKey: Keys.ollamaModel) ?? LLMProvider.ollama.defaultModel
        self.promptOverride = defaults.string(forKey: Keys.promptOverride) ?? ""
        self.saveHistory = defaults.object(forKey: Keys.saveHistory) as? Bool ?? true
        self.retentionDays = defaults.object(forKey: Keys.retentionDays) as? Int ?? 30
        self.ollamaBaseURL = defaults.string(forKey: Keys.ollamaBaseURL) ?? "http://localhost:11434"
        let savedTimeout = defaults.object(forKey: Keys.ollamaTimeoutSeconds) as? Int
            ?? Int(AppConstants.ollamaRequestTimeoutSeconds)
        self.ollamaTimeoutSeconds = Self.sanitizeOllamaTimeoutSeconds(savedTimeout)

        if let savedOpenAIModel, savedOpenAIModel != resolvedOpenAIModel {
            defaults.set(resolvedOpenAIModel, forKey: Keys.openAIModel)
        }

        if savedTimeout != ollamaTimeoutSeconds {
            defaults.set(ollamaTimeoutSeconds, forKey: Keys.ollamaTimeoutSeconds)
        }
    }

    func model(for provider: LLMProvider) -> String {
        switch provider {
        case .openAI:
            return openAIModel
        case .gemini:
            return geminiModel
        case .anthropic:
            return anthropicModel
        case .ollama:
            return ollamaModel
        }
    }

    func setModel(_ model: String, for provider: LLMProvider) {
        switch provider {
        case .openAI:
            openAIModel = model
        case .gemini:
            geminiModel = model
        case .anthropic:
            anthropicModel = model
        case .ollama:
            ollamaModel = model
        }
    }

    func snapshot() -> AppSettingsSnapshot {
        AppSettingsSnapshot(
            activeProvider: activeProvider,
            modelByProvider: [
                .openAI: openAIModel,
                .gemini: geminiModel,
                .anthropic: anthropicModel,
                .ollama: ollamaModel
            ],
            promptOverride: promptOverride,
            saveHistory: saveHistory,
            retentionDays: retentionDays,
            ollamaBaseURL: ollamaBaseURL,
            ollamaTimeoutSeconds: ollamaTimeoutSeconds
        )
    }
}

private extension AppSettingsStore {
    static func migrateOpenAIModel(_ model: String) -> String {
        switch model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "gpt-4.1-mini":
            return LLMProvider.openAI.defaultModel
        default:
            return model
        }
    }

    static func sanitizeOllamaTimeoutSeconds(_ timeout: Int) -> Int {
        min(max(timeout, AppConstants.minOllamaRequestTimeoutSeconds), AppConstants.maxOllamaRequestTimeoutSeconds)
    }
}

private enum Keys {
    static let activeProvider = "settings.activeProvider"
    static let openAIModel = "settings.openAIModel"
    static let geminiModel = "settings.geminiModel"
    static let anthropicModel = "settings.anthropicModel"
    static let ollamaModel = "settings.ollamaModel"
    static let promptOverride = "settings.promptOverride"
    static let saveHistory = "settings.saveHistory"
    static let retentionDays = "settings.retentionDays"
    static let ollamaBaseURL = "settings.ollamaBaseURL"
    static let ollamaTimeoutSeconds = "settings.ollamaTimeoutSeconds"
}
