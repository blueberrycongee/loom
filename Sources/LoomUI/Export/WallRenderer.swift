import SwiftUI
import AppKit
import LoomCore
import LoomDesign
import LoomIndex

/// Offscreen rendering of a ``Wall`` for export.
///
/// We can't simply snapshot the live SwiftUI view — it's embedded in the
/// app's scene and the renderer needs to work even if the window isn't
/// visible. Instead, we build a parallel SwiftUI view tree at the wall's
/// full canvas resolution and hand it to ``ImageRenderer``.
///
/// The render path uses the same `TileView` and `WallCanvas` layouts the
/// live app shows, so the export is pixel-identical up to the render
/// resolution.
@MainActor
public enum WallRenderer {

    /// Render to an NSImage at 2× the wall's canvas size — suitable for
    /// Retina display preview. Higher resolutions go through ``renderToPNG``.
    public static func renderToImage(
        wall: Wall,
        photos: [Photo],
        scale: CGFloat = 2.0,
        applyCropInsets: Bool = true
    ) -> NSImage? {
        let images = preloadImages(for: wall, from: photos, scale: scale)
        let view = ExportWallView(wall: wall, photos: photos, images: images, applyCropInsets: applyCropInsets)
            .frame(width: wall.canvasSize.width, height: wall.canvasSize.height)
            .background(Palette.canvas)

        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.nsImage
    }

    /// Eagerly generate and load every thumbnail the wall needs so the
    /// off-screen renderer sees actual photos, not dominant-colour swatches.
    private static func preloadImages(
        for wall: Wall,
        from photos: [Photo],
        scale: CGFloat? = nil
    ) -> [PhotoID: NSImage] {
        let cache = ThumbnailCache()
        let photoByID = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })
        var images: [PhotoID: NSImage] = [:]
        for tile in wall.tiles {
            guard let photo = photoByID[tile.photoID] else { continue }
            guard let thumbURL = cache.ensure(for: photo.id, source: photo.url, size: .tile),
                  let nsImage = loadThumbnail(from: thumbURL, scale: scale)
            else { continue }
            images[tile.photoID] = nsImage
        }
        return images
    }

    /// Export to a PNG file at the given URL. Returns true on success.
    @discardableResult
    public static func renderToPNG(
        wall: Wall,
        photos: [Photo],
        scale: CGFloat = 3.0,
        applyCropInsets: Bool = true,
        to url: URL
    ) -> Bool {
        guard let image = renderToImage(wall: wall, photos: photos, scale: scale, applyCropInsets: applyCropInsets),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return false }
        return (try? png.write(to: url)) != nil
    }

    /// Export to a PDF at the given URL.
    @discardableResult
    public static func renderToPDF(
        wall: Wall,
        photos: [Photo],
        applyCropInsets: Bool = true,
        to url: URL
    ) -> Bool {
        let images = preloadImages(for: wall, from: photos)
        let view = ExportWallView(wall: wall, photos: photos, images: images, applyCropInsets: applyCropInsets)
            .frame(width: wall.canvasSize.width, height: wall.canvasSize.height)
            .background(Palette.canvas)

        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(wall.canvasSize)

        var ok = false
        renderer.render { size, context in
            let pageRect = CGRect(origin: .zero, size: size)
            var mediaBox = pageRect
            guard let pdf = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else { return }
            pdf.beginPDFPage(nil)
            context(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
            ok = true
        }
        return ok
    }
}

/// A stripped-down wall rendering used only for exports: same visual, no
/// environment(AppModel) dependency (the renderer runs outside the app's
/// scene), no hover / lock affordances.
private struct ExportWallView: View {
    let wall: Wall
    let photos: [Photo]
    let images: [PhotoID: NSImage]
    let applyCropInsets: Bool

    private var photoByID: [PhotoID: Photo] {
        Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            ForEach(wall.tiles, id: \.photoID) { tile in
                ExportTileView(
                    tile: tile,
                    photo: photoByID[tile.photoID],
                    image: images[tile.photoID],
                    style: wall.style,
                    applyCropInsets: applyCropInsets
                )
                .position(x: tile.frame.midX, y: tile.frame.midY)
                .frame(width: tile.frame.width, height: tile.frame.height)
            }
        }
        .frame(width: wall.canvasSize.width, height: wall.canvasSize.height)
    }
}

/// A non-interactive tile view that receives its image eagerly — no `.task`
/// async load.  Used by ``ExportWallView`` so ``ImageRenderer`` captures
/// actual photos rather than dominant-colour swatches.
private struct ExportTileView: View {
    let tile: Tile
    let photo: Photo?
    let image: NSImage?
    let style: Style
    let applyCropInsets: Bool

    var body: some View {
        Group {
            if style == .vintage {
                polaroid
            } else {
                plainTile
            }
        }
        .frame(width: tile.frame.width, height: tile.frame.height)
        .rotationEffect(.radians(tile.rotation))
        .shadow(color: LoomShadow.tone.opacity(0.15), radius: 8, x: 0, y: 4)
    }

    private var plainTile: some View {
        ZStack {
            if let photo {
                dominantSwatch(for: photo)
            }
            if let image {
                croppedImage(Image(nsImage: image))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: LoomRadius.tile, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LoomRadius.tile, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
    }

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
                        croppedImage(Image(nsImage: image))
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
    }

    @ViewBuilder
    private func croppedImage(_ img: Image) -> some View {
        let insets = applyCropInsets ? (photo?.cropInsets ?? .zero) : .zero
        if insets.isZero {
            img.resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            let scaleX = 1.0 / max(0.5, 1.0 - insets.left - insets.right)
            let scaleY = 1.0 / max(0.5, 1.0 - insets.top - insets.bottom)
            let scale = max(scaleX, scaleY)
            let dx = (insets.left - insets.right) * 0.5
            let dy = (insets.top - insets.bottom) * 0.5
            img.resizable()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(scale)
                .offset(
                    x: -dx * tile.frame.width,
                    y: -dy * tile.frame.height
                )
        }
    }

    private func dominantSwatch(for photo: Photo) -> some View {
        let rgb = labToSRGB(photo.dominantColor)
        return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}
