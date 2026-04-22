import SwiftUI
import LoomDesign

/// A minimal settings gear button in the wall's top-right corner —
/// mirrors ``LibraryChip`` on the opposite side so the three-point
/// composition (library · settings · shuffle chrome) reads as a balanced
/// triangle around the wall.
///
/// Uses the modern `@Environment(\.openSettings)` action (macOS 14+) to
/// open the native Settings window. Keeps keyboard parity: ⌘, works from
/// the standard menu regardless of this button.
public struct SettingsChip: View {

    @Environment(\.openSettings) private var openSettings
    @State private var hovered = false

    public init() {}

    public var body: some View {
        Button {
            openSettings()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.inkMuted)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(Palette.surface.opacity(0.88))
                        .background(.ultraThinMaterial, in: Circle())
                )
                .overlay(Circle().strokeBorder(Palette.hairline, lineWidth: 1))
                .offset(y: hovered ? -1 : 0)
        }
        .buttonStyle(.plain)
        .help(LocalizedStringKey("Settings"))
        .onHover { hovered = $0 }
        .animation(LoomMotion.hover, value: hovered)
    }
}
