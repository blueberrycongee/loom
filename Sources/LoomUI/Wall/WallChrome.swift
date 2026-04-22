import SwiftUI
import LoomCore
import LoomDesign

/// The floating toolbar at the bottom of the wall.
///
/// Three groups, centered: axis toggle · style picker · Shuffle hero. A
/// single soft-edged capsule background ties them together; individual
/// controls have their own hover states. The whole bar rises 4pt on hover
/// to hint it's interactive.
public struct WallChrome: View {

    @Environment(AppModel.self) private var app
    public let shuffle: () -> Void

    @State private var hoveringBar = false

    public init(shuffle: @escaping () -> Void) {
        self.shuffle = shuffle
    }

    public var body: some View {
        @Bindable var bindableApp = app

        HStack(spacing: LoomSpacing.md) {
            AxisToggle(
                selected: $bindableApp.axis,
                onChange: { _ in shuffle() }
            )

            StylePicker(
                selected: $bindableApp.style,
                onChange: { _ in shuffle() }
            )

            ShuffleButton(action: shuffle)
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
}
