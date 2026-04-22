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
        let view = ExportWallView(wall: wall, photos: photos, applyCropInsets: applyCropInsets)
            .frame(width: wall.canvasSize.width, height: wall.canvasSize.height)
            .background(Palette.canvas)

        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        return renderer.nsImage
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
        let view = ExportWallView(wall: wall, photos: photos, applyCropInsets: applyCropInsets)
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
    let applyCropInsets: Bool

    private var photoByID: [PhotoID: Photo] {
        Dictionary(uniqueKeysWithValues: photos.map { ($0.id, $0) })
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            ForEach(wall.tiles, id: \.photoID) { tile in
                TileView(
                    tile: tile,
                    photo: photoByID[tile.photoID],
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
