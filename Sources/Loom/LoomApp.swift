import SwiftUI
import LoomCore
import LoomDesign
import LoomUI

@main
struct LoomApp: App {

    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootScene()
                .environment(app)
                .frame(minWidth: 960, minHeight: 640)
                .preferredColorScheme(.dark)
                .background(Palette.canvas.ignoresSafeArea())
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
