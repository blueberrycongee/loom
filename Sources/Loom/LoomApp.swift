import SwiftUI
import LoomCore
import LoomDesign
import LoomUI

@main
struct LoomApp: App {

    @State private var app = AppModel()
    @State private var coordinator: LibraryCoordinator?

    var body: some Scene {
        WindowGroup {
            RootScene()
                .environment(app)
                .frame(minWidth: 960, minHeight: 640)
                .preferredColorScheme(.dark)
                .background(Palette.canvas.ignoresSafeArea())
                .task {
                    // Create the coordinator on first scene appearance — it
                    // registers notification observers and resumes the last
                    // library, if any.
                    if coordinator == nil {
                        let c = LibraryCoordinator(app: app)
                        coordinator = c
                        c.bootstrap()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            AppCommands(app: app)
        }

        Settings {
            SettingsView()
                .environment(app)
                .preferredColorScheme(.dark)
        }
    }
}
