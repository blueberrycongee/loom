import SwiftUI
import LoomCore
import LoomDesign

/// Menu-bar commands and keyboard shortcuts.
///
/// Loom leans on the keyboard: Space is Shuffle, ⌘1–6 pick a style, ⌘K opens
/// the style palette. We declare them here instead of peppering views with
/// `.keyboardShortcut` so the menu bar mirrors reality.
///
/// ⚠️ macOS `Commands` does **not** read SwiftUI's `\.locale` environment,
/// so an in-app language switch would leave the menu bar stale. We work
/// around this by explicitly passing the user's language preference into
/// `String(localized:locale:)` so every menu item resolves at build-time
/// against the current app-level locale instead of the system one.
struct AppCommands: Commands {

    let app: AppModel
    let favorites: FavoritesCoordinator

    private var locale: Locale {
        app.languagePreference.locale ?? Locale.autoupdatingCurrent
    }

    private func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), locale: locale)
    }

    private func styleName(_ style: Style) -> String {
        switch style {
        case .exhibit:   return localized("Exhibit")
        case .tapestry:  return localized("Tapestry")
        case .editorial: return localized("Editorial")
        case .gallery:   return localized("Gallery")
        case .collage:   return localized("Collage")
        case .minimal:   return localized("Minimal")
        case .vintage:   return localized("Vintage")
        }
    }

    private func axisName(_ axis: ClusterAxis) -> String {
        switch axis {
        case .color:  return localized("Color")
        case .mood:   return localized("Mood")
        case .scene:  return localized("Scene")
        case .people: return localized("People")
        case .time:   return localized("Time")
        }
    }

    var body: some Commands {

        CommandGroup(replacing: .newItem) {
            Button(localized("Pick Library…")) {
                NotificationCenter.default.post(name: .loomPickLibrary, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)
        }

        CommandMenu(localized("Weave")) {
            Button(localized("Shuffle")) {
                NotificationCenter.default.post(name: .loomShuffle, object: nil)
            }
            .keyboardShortcut(.space, modifiers: [])

            Divider()

            ForEach(Style.allCases) { style in
                Button(styleName(style)) {
                    app.setStyle(style)
                    NotificationCenter.default.post(name: .loomShuffle, object: nil)
                }
                .keyboardShortcut(
                    KeyEquivalent(Character("\(style.shortcutDigit)")),
                    modifiers: .command
                )
            }

            Divider()

            Menu(localized("Cluster By")) {
                ForEach(ClusterAxis.allCases, id: \.self) { axis in
                    Button(axisName(axis)) {
                        app.setAxis(axis)
                        NotificationCenter.default.post(name: .loomShuffle, object: nil)
                    }
                }
            }

            Divider()

            Button(localized("Save Wall as Favorite")) {
                NotificationCenter.default.post(name: .loomFavoriteSave, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command])

            Button(localized("Clear Locks")) {
                app.clearLocks()
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .saveItem) {
            Button(localized("Export as PNG…")) {
                NotificationCenter.default.post(name: .loomExportPNG, object: nil)
            }
            .keyboardShortcut("e", modifiers: [.command])
            Button(localized("Export as PDF…")) {
                NotificationCenter.default.post(name: .loomExportPDF, object: nil)
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }

        CommandMenu(localized("Favorites")) {
            if favorites.favorites.isEmpty {
                Text(localized("No saved walls yet — ⌘S to save the current one."))
            } else {
                ForEach(favorites.favorites.prefix(12)) { fav in
                    Button(fav.name) {
                        NotificationCenter.default.post(
                            name: .loomFavoriteApply, object: fav
                        )
                    }
                }
            }
        }
    }
}

// Notification.Name constants now live in LoomCore/Events.swift so both
// the Loom executable target and LoomUI views can reference them without
// introducing a cross-target dependency.
