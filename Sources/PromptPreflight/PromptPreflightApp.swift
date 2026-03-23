import SwiftData
import SwiftUI

@main
struct PromptPreflightApp: App {
    @State private var settingsStore = AppSettingsStore()

    private let modelContainer: ModelContainer = PromptPreflightApp.makeModelContainer()

    var body: some Scene {
        MenuBarExtra(AppConstants.appName, systemImage: "wand.and.stars") {
            MainPopoverView()
                .environment(settingsStore)
                .modelContainer(modelContainer)
        }
        .menuBarExtraStyle(.window)

        WindowGroup(id: AppConstants.pinnedWindowID) {
            MainPopoverView(isPinnedWindow: true)
                .environment(settingsStore)
                .modelContainer(modelContainer)
        }
        .defaultSize(width: 980, height: 720)
    }

    private static func makeModelContainer() -> ModelContainer {
        let schema = Schema([ChatEntry.self])
        let config = ModelConfiguration(schema: schema, url: historyStoreURL())

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            resetHistoryStore(at: historyStoreURL())
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to initialize SwiftData model container: \(error)")
            }
        }
    }

    private static func historyStoreURL() -> URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("PromptPreflight", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.store")
    }

    private static func resetHistoryStore(at storeURL: URL) {
        let fileManager = FileManager.default
        let relatedURLs = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal")
        ]

        for url in relatedURLs {
            try? fileManager.removeItem(at: url)
        }
    }
}
