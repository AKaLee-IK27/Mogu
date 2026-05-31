import SwiftUI

@main
struct MoleMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 920, minHeight: 620)
        }
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
