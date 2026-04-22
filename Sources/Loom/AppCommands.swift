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
        }
    }
}

/// App-wide event bus. NotificationCenter stays the simplest dependency-free
/// option for global commands; when the app grows we'll swap in a dedicated
/// router.
public extension Notification.Name {
    static let loomShuffle     = Notification.Name("loom.shuffle")
    static let loomPickLibrary = Notification.Name("loom.pickLibrary")
}
