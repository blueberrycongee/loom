import SwiftUI
import AppKit
import LoomCore
import LoomDesign
import LoomIndex

/// A single tile in the grid browser.
///
/// The thumbnail is loaded lazily from `ThumbnailCache`. Load is async but
/// the file is already on disk (baked during indexing) so it's essentially
/// instant — we still go through a `Task` so a very cold disk can't stutter
/// scroll.
struct GridTileView: View {

    let photo: Photo
    let frame: CGRect          // size only; origin ignored
    let hovered: Bool
    let focused: Bool
    let thumbnails: ThumbnailCache

    @State private var image: NSImage?

    var body: some View {
        ZStack {
            // Background = the dominant color. Showing the Lab→sRGB-ish proxy
            // here avoids a jarring black flash before the thumbnail loads.
            dominantSwatch

            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            }
        }
        .frame(width: frame.width, height: frame.height)
        .clipShape(RoundedRectangle(cornerRadius: LoomRadius.tile, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LoomRadius.tile, style: .continuous)
                .strokeBorder(
                    focused ? Palette.brass : Palette.hairline,
                    lineWidth: focused ? 2 : 1
                )
        )
        .scaleEffect(hovered || focused ? 1.02 : 1.0)
        .shadow(color: .black.opacity(hovered ? 0.45 : 0.25),
                radius: hovered ? 22 : 14,
                x: 0, y: hovered ? 10 : 6)
        .animation(LoomMotion.hover, value: hovered)
        .animation(LoomMotion.snap,  value: focused)
        .task(id: photo.id) {
            await loadImage()
        }
    }

    private var dominantSwatch: some View {
        // The L*a*b* dominant color, converted to sRGB for screen. This is a
        // display-only approximation; the clusterer operates on Lab directly.
        let rgb = labToSRGB(photo.dominantColor)
        return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    private func loadImage() async {
        if let cached = image { _ = cached; return }
        let url = thumbnails.url(for: photo.id, size: .grid)
        let img: NSImage? = await Task.detached(priority: .userInitiated) {
            guard FileManager.default.fileExists(atPath: url.path) else {
                // Cache miss — try to bake it on demand.
                let cache = ThumbnailCache()
                if let baked = cache.ensure(for: photo.id, source: photo.url, size: .grid) {
                    return NSImage(contentsOf: baked)
                }
                return nil
            }
            return NSImage(contentsOf: url)
        }.value

        await MainActor.run {
            withLoomAnimation(LoomMotion.ease) { self.image = img }
        }
    }
}

// MARK: — Lab → sRGB helper (display-only)

/// Convert a CIE L*a*b* color (D65) to an sRGB triple clamped to [0, 1].
/// Good enough to render a swatch; not colorimetric-grade.
func labToSRGB(_ lab: LabColor) -> (r: Double, g: Double, b: Double) {
    let L = lab.l, a = lab.a, bb = lab.b
    var fy = (L + 16) / 116
    var fx = a / 500 + fy
    var fz = fy - bb / 200

    func finv(_ t: Double) -> Double {
        let t3 = t * t * t
        return t3 > 0.008856 ? t3 : (t - 16.0 / 116.0) / 7.787
    }

    fy = finv(fy); fx = finv(fx); fz = finv(fz)
    let X = fx * 0.95047
    let Y = fy * 1.00000
    let Z = fz * 1.08883

    // XYZ → linear sRGB
    let rLin =  3.2404542 * X - 1.5371385 * Y - 0.4985314 * Z
    let gLin = -0.9692660 * X + 1.8760108 * Y + 0.0415560 * Z
    let bLin =  0.0556434 * X - 0.2040259 * Y + 1.0572252 * Z

    func gamma(_ u: Double) -> Double {
        let v = max(0, min(1, u))
        return v <= 0.0031308 ? 12.92 * v : 1.055 * Foundation.pow(v, 1 / 2.4) - 0.055
    }

    return (gamma(rLin), gamma(gLin), gamma(bLin))
}
