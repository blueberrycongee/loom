import SwiftUI
import LoomCore
import LoomDesign

/// Menu-bar commands and keyboard shortcuts.
///
/// Loom leans on the keyboard: Space is Shuffle, ⌘1–6 pick a style, ⌘K opens
/// the style palette. We declare them here instead of peppering views with
/// `.keyboardShortcut` so the menu bar mirrors reality.
struct AppCommands: Commands {

    let app: AppModel
    let favorites: FavoritesCoordinator

    var body: some Commands {

        CommandGroup(replacing: .newItem) {
            Button("Pick Library…") {
                NotificationCenter.default.post(name: .loomPickLibrary, object: nil)
            }
            .keyboardShortcut("o", modifiers: .command)
        }

        CommandMenu("Weave") {
            Button("Shuffle") {
                NotificationCenter.default.post(name: .loomShuffle, object: nil)
            }
            .keyboardShortcut(.space, modifiers: [])

            Divider()

            ForEach(Style.allCases) { style in
                Button(style.displayName) {
                    app.setStyle(style)
                    NotificationCenter.default.post(name: .loomShuffle, object: nil)
                }
                .keyboardShortcut(
                    KeyEquivalent(Character("\(style.shortcutDigit)")),
                    modifiers: .command
                )
            }

            Divider()

            Menu("Cluster By") {
                ForEach(ClusterAxis.allCases, id: \.self) { axis in
                    Button(axis.displayName) {
                        app.setAxis(axis)
                        NotificationCenter.default.post(name: .loomShuffle, object: nil)
                    }
                }
            }

            Divider()

            Button("Save Wall as Favorite") {
                NotificationCenter.default.post(name: .loomFavoriteSave, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command])

            Button("Clear Locks") {
                app.clearLocks()
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .saveItem) {
            Button("Export as PNG…") {
                NotificationCenter.default.post(name: .loomExportPNG, object: nil)
            }
            .keyboardShortcut("e", modifiers: [.command])
            Button("Export as PDF…") {
                NotificationCenter.default.post(name: .loomExportPDF, object: nil)
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }

        CommandMenu("Favorites") {
            if favorites.favorites.isEmpty {
                Text("No saved walls yet — ⌘S to save the current one.")
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
