import SwiftUI
import LoomCore
import LoomDesign

/// The floating toolbar at the bottom of the wall.
///
/// Redesigned: **secondary + primary**. Axis and Style live as plain
/// text chips with a chevron (no capsule-in-capsule clutter); Shuffle
/// keeps its brass hero styling and now sits alone on the right with a
/// thin paper-rule hairline separating it from the secondary controls.
/// Background is a solid warm surface — no ``.ultraThinMaterial`` blur,
/// which read as translucent glass and fought the paper-canvas metaphor.
///
/// One visual vocabulary across the three regions: matching horizontal
/// padding, matching chevron weight, matching hover lift. The chrome is
/// meant to disappear; the wall is the product.
public struct WallChrome: View {

    @Environment(AppModel.self) private var app
    public let shuffle: () -> Void

    @State private var hoveringBar = false
    @State private var hoveredChip: Chip?

    private enum Chip: Hashable { case axis, style }

    public init(shuffle: @escaping () -> Void) {
        self.shuffle = shuffle
    }

    public var body: some View {
        HStack(spacing: 0) {
            axisChip
            gap
            styleChip

            ruleDivider

            ShuffleButton(compact: true, action: shuffle)
                .padding(.leading, LoomSpacing.xs)
        }
        .padding(.horizontal, LoomSpacing.sm)
        .padding(.vertical, LoomSpacing.xs)
        .background(
            Capsule(style: .continuous)
                .fill(Palette.surface)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
        .surfaceShadow()
        .offset(y: hoveringBar ? -4 : 0)
        .onHover { hoveringBar = $0 }
        .animation(LoomMotion.hover, value: hoveringBar)
    }

    // MARK: — Chips

    private var axisChip: some View {
        Menu {
            ForEach(ClusterAxis.allCases, id: \.self) { axis in
                Button {
                    app.setAxis(axis)
                    shuffle()
                } label: {
                    HStack {
                        Text(axis.displayName)
                        Spacer()
                        if axis == app.axis {
                            Image(systemName: "checkmark")
                        } else if !isAvailable(axis) {
                            Text("soon")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(!isAvailable(axis))
            }
        } label: {
            chipLabel(Text(app.axis.displayName), kind: .axis)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var styleChip: some View {
        Menu {
            ForEach(Style.allCases) { style in
                Button {
                    app.setStyle(style)
                    shuffle()
                } label: {
                    HStack {
                        Text(style.displayName)
                        Spacer()
                        if style == app.style {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            chipLabel(Text(app.style.displayName), kind: .style)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    /// Single source of truth for chip appearance — any future chips
    /// (e.g. a palette-mode toggle) reuse this shape and spacing so the
    /// rhythm across the chrome stays consistent.
    private func chipLabel(_ text: Text, kind: Chip) -> some View {
        HStack(spacing: LoomSpacing.xs) {
            text
                .font(LoomType.caption)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(Palette.ink)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Palette.inkFaint)
        }
        .padding(.horizontal, LoomSpacing.md)
        .padding(.vertical, LoomSpacing.xs + 1)
        .background(
            Capsule(style: .continuous)
                .fill(hoveredChip == kind ? Palette.surfaceElevated : Color.clear)
        )
        .onHover { entered in
            if entered { hoveredChip = kind }
            else if hoveredChip == kind { hoveredChip = nil }
        }
        .animation(LoomMotion.hover, value: hoveredChip)
    }

    // MARK: — Rule / spacer

    private var gap: some View {
        Spacer().frame(width: LoomSpacing.xxs)
    }

    /// Paper-rule style divider — not a heavy pipe. Signals the
    /// secondary-vs-primary transition without visual noise.
    private var ruleDivider: some View {
        Rectangle()
            .fill(Palette.hairline)
            .frame(width: 1, height: 20)
            .padding(.horizontal, LoomSpacing.sm)
    }

    private func isAvailable(_ axis: ClusterAxis) -> Bool {
        axis == .color || axis == .mood
    }
}
