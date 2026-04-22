import SwiftUI
import LoomCore
import LoomDesign

/// A segmented style picker sitting next to the Shuffle CTA.
///
/// It's not a popup menu: the styles are first-class, their taglines live in
/// the design, and showing the set invites experimentation. Hover shows the
/// tagline; click selects + triggers a shuffle.
public struct StylePicker: View {

    @Binding public var selected: Style
    public let onChange: (Style) -> Void

    @State private var hovered: Style?

    public init(
        selected: Binding<Style>,
        onChange: @escaping (Style) -> Void
    ) {
        self._selected = selected
        self.onChange = onChange
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(Style.allCases) { style in
                cell(for: style)
            }
        }
        .padding(3)
        .background(
            Capsule().fill(Palette.surface.opacity(0.7))
        )
        .overlay(
            Capsule().strokeBorder(Palette.hairline, lineWidth: 1)
        )
        .help(hovered.map(\.tagline) ?? "")
    }

    private func cell(for style: Style) -> some View {
        let isSelected = selected == style
        return Button {
            selected = style
            onChange(style)
        } label: {
            Text(style.displayName)
                .font(LoomType.caption)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(isSelected ? Palette.canvas : Palette.inkMuted)
                .padding(.horizontal, LoomSpacing.md)
                .padding(.vertical, LoomSpacing.xs + 2)
                .background(
                    Capsule()
                        .fill(isSelected ? AnyShapeStyle(Palette.brassFill) : AnyShapeStyle(Color.clear))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? style : (hovered == style ? nil : hovered) }
        .animation(LoomMotion.snap, value: selected)
    }
}
