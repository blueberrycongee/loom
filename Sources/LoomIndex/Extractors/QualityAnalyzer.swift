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

        // Extreme exposure (near-black or near-white) is a hard reject:
        // no amount of resolution or sharpness saves a completely
        // crushed or blown photo.
        guard exposure > 0.0 else { return 0.0 }

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

    /// Exposure analysis. Two checks:
    /// 1. Mean luminance — if the photo is overwhelmingly dark or bright
    ///    on average, it's a bad photo regardless of local contrast.
    /// 2. Histogram extremes — what fraction of pixels are crushed to
    ///    near-black or blown to near-white.
    private static func exposureScore(_ pixels: [UInt8]) -> Double {
        guard !pixels.isEmpty else { return 0.5 }
        var totalLum: UInt64 = 0
        var lowCount = 0
        var highCount = 0
        for p in pixels {
            totalLum += UInt64(p)
            if p < 26  { lowCount  += 1 }
            if p > 230 { highCount += 1 }
        }
        let n = Double(pixels.count)
        let meanLum = Double(totalLum) / n

        // Nearly black or nearly white overall → reject immediately.
        if meanLum < 30 || meanLum > 240 { return 0.0 }

        let extremeFrac = max(Double(lowCount), Double(highCount)) / n
        if extremeFrac > 0.70 { return 0.0 }
        if extremeFrac > 0.50 { return 0.3 }
        if extremeFrac > 0.35 { return 0.6 }
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
        // Primary path: 8-bit DeviceGray (fast, standard).
        var pixels = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        if let ctx = CGContext(
            data: &pixels,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) {
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            // If we got any non-zero data, trust the primary path.
            if pixels.contains(where: { $0 != 0 }) {
                return pixels
            }
        }

        // Fallback: 32-bit RGBX then luminance conversion.
        // Some macOS configurations silently fail with 8-bit grayscale
        // CGContext (same root cause as the BorderDetector 24-bit RGB bug).
        // 32-bit RGBX is guaranteed supported, so we draw there and convert.
        let bytesPerRow = width * 4
        var rgba = [UInt8](repeating: 0, count: bytesPerRow * height)
        let rgbSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &rgba,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: rgbSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return [] }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // ITU-R BT.601 luma coefficients.
        var gray = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let i = y * bytesPerRow + x * 4
                let r = Int(rgba[i])
                let g = Int(rgba[i + 1])
                let b = Int(rgba[i + 2])
                let lum = (76 * r + 150 * g + 29 * b) >> 8
                gray[y * width + x] = UInt8(max(0, min(255, lum)))
            }
        }
        return gray
    }
}
