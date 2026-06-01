import SwiftUI

@main
struct MoguApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 920, minHeight: 620)
        }

        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
