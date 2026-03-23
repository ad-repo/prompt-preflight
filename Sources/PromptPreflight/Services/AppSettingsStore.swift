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

    var privateMode: Bool = false
    var keepPinnedWindowOpen: Bool = false

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.activeProvider = LLMProvider(rawValue: defaults.string(forKey: Keys.activeProvider) ?? "") ?? .openAI
        self.openAIModel = defaults.string(forKey: Keys.openAIModel) ?? LLMProvider.openAI.defaultModel
        self.geminiModel = defaults.string(forKey: Keys.geminiModel) ?? LLMProvider.gemini.defaultModel
        self.anthropicModel = defaults.string(forKey: Keys.anthropicModel) ?? LLMProvider.anthropic.defaultModel
        self.ollamaModel = defaults.string(forKey: Keys.ollamaModel) ?? LLMProvider.ollama.defaultModel
        self.promptOverride = defaults.string(forKey: Keys.promptOverride) ?? ""
        self.saveHistory = defaults.object(forKey: Keys.saveHistory) as? Bool ?? true
        self.retentionDays = defaults.object(forKey: Keys.retentionDays) as? Int ?? 30
        self.ollamaBaseURL = defaults.string(forKey: Keys.ollamaBaseURL) ?? "http://localhost:11434"
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
            ollamaBaseURL: ollamaBaseURL
        )
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
}
