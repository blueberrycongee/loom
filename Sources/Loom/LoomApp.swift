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

    init() {
        devMirrorLocalizationIfNeeded()
    }

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

// MARK: — Development localization mirror

/// When running via `swift run`, Bundle.main is the raw executable directory
/// (`.build/debug/`), not an .app bundle. SPM therefore can't place resources
/// in the main bundle, so SwiftUI `Text` never finds our .strings files.
///
/// This helper detects that situation and copies the `Resources/` folder from
/// the repository root into the executable directory so that `Bundle.main`
/// behaves like a real app bundle for localization lookups. It is a no-op
/// inside a shipped `.app` or when the files are already present.
private func devMirrorLocalizationIfNeeded() {
    let fm = FileManager.default
    let mainURL = Bundle.main.bundleURL

    // Only run when Bundle.main is a plain directory, not an .app bundle.
    guard mainURL.pathExtension != "app" else { return }

    // Already mirrored?
    let enStrings = mainURL.appendingPathComponent("en.lproj/Localizable.strings")
    if fm.fileExists(atPath: enStrings.path) { return }

    // Walk up from this file (Sources/Loom/LoomApp.swift) to repo root.
    let repoRoot = URL(fileURLWithPath: #file)
        .deletingLastPathComponent() // Loom
        .deletingLastPathComponent() // Sources
        .deletingLastPathComponent() // repo root
    let resourcesDir = repoRoot.appendingPathComponent("Resources")

    guard fm.fileExists(atPath: resourcesDir.path) else { return }

    do {
        for entry in try fm.contentsOfDirectory(atPath: resourcesDir.path) {
            guard entry.hasSuffix(".lproj") else { continue }
            let src = resourcesDir.appendingPathComponent(entry)
            let dst = mainURL.appendingPathComponent(entry)
            guard !fm.fileExists(atPath: dst.path) else { continue }
            try fm.copyItem(at: src, to: dst)
        }
    } catch {
        // Non-fatal: localization simply won't work in `swift run`.
        // Developers can always build the .app instead.
    }
}
