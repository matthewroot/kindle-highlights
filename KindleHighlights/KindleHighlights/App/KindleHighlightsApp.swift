import SwiftUI

@main
struct KindleHighlightsApp: App {
    @StateObject private var databaseManager = DatabaseManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(databaseManager)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import Clippings...") {
                    NotificationCenter.default.post(name: .importClippings, object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command])

                Button("Export to Markdown...") {
                    NotificationCenter.default.post(name: .exportMarkdown, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command])
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(databaseManager)
        }
        #endif
    }
}

extension Notification.Name {
    static let importClippings = Notification.Name("importClippings")
    static let exportMarkdown = Notification.Name("exportMarkdown")
}
