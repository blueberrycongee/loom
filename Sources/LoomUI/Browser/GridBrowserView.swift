import SwiftUI
import LoomCore
import LoomDesign
import LoomIndex

/// A justified grid browser of the whole library. M1 surface.
///
/// The visual intent sits between Apple Photos' "All Photos" grid and
/// Tapestry's hero surface: tiles of equal row-height, gutters tight, no
/// chrome. Clicking a tile currently just focuses it; M5 adds detail.
///
/// Thumbnails come from ``ThumbnailCache`` — the grid never touches originals.
public struct GridBrowserView: View {

    @Environment(AppModel.self) private var app
    @State private var hovered: PhotoID?
    @State private var focused: PhotoID?

    private let thumbnails = ThumbnailCache()

    private let targetRowHeight: CGFloat = 200
    private let gutter: CGFloat = 6

    public init() {}

    public var body: some View {
        GeometryReader { geo in
            let rows = JustifiedRowPacker.pack(
                photos: app.photos,
                availableWidth: geo.size.width - LoomSpacing.lg * 2,
                targetRowHeight: targetRowHeight,
                gutter: gutter
            )

            ScrollView {
                VStack(alignment: .leading, spacing: gutter) {
                    ForEach(rows.indices, id: \.self) { idx in
                        HStack(spacing: gutter) {
                            ForEach(rows[idx]) { placement in
                                GridTileView(
                                    photo: placement.photo,
                                    frame: placement.frame,
                                    hovered: hovered == placement.photo.id,
                                    focused: focused == placement.photo.id,
                                    thumbnails: thumbnails
                                )
                                .onHover { hovered = $0 ? placement.photo.id : (hovered == placement.photo.id ? nil : hovered) }
                                .onTapGesture {
                                    withLoomAnimation(LoomMotion.snap) {
                                        focused = (focused == placement.photo.id) ? nil : placement.photo.id
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, LoomSpacing.lg)
                .padding(.vertical, LoomSpacing.lg)
            }
            .scrollContentBackground(.hidden)
        }
        .animation(LoomMotion.breathe, value: app.photos.count)
        .overlay(alignment: .topTrailing) {
            IndexStat(count: app.photos.count)
                .padding(LoomSpacing.md)
        }
    }
}

private struct IndexStat: View {
    let count: Int
    var body: some View {
        HStack(spacing: LoomSpacing.xs) {
            Circle().fill(Palette.brass).frame(width: 6, height: 6)
            Text("\(count) photos")
                .font(LoomType.monoSm)
                .foregroundStyle(Palette.inkMuted)
        }
        .padding(.horizontal, LoomSpacing.sm)
        .padding(.vertical, LoomSpacing.xs)
        .background(Capsule().fill(Palette.surface.opacity(0.6)))
        .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
    }
}
