import SwiftUI
import LoomCore
import LoomDesign

/// A compact menu that lets the user flip the clustering axis.
///
/// Sits as a small pill inside the wall chrome. Click opens a Menu listing
/// the axes; each shows whether it's available yet (color is v1; mood/scene/
/// people/time come later). Unavailable axes render disabled with a
/// "coming soon" note so users see the roadmap without friction.
public struct AxisToggle: View {

    @Binding public var selected: ClusterAxis
    public let onChange: (ClusterAxis) -> Void

    public init(
        selected: Binding<ClusterAxis>,
        onChange: @escaping (ClusterAxis) -> Void
    ) {
        self._selected = selected
        self.onChange = onChange
    }

    public var body: some View {
        Menu {
            ForEach(ClusterAxis.allCases, id: \.self) { axis in
                Button {
                    selected = axis
                    onChange(axis)
                } label: {
                    HStack {
                        Text(axis.displayName)
                        Spacer()
                        if !isAvailable(axis) {
                            Text("soon")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(!isAvailable(axis))
            }
        } label: {
            HStack(spacing: LoomSpacing.xs) {
                Image(systemName: "circle.grid.cross")
                    .font(.system(size: 11, weight: .semibold))
                Text(selected.displayName)
                    .font(LoomType.caption)
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

    private func isAvailable(_ axis: ClusterAxis) -> Bool {
        axis == .color
    }
}
