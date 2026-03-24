import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss
    private let keychain: KeychainProviding
    private let showDoneButton: Bool
    private let onDone: (() -> Void)?

    @State private var openAIKey = ""
    @State private var geminiKey = ""
    @State private var anthropicKey = ""
    @State private var ollamaToken = ""
    @State private var promptDraft = ""
    @State private var statusMessage = ""
    @State private var keyPresence: [LLMProvider: Bool] = [:]

    init(
        keychain: KeychainProviding,
        showDoneButton: Bool = false,
        onDone: (() -> Void)? = nil
    ) {
        self.keychain = keychain
        self.showDoneButton = showDoneButton
        self.onDone = onDone
    }

    var body: some View {
        @Bindable var settings = settings

        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    sectionCard(title: "Provider") {
                        settingsRow(title: "Active Provider") {
                            Picker("Active Provider", selection: $settings.activeProvider) {
                                ForEach(LLMProvider.allCases) { provider in
                                    Text(provider.displayName).tag(provider)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(maxWidth: 260, alignment: .leading)
                        }

                        settingsRow(title: "OpenAI Model") {
                            TextField("OpenAI Model", text: $settings.openAIModel)
                                .textFieldStyle(.roundedBorder)
                        }

                        settingsRow(title: "Gemini Model") {
                            TextField("Gemini Model", text: $settings.geminiModel)
                                .textFieldStyle(.roundedBorder)
                        }

                        settingsRow(title: "Anthropic Model") {
                            TextField("Anthropic Model", text: $settings.anthropicModel)
                                .textFieldStyle(.roundedBorder)
                        }

                        settingsRow(title: "Ollama Model") {
                            TextField("Ollama Model", text: $settings.ollamaModel)
                                .textFieldStyle(.roundedBorder)
                        }

                        settingsRow(title: "Ollama Base URL") {
                            TextField("http://localhost:11434", text: $settings.ollamaBaseURL)
                                .textFieldStyle(.roundedBorder)
                        }

                        settingsRow(title: "Ollama Timeout") {
                            Stepper(
                                value: $settings.ollamaTimeoutSeconds,
                                in: AppConstants.minOllamaRequestTimeoutSeconds ... AppConstants.maxOllamaRequestTimeoutSeconds,
                                step: 15
                            ) {
                                Text("\(settings.ollamaTimeoutSeconds) sec")
                            }
                            .frame(maxWidth: 220, alignment: .leading)
                        }
                    }

                    sectionCard(title: "Prompt") {
                        TextEditor(text: $promptDraft)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 170)
                            .padding(8)
                            .background(textEditorBackground)
                            .onChange(of: promptDraft) { _, newValue in
                                settings.promptOverride = newValue
                            }
                    }

                    sectionCard(title: "History & Privacy") {
                        Toggle("Save History", isOn: $settings.saveHistory)
                            .toggleStyle(.switch)

                        settingsRow(title: "Retention Days") {
                            Stepper(value: $settings.retentionDays, in: 1 ... 365) {
                                Text("\(settings.retentionDays) days")
                            }
                            .disabled(!settings.saveHistory)
                            .frame(maxWidth: 220, alignment: .leading)
                        }
                    }

                    sectionCard(title: "API Keys") {
                        keyRow(
                            title: "OpenAI API Key",
                            provider: .openAI,
                            text: $openAIKey,
                            placeholder: "sk-..."
                        )

                        keyRow(
                            title: "Gemini API Key",
                            provider: .gemini,
                            text: $geminiKey,
                            placeholder: "AIza..."
                        )

                        keyRow(
                            title: "Anthropic API Key",
                            provider: .anthropic,
                            text: $anthropicKey,
                            placeholder: "sk-ant-..."
                        )

                        keyRow(
                            title: "Ollama Token (Optional)",
                            provider: .ollama,
                            text: $ollamaToken,
                            placeholder: "token"
                        )

                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
            }

            if showDoneButton {
                Divider()
                HStack {
                    Spacer()
                    Button("Done") {
                        if let onDone {
                            onDone()
                        } else {
                            dismiss()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(12)
            }
        }
        .background(windowBackground)
        .onAppear {
            let activeWindow = NSApp.keyWindow
            refreshKeyPresence()
            promptDraft = settings.promptOverride
            restoreWindowAfterSystemPrompt(activeWindow)
        }
        .onChange(of: settings.promptOverride) { _, newValue in
            if promptDraft != newValue {
                promptDraft = newValue
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func keyRow(
        title: String,
        provider: LLMProvider,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                SecureField(placeholder, text: text)
                    .textFieldStyle(.roundedBorder)

                Button("Save") {
                    saveKey(provider: provider, value: text.wrappedValue)
                    text.wrappedValue = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Clear") {
                    clearKey(provider: provider)
                    text.wrappedValue = ""
                }
                .buttonStyle(.bordered)

                Text(keyPresence[provider] == true ? "Saved" : "Not set")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func saveKey(provider: LLMProvider, value: String) {
        let activeWindow = NSApp.keyWindow
        defer { restoreWindowAfterSystemPrompt(activeWindow) }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            statusMessage = "Key for \(provider.displayName) is empty."
            return
        }

        do {
            try keychain.save(value: trimmedValue, account: provider.keychainAccount)
            let persisted = try keychain.read(account: provider.keychainAccount) ?? ""
            guard !persisted.isEmpty else {
                statusMessage = "Key save for \(provider.displayName) could not be verified."
                refreshKeyPresence()
                return
            }

            statusMessage = "Saved key for \(provider.displayName)."
            refreshKeyPresence()
        } catch {
            statusMessage = "Failed to save key for \(provider.displayName): \(error.localizedDescription)"
        }
    }

    private func clearKey(provider: LLMProvider) {
        let activeWindow = NSApp.keyWindow
        defer { restoreWindowAfterSystemPrompt(activeWindow) }

        do {
            try keychain.delete(account: provider.keychainAccount)
            statusMessage = "Cleared key for \(provider.displayName)."
            refreshKeyPresence()
        } catch {
            statusMessage = "Failed to clear key for \(provider.displayName): \(error.localizedDescription)"
        }
    }

    private func restoreWindowAfterSystemPrompt(_ window: NSWindow?) {
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            window.makeKeyAndOrderFront(nil)
        } else if let fallbackWindow = NSApp.windows.first(where: { $0.isVisible }) {
            fallbackWindow.makeKeyAndOrderFront(nil)
        }
    }

    private func refreshKeyPresence() {
        var result: [LLMProvider: Bool] = [:]
        for provider in LLMProvider.allCases {
            let key = try? keychain.read(account: provider.keychainAccount)
            result[provider] = (key ?? "").isEmpty == false
        }
        keyPresence = result
    }

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func settingsRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var textEditorBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            }
    }

    private var windowBackground: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .underPageBackgroundColor)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
