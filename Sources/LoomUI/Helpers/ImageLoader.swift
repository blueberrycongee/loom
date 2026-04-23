import AppKit

/// Load a thumbnail JPEG into an `NSImage` with the correct pixel-density
/// declaration so SwiftUI renders it at full resolution on Retina displays.
///
/// `NSImage(contentsOf:)` sets the image `size` in points based on the JPEG's
/// DPI metadata. Most camera JPEGs lack meaningful DPI, so the size defaults
/// to the pixel dimensions — e.g. a 2048px image gets `size = 2048pt`. SwiftUI
/// treats this as a 1× image. On a 2× Retina screen a 1024pt tile then only
/// receives 1024 rendered pixels instead of the 2048 available, producing blur.
///
/// This helper divides the actual pixel count by the display (or render) scale
/// so that `pixels / size == scale`. SwiftUI then maps every pixel 1:1 to the
/// screen at the declared scale, and any further downsampling to fit a smaller
/// tile is handled by the `.resizable()` pipeline with plenty of headroom.
func loadThumbnail(from url: URL, scale: CGFloat? = nil) -> NSImage? {
    guard let image = NSImage(contentsOf: url) else { return nil }
    guard let rep = image.representations.first as? NSBitmapImageRep else {
        return image
    }
    let targetScale = scale ?? NSScreen.main?.backingScaleFactor ?? 2.0
    image.size = NSSize(
        width: CGFloat(rep.pixelsWide) / targetScale,
        height: CGFloat(rep.pixelsHigh) / targetScale
    )
    return image
}
