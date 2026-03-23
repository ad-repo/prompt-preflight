import SwiftData
import SwiftUI

struct MainPopoverView: View {
    private enum Screen {
        case compose
        case history
        case settings
    }

    @Environment(AppSettingsStore.self) private var settings
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ChatEntry.timestamp, order: .reverse) private var entries: [ChatEntry]

    @State private var viewModel: MainViewModel
    @State private var screen: Screen = .compose
    private let keychain: KeychainProviding

    init(
        viewModel: MainViewModel = MainViewModel(
            llmService: LLMGateway(keychain: KeychainService())
        ),
        keychain: KeychainProviding = KeychainService()
    ) {
        _viewModel = State(initialValue: viewModel)
        self.keychain = keychain
    }

    var body: some View {
        @Bindable var settings = settings
        @Bindable var viewModel = viewModel

        VStack(spacing: 14) {
            switch screen {
            case .compose:
                topControls(settings: settings, viewModel: viewModel)

                HSplitView {
                    panelContainer(title: "Input Text") {
                        VStack(alignment: .leading, spacing: 8) {
                            if let preflight = viewModel.tokenPreflight {
                                Label("Estimated Tokens: \(preflight.estimatedTokens) / \(preflight.limitTokens)", systemImage: preflight.exceedsLimit ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(preflight.exceedsLimit ? .red : .secondary)
                            }

                            TextEditor(text: $viewModel.inputText)
                                .font(.system(.body, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .background(textEditorBackground)
                        }
                    }

                    panelContainer(title: "Response Text") {
                        TextEditor(text: .constant(viewModel.responseMarkdown))
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(textEditorBackground)
                            .textSelection(.enabled)
                            .disabled(true)
                    }
                }
                .frame(minHeight: 500)

                statusBar(viewModel: viewModel)

            case .history:
                subscreenContainer(title: "History") {
                    screen = .compose
                } content: {
                    HistoryView(
                        entries: entries,
                        onSelect: { entry in
                            viewModel.load(entry: entry, settings: settings)
                            screen = .compose
                        },
                        onDone: nil
                    )
                }

            case .settings:
                subscreenContainer(title: "Settings") {
                    screen = .compose
                } content: {
                    SettingsView(
                        keychain: keychain,
                        showDoneButton: false
                    )
                    .environment(settings)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 14)
        .padding(.top, 48)
        .frame(minWidth: 880, idealWidth: 980, minHeight: 620, idealHeight: 720)
        .background(windowBackground)
        .onAppear {
            viewModel.cleanupExpiredHistory(settings: settings.snapshot(), modelContext: modelContext)
            viewModel.runTokenPreflight(settings: settings)
        }
        .onChange(of: viewModel.inputText) { _, _ in
            viewModel.runTokenPreflight(settings: settings)
        }
        .onChange(of: settings.activeProvider) { _, _ in
            viewModel.runTokenPreflight(settings: settings)
        }
    }

    @ViewBuilder
    private func topControls(settings: AppSettingsStore, viewModel: MainViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                providerAndModelControls(settings: settings, viewModel: viewModel)
                privateModeToggle(settings: settings)
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                actionButtons(settings: settings, viewModel: viewModel)
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func providerAndModelControls(settings: AppSettingsStore, viewModel: MainViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Label("Model Target", systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(settings.activeProvider.displayName.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(0.09))
                    )
            }

            HStack(spacing: 8) {
                Picker("", selection: Binding(
                    get: { settings.activeProvider },
                    set: {
                        settings.activeProvider = $0
                        viewModel.runTokenPreflight(settings: settings)
                    }
                )) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 145)

                TextField(
                    "Model ID",
                    text: Binding(
                        get: { settings.model(for: settings.activeProvider) },
                        set: {
                            settings.setModel($0, for: settings.activeProvider)
                            viewModel.runTokenPreflight(settings: settings)
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 305)
            }
        }
        .padding(10)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor),
                    Color(nsColor: .windowBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private func privateModeToggle(settings: AppSettingsStore) -> some View {
        Toggle("Private Mode", isOn: Binding(
            get: { settings.privateMode },
            set: { settings.privateMode = $0 }
        ))
        .toggleStyle(.switch)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private func actionButtons(settings: AppSettingsStore, viewModel: MainViewModel) -> some View {
        Group {
        if viewModel.isSending {
            Button {
                viewModel.cancelSend()
            } label: {
                Label("Cancel", systemImage: "xmark.circle.fill")
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .keyboardShortcut(.cancelAction)
        } else {
            Button {
                Task {
                    await viewModel.send(modelContext: modelContext, settings: settings)
                }
            } label: {
                Label("Send", systemImage: "paperplane.fill")
                    .lineLimit(1)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canSend)
            .keyboardShortcut(.defaultAction)
        }

        Button {
            viewModel.copyResponseToClipboard()
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.responseMarkdown.isEmpty)

        Button {
            viewModel.clearAll()
        } label: {
            Label("Clear", systemImage: "trash")
                .lineLimit(1)
        }
        .buttonStyle(.bordered)

        Button {
            screen = .history
        } label: {
            Label("History", systemImage: "clock.arrow.circlepath")
                .lineLimit(1)
        }
        .buttonStyle(.bordered)

        Button {
            screen = .settings
        } label: {
            Label("Settings", systemImage: "gearshape")
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private func panelContainer<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline.weight(.semibold))
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
        .frame(minWidth: AppConstants.minPanelWidth, maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func statusBar(viewModel: MainViewModel) -> some View {
        let status = statusState(viewModel: viewModel)
        let compactMessage = compactStatusMessage(status.message)

        HStack(alignment: .top, spacing: 8) {
            Image(systemName: status.systemImage)
                .font(.caption)
                .foregroundStyle(status.color)
                .padding(.top, 1)

            Text(compactMessage)
                .font(.caption)
                .foregroundStyle(status.color)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(status.message)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minHeight: 32, maxHeight: 52, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
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

    private func statusState(viewModel: MainViewModel) -> (message: String, systemImage: String, color: Color) {
        if let error = viewModel.errorMessage {
            return (error, "xmark.octagon.fill", .red)
        }

        if let info = viewModel.infoMessage {
            return (info, "checkmark.circle.fill", .secondary)
        }

        return ("Ready", "circle.fill", .secondary)
    }

    private func compactStatusMessage(_ message: String) -> String {
        let compact = message
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !compact.isEmpty else { return "Unknown status." }
        return compact
    }

    @ViewBuilder
    private func subscreenContainer<Content: View>(
        title: String,
        onDone: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline.weight(.semibold))
                Spacer()
                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.cancelAction)
            }

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
