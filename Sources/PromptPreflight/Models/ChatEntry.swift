import Foundation
import SwiftData

@Model
final class ChatEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var providerRawValue: String
    var model: String
    var inputText: String
    var outputMarkdown: String
    var isPrivateRun: Bool

    init(
        id: UUID = UUID(),
        timestamp: Date = .now,
        provider: LLMProvider,
        model: String,
        inputText: String,
        outputMarkdown: String,
        isPrivateRun: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.providerRawValue = provider.rawValue
        self.model = model
        self.inputText = inputText
        self.outputMarkdown = outputMarkdown
        self.isPrivateRun = isPrivateRun
    }

    var provider: LLMProvider {
        get { LLMProvider(rawValue: providerRawValue) ?? .openAI }
        set { providerRawValue = newValue.rawValue }
    }
}
