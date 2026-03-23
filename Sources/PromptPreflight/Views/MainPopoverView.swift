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
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @Query(sort: \ChatEntry.timestamp, order: .reverse) private var entries: [ChatEntry]

    @State private var viewModel: MainViewModel
    @State private var screen: Screen = .compose
    private let keychain: KeychainProviding
    private let isPinnedWindow: Bool

    init(
        viewModel: MainViewModel = MainViewModel(
            llmService: LLMGateway(keychain: KeychainService())
        ),
        keychain: KeychainProviding = KeychainService(),
        isPinnedWindow: Bool = false
    ) {
        _viewModel = State(initialValue: viewModel)
        self.keychain = keychain
        self.isPinnedWindow = isPinnedWindow
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
        .padding(14)
        .frame(minWidth: 880, idealWidth: 980, minHeight: 620, idealHeight: 720)
        .background(windowBackground)
        .background {
            if isPinnedWindow {
                WindowLevelConfigurator(isFloating: true)
            }
        }
        .onAppear {
            if isPinnedWindow {
                settings.keepPinnedWindowOpen = true
            }
            viewModel.cleanupExpiredHistory(settings: settings.snapshot(), modelContext: modelContext)
            viewModel.runTokenPreflight(settings: settings)
        }
        .onChange(of: viewModel.inputText) { _, _ in
            viewModel.runTokenPreflight(settings: settings)
        }
        .onChange(of: settings.activeProvider) { _, _ in
            viewModel.runTokenPreflight(settings: settings)
        }
        .onDisappear {
            if isPinnedWindow {
                settings.keepPinnedWindowOpen = false
            }
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
        .controlSize(.small)
    }

    @ViewBuilder
    private func providerAndModelControls(settings: AppSettingsStore, viewModel: MainViewModel) -> some View {
        HStack(spacing: 8) {
            Picker("Provider", selection: Binding(
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
            .pickerStyle(.menu)
            .frame(width: 160)

            TextField(
                "Model",
                text: Binding(
                    get: { settings.model(for: settings.activeProvider) },
                    set: {
                        settings.setModel($0, for: settings.activeProvider)
                        viewModel.runTokenPreflight(settings: settings)
                    }
                )
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 250)
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
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

        Button {
            togglePinnedWindow(settings: settings)
        } label: {
            Label(
                settings.keepPinnedWindowOpen ? "Unpin" : "Pin",
                systemImage: settings.keepPinnedWindowOpen ? "pin.fill" : "pin"
            )
            .lineLimit(1)
        }
        .buttonStyle(.bordered)
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

        HStack {
            Label(status.message, systemImage: status.systemImage)
                .font(.caption)
                .foregroundStyle(status.color)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
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

    private func togglePinnedWindow(settings: AppSettingsStore) {
        let shouldPin = !settings.keepPinnedWindowOpen
        settings.keepPinnedWindowOpen = shouldPin

        if shouldPin {
            openWindow(id: AppConstants.pinnedWindowID)
            screen = .compose
        } else {
            dismissWindow(id: AppConstants.pinnedWindowID)
        }
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
