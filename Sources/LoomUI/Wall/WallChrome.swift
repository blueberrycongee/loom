import SwiftUI
import LoomCore
import LoomDesign

/// The floating toolbar at the bottom of the wall.
///
/// Three controls — axis toggle · style picker · Shuffle hero — inside a
/// single ultra-thin-material capsule. At normal window widths (≥ ~980pt)
/// the style picker is a full seven-cell segmented pill; narrower than
/// that, ``ViewThatFits`` auto-swaps in a compact ``StyleMenu`` + shrunken
/// Shuffle button so the chrome always occupies one row, never wraps to
/// two, and never clips. Line-clamping on every Text is a belt-and-braces
/// safety net in case a future localization has unusually long labels.
public struct WallChrome: View {

    @Environment(AppModel.self) private var app
    public let shuffle: () -> Void

    @State private var hoveringBar = false

    public init(shuffle: @escaping () -> Void) {
        self.shuffle = shuffle
    }

    public var body: some View {
        @Bindable var bindableApp = app

        ViewThatFits(in: .horizontal) {
            wideRow(bindableApp: bindableApp)
            compactRow(bindableApp: bindableApp)
        }
        .padding(.horizontal, LoomSpacing.md)
        .padding(.vertical, LoomSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: LoomRadius.pill, style: .continuous)
                .fill(Palette.surface.opacity(0.85))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: LoomRadius.pill, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LoomRadius.pill, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
        .surfaceShadow()
        .offset(y: hoveringBar ? -4 : 0)
        .onHover { hoveringBar = $0 }
        .animation(LoomMotion.hover, value: hoveringBar)
    }

    /// Wide layout: full segmented ``StylePicker`` + chunky 220pt Shuffle.
    private func wideRow(bindableApp: AppModel) -> some View {
        HStack(spacing: LoomSpacing.md) {
            AxisToggle(
                selected: Binding(get: { bindableApp.axis }, set: { bindableApp.axis = $0 }),
                onChange: { _ in shuffle() }
            )

            StylePicker(
                selected: Binding(get: { bindableApp.style }, set: { bindableApp.style = $0 }),
                onChange: { _ in shuffle() }
            )

            ShuffleButton(compact: false, action: shuffle)
        }
    }

    /// Compact layout: Menu-backed ``StyleMenu`` + natural-size Shuffle.
    /// ViewThatFits picks this when the wide row's ideal width exceeds
    /// the available horizontal space — typically at window widths below
    /// ~980pt, or when the user picks particularly verbose localized
    /// style labels.
    private func compactRow(bindableApp: AppModel) -> some View {
        HStack(spacing: LoomSpacing.sm) {
            AxisToggle(
                selected: Binding(get: { bindableApp.axis }, set: { bindableApp.axis = $0 }),
                onChange: { _ in shuffle() }
            )

            StyleMenu(
                selected: Binding(get: { bindableApp.style }, set: { bindableApp.style = $0 }),
                onChange: { _ in shuffle() }
            )

            ShuffleButton(compact: true, action: shuffle)
        }
    }
}
