import SwiftUI
import LoomCore
import LoomDesign
import LoomUI

@main
struct LoomApp: App {

    @State private var app = AppModel()
    @State private var coordinator: LibraryCoordinator?
    @State private var favorites = FavoritesCoordinator()
    @State private var exporter: ExportCoordinator?
    @State private var handSense: HandSenseCoordinator?

    var body: some Scene {
        WindowGroup {
            RootScene()
                .environment(app)
                .environment(\.loomFavorites, favorites)
                .environment(\.locale, app.languagePreference.locale ?? Locale.autoupdatingCurrent)
                .frame(minWidth: 960, minHeight: 640)
                .preferredColorScheme(.light)
                .background(Palette.canvas.ignoresSafeArea())
                .id(app.languagePreference.rawValue)
                .task {
                    if coordinator == nil {
                        let c = LibraryCoordinator(app: app, favorites: favorites)
                        coordinator = c
                        c.bootstrap()
                    }
                    if exporter == nil {
                        exporter = ExportCoordinator(app: app)
                    }
                    if handSense == nil {
                        let h = HandSenseCoordinator(app: app)
                        handSense = h
                        // Auto-resume capture if the user had it on
                        // previously and camera is still authorized —
                        // never cold-prompts for camera at launch.
                        h.bootstrap()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            AppCommands(app: app, favorites: favorites)
        }

        Settings {
            SettingsView()
                .environment(app)
                .environment(\.locale, app.languagePreference.locale ?? Locale.autoupdatingCurrent)
                .preferredColorScheme(.light)
                .id(app.languagePreference.rawValue)
        }
    }
}

/// Environment key so any view in LoomUI can reach the FavoritesCoordinator
/// without the top-level executable target needing to vend it down as a
/// prop chain. The coordinator is @MainActor-isolated; access site stays
/// on the main actor.
private struct LoomFavoritesKey: EnvironmentKey {
    static let defaultValue: FavoritesCoordinator? = nil
}

extension EnvironmentValues {
    var loomFavorites: FavoritesCoordinator? {
        get { self[LoomFavoritesKey.self] }
        set { self[LoomFavoritesKey.self] = newValue }
    }
}
