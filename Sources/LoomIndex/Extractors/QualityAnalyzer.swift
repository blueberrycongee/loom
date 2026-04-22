import CoreGraphics
import Foundation
import ImageIO
import LoomCore

/// Computes a composite quality score for a photo: blur, exposure, and
/// resolution combined into a single 0–1 value. The Composer uses this
/// to skip low-quality photos when the filter is enabled (default on).
///
/// All analysis runs on a 256px thumbnail — cheap enough to process
/// thousands of photos during an index scan without a perceptible stall.
public enum QualityAnalyzer {

    public static let qualityThreshold: Double = 0.35

    /// Returns a score in [0, 1]. Higher = better.
    static func analyze(_ url: URL, pixelSize: PixelSize) -> Double {
        let resScore = resolutionScore(pixelSize)
        guard let thumb = thumbnail(url) else { return resScore }

        let width = thumb.width
        let height = thumb.height
        guard width > 4, height > 4 else { return resScore }

        let pixels = grayscalePixels(thumb, width: width, height: height)
        guard pixels.count == width * height else { return resScore }

        let blur = blurScore(pixels, width: width, height: height)
        let exposure = exposureScore(pixels)

        return resScore * 0.2 + blur * 0.5 + exposure * 0.3
    }

    // MARK: — Sub-scores

    private static func resolutionScore(_ size: PixelSize) -> Double {
        let minDim = Double(min(size.width, size.height))
        if minDim < 100 { return 0.0 }
        if minDim < 200 { return 0.3 }
        if minDim < 400 { return 0.7 }
        return 1.0
    }

    /// Laplacian variance — low variance means blurry. Computed on
    /// grayscale so color edges don't inflate the count.
    private static func blurScore(
        _ pixels: [UInt8], width: Int, height: Int
    ) -> Double {
        var sum: Double = 0
        var sumSq: Double = 0
        var count = 0
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let idx = y * width + x
                let lap = -4 * Int(pixels[idx])
                    + Int(pixels[idx - 1])
                    + Int(pixels[idx + 1])
                    + Int(pixels[idx - width])
                    + Int(pixels[idx + width])
                let v = Double(lap)
                sum += v
                sumSq += v * v
                count += 1
            }
        }
        guard count > 0 else { return 0.5 }
        let mean = sum / Double(count)
        let variance = sumSq / Double(count) - mean * mean
        return min(1.0, max(0.0, (variance - 30) / 300))
    }

    /// Histogram analysis — photos where >70% of pixels are in the
    /// bottom or top 10% of luminance are heavily under/over-exposed.
    private static func exposureScore(_ pixels: [UInt8]) -> Double {
        guard !pixels.isEmpty else { return 0.5 }
        var lowCount = 0
        var highCount = 0
        for p in pixels {
            if p < 26  { lowCount  += 1 }  // bottom 10%
            if p > 230 { highCount += 1 }  // top 10%
        }
        let n = Double(pixels.count)
        let lowFrac  = Double(lowCount)  / n
        let highFrac = Double(highCount) / n
        let extremeFrac = max(lowFrac, highFrac)
        if extremeFrac > 0.85 { return 0.0 }
        if extremeFrac > 0.70 { return 0.3 }
        if extremeFrac > 0.50 { return 0.6 }
        return 1.0
    }

    // MARK: — Helpers

    private static func thumbnail(_ url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 256,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
    }

    private static func grayscalePixels(
        _ image: CGImage, width: Int, height: Int
    ) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: &pixels,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return [] }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }
}
