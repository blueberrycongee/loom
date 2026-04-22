import SwiftUI
import LoomCore
import LoomDesign

/// The floating toolbar at the bottom of the wall.
///
/// **Auto-hide**: appears on launch, fades out after ~3s of idle, slides
/// back in when the cursor approaches the bottom edge. During hover the
/// chrome stays solid; on exit the idle timer restarts.
///
/// **Layout**: two groups separated by breathing room (no explicit divider).
/// Secondary controls (Axis / Style) sit left as quiet text chips;
/// the primary Shuffle button sits right in brass. Material-backed with
/// a warm canvas tint — frosted glass that belongs on the paper canvas
/// rather than fighting it.
public struct WallChrome: View {

    @Environment(AppModel.self) private var app
    public let shuffle: () -> Void
    public let isNarrow: Bool

    @State private var hoveredChip: Chip?

    private enum Chip: Hashable { case axis, style }

    public init(shuffle: @escaping () -> Void, isNarrow: Bool = false) {
        self.shuffle = shuffle
        self.isNarrow = isNarrow
    }

    public var body: some View {
        HStack(spacing: 0) {
            axisChip
            separator
            styleChip

            Spacer()
                .frame(width: LoomSpacing.lg)

            ShuffleButton(showShortcut: !isNarrow, action: shuffle)
        }
        .padding(.horizontal, LoomSpacing.md)
        .padding(.vertical, LoomSpacing.xs + 2)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .background(
            Capsule(style: .continuous)
                .fill(Palette.canvas.opacity(0.55))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(Palette.hairline.opacity(0.6), lineWidth: 0.5)
        )
        .shadow(
            color: LoomShadow.tone.opacity(0.10),
            radius: 20, x: 0, y: 8
        )
        .shadow(
            color: LoomShadow.tone.opacity(0.04),
            radius: 2, x: 0, y: 1
        )
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

    private func chipLabel(_ text: Text, kind: Chip) -> some View {
        HStack(spacing: LoomSpacing.xs) {
            text
                .font(LoomType.caption)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(Palette.ink)
            Image(systemName: "chevron.down")
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(Palette.inkFaint)
        }
        .padding(.horizontal, LoomSpacing.sm + 2)
        .padding(.vertical, LoomSpacing.xs + 2)
        .background(
            Capsule(style: .continuous)
                .fill(hoveredChip == kind
                      ? Palette.ink.opacity(0.06)
                      : Color.clear)
        )
        .onHover { entered in
            if entered { hoveredChip = kind }
            else if hoveredChip == kind { hoveredChip = nil }
        }
        .animation(LoomMotion.hover, value: hoveredChip)
    }

    // MARK: — Separator

    private var separator: some View {
        Text("·")
            .font(.system(size: 11, weight: .light))
            .foregroundStyle(Palette.inkFaint)
            .padding(.horizontal, LoomSpacing.xs)
    }

    private func isAvailable(_ axis: ClusterAxis) -> Bool {
        axis == .color || axis == .mood
    }
}
