import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var databaseManager: DatabaseManager

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            TagManagerView()
                .tabItem {
                    Label("Tags", systemImage: "tag")
                }
        }
        .frame(width: 450, height: 350)
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        Form {
            Section {
                LabeledContent("Database Location") {
                    Text(DatabaseManager.databasePath())
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

#Preview {
    SettingsView()
        .environmentObject(DatabaseManager())
}
