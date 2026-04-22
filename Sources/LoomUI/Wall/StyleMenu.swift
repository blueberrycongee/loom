import SwiftUI
import LoomCore
import LoomDesign

/// A compact Menu-backed style picker. Shows the current style as a pill
/// with a chevron; the full list of styles appears in the dropdown.
///
/// Visually matches ``AxisToggle`` so the narrow-layout chrome reads as
/// three equally-weighted pill-shaped controls. Used by ``WallChrome``'s
/// narrow branch (below ~980pt window width) when ``StylePicker``'s seven
/// segmented cells no longer fit on one row.
public struct StyleMenu: View {

    @Binding public var selected: Style
    public let onChange: (Style) -> Void

    public init(
        selected: Binding<Style>,
        onChange: @escaping (Style) -> Void
    ) {
        self._selected = selected
        self.onChange = onChange
    }

    public var body: some View {
        Menu {
            ForEach(Style.allCases) { style in
                Button {
                    selected = style
                    onChange(style)
                } label: {
                    HStack {
                        Text(style.displayName)
                        if style == selected {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: LoomSpacing.xs) {
                Image(systemName: "square.on.square")
                    .font(.system(size: 11, weight: .semibold))
                Text(selected.displayName)
                    .font(LoomType.caption)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Palette.inkFaint)
            }
            .foregroundStyle(Palette.inkMuted)
            .padding(.horizontal, LoomSpacing.md)
            .padding(.vertical, LoomSpacing.xs + 2)
            .background(Capsule().fill(Palette.surface.opacity(0.7)))
            .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
