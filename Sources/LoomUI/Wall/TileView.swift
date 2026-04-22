import SwiftUI
import AppKit
import LoomCore
import LoomDesign
import LoomIndex

/// One photo on the wall.
///
/// Loads its thumbnail from `ThumbnailCache.Size.tile` — a 1024px JPEG,
/// baked on-demand because tile thumbnails are heavier than grid ones and
/// most wall photos never get shown before the next Shuffle.
///
/// The dominant-color swatch underneath the image gives the wall its
/// immediate palette even before any thumbnails paint, which matters because
/// a wall is about gestalt first, detail second.
struct TileView: View {

    let tile: Tile
    let photo: Photo?
    let style: Style

    private let thumbnails = ThumbnailCache()
    @State private var image: NSImage?
    @State private var hovered = false

    init(tile: Tile, photo: Photo?, style: Style = .tapestry) {
        self.tile = tile
        self.photo = photo
        self.style = style
    }

    var body: some View {
        Group {
            if style == .vintage {
                polaroid
            } else {
                plainTile
            }
        }
        .frame(width: tile.frame.width, height: tile.frame.height)
        .scaleEffect(hovered ? 1.015 : 1.0)
        .rotationEffect(.radians(tile.rotation))
        .onHover { hovered = $0 }
        .animation(LoomMotion.hover, value: hovered)
        .task(id: photo?.id) {
            await load()
        }
    }

    private var plainTile: some View {
        ZStack {
            if let photo {
                dominantSwatch(for: photo)
            }

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: LoomRadius.tile, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LoomRadius.tile, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
        .tileShadow()
    }

    /// Polaroid chrome: thick white border, extra-thick on the bottom for
    /// the signature space; paper-texture off-white rather than pure white.
    private var polaroid: some View {
        let paper = Color(red: 0.97, green: 0.95, blue: 0.90)
        let topMargin: CGFloat = 10
        let sideMargin: CGFloat = 10
        let bottomMargin: CGFloat = max(24, tile.frame.height * 0.18)
        return ZStack {
            paper
            VStack(spacing: 0) {
                ZStack {
                    if let photo {
                        dominantSwatch(for: photo)
                    }
                    if let image {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .transition(.opacity)
                    }
                }
                .clipped()
                .padding(.top, topMargin)
                .padding(.horizontal, sideMargin)

                Spacer(minLength: 0)
            }
            .padding(.bottom, bottomMargin)
        }
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
        )
        .tileShadow()
    }

    private func dominantSwatch(for photo: Photo) -> some View {
        let rgb = labToSRGB(photo.dominantColor)
        return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    private func load() async {
        guard let photo else { return }
        image = nil
        let loaded = await Task.detached(priority: .userInitiated) {
            let url = ThumbnailCache().ensure(
                for: photo.id, source: photo.url, size: .tile
            )
            return url.flatMap { NSImage(contentsOf: $0) }
        }.value
        await MainActor.run {
            withLoomAnimation(LoomMotion.ease) { self.image = loaded }
        }
    }
}
