import AppKit
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class MainViewModel {
    var inputText = ""
    var responseMarkdown = ""
    var errorMessage: String?
    var infoMessage: String?
    var tokenPreflight: TokenPreflightResult?
    var isSending = false

    private let llmService: LLMService
    private var currentRequest: Task<String, Error>?

    init(llmService: LLMService) {
        self.llmService = llmService
    }

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    func runTokenPreflight(settings: AppSettingsStore) {
        let snapshot = settings.snapshot()
        let provider = snapshot.activeProvider
        let model = snapshot.model(for: provider)
        tokenPreflight = TokenEstimator.preflight(provider: provider, model: model, input: inputText)
    }

    func send(modelContext: ModelContext?, settings: AppSettingsStore) async {
        guard canSend else { return }

        let rawInput = inputText
        guard !rawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Input is empty."
            return
        }

        let snapshot = settings.snapshot()
        let provider = snapshot.activeProvider
        let model = snapshot.model(for: provider)

        let preflight = TokenEstimator.preflight(provider: provider, model: model, input: rawInput)
        tokenPreflight = preflight

        guard !preflight.exceedsLimit else {
            errorMessage = "Estimated tokens \(preflight.estimatedTokens) exceed limit \(preflight.limitTokens). Reduce input size and retry."
            return
        }

        let prompt = snapshot.effectiveSystemPrompt

        errorMessage = nil
        infoMessage = nil
        isSending = true

        let requestTask = Task {
            try await llmService.send(
                provider: provider,
                model: model,
                systemPrompt: prompt,
                inputMarkdown: rawInput,
                settings: snapshot
            )
        }
        currentRequest = requestTask

        do {
            let output = try await requestTask.value
            responseMarkdown = Self.stripTopLevelCodeFenceIfPresent(output)
            infoMessage = "Response received from \(provider.displayName)."

            try persistHistoryIfNeeded(
                output: responseMarkdown,
                provider: provider,
                model: model,
                inputText: rawInput,
                settings: snapshot,
                privateMode: settings.privateMode,
                modelContext: modelContext
            )
        } catch {
            if (error as? LLMError) == .cancelled {
                errorMessage = "Request cancelled."
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isSending = false
        currentRequest = nil
    }

    func cancelSend() {
        currentRequest?.cancel()
    }

    func clearAll() {
        inputText = ""
        responseMarkdown = ""
        tokenPreflight = nil
        errorMessage = nil
        infoMessage = nil
    }

    func copyResponseToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(responseMarkdown, forType: .string)
        infoMessage = "Response copied."
    }

    func load(entry: ChatEntry, settings: AppSettingsStore) {
        inputText = entry.inputText
        responseMarkdown = entry.outputMarkdown
        runTokenPreflight(settings: settings)
        errorMessage = nil
    }

    func cleanupExpiredHistory(settings: AppSettingsSnapshot, modelContext: ModelContext?) {
        guard settings.saveHistory, let modelContext else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -max(1, settings.retentionDays), to: .now) ?? .distantPast
        let descriptor = FetchDescriptor<ChatEntry>(predicate: #Predicate<ChatEntry> { entry in
            entry.timestamp < cutoff
        })

        guard let oldEntries = try? modelContext.fetch(descriptor) else { return }
        for entry in oldEntries {
            modelContext.delete(entry)
        }
        try? modelContext.save()
    }

    private func persistHistoryIfNeeded(
        output: String,
        provider: LLMProvider,
        model: String,
        inputText: String,
        settings: AppSettingsSnapshot,
        privateMode: Bool,
        modelContext: ModelContext?
    ) throws {
        guard settings.saveHistory, !privateMode, let modelContext else { return }

        cleanupExpiredHistory(settings: settings, modelContext: modelContext)

        let entry = ChatEntry(
            provider: provider,
            model: model,
            inputText: inputText,
            outputMarkdown: output,
            isPrivateRun: privateMode
        )
        modelContext.insert(entry)
        try modelContext.save()
    }

    private static func stripTopLevelCodeFenceIfPresent(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```"), trimmed.hasSuffix("```") else { return text }

        var lines = trimmed.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return text }
        lines.removeFirst()

        if let last = lines.last, last.trimmingCharacters(in: .whitespacesAndNewlines) == "```" {
            lines.removeLast()
            return lines.joined(separator: "\n")
        }

        return text
    }
}

extension LLMError: Equatable {
    public static func == (lhs: LLMError, rhs: LLMError) -> Bool {
        switch (lhs, rhs) {
        case (.cancelled, .cancelled):
            return true
        default:
            return false
        }
    }
}
