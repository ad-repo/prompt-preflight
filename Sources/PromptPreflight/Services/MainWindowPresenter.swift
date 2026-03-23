import AppKit
import SwiftData
import SwiftUI

@MainActor
final class MainWindowPresenter {
    private let settingsStore: AppSettingsStore
    private let modelContainer: ModelContainer
    private var window: NSWindow?

    init(settingsStore: AppSettingsStore, modelContainer: ModelContainer) {
        self.settingsStore = settingsStore
        self.modelContainer = modelContainer
    }

    func show() {
        ensureWindow()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func ensureWindow() {
        guard window == nil else { return }

        let rootView = MainPopoverView()
            .environment(settingsStore)
            .modelContainer(modelContainer)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = AppConstants.appName
        window.isReleasedWhenClosed = false
        window.center()
        window.contentView = NSHostingView(rootView: rootView)

        self.window = window
    }
}
