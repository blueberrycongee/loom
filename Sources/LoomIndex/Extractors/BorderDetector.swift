import CoreGraphics
import Foundation
import ImageIO
import LoomCore

/// Detects solid-color borders (letterbox, scanner margins) by scanning
/// inward from each edge of a 256px thumbnail. Each edge strip that has
/// near-zero color variance is flagged as a border; the returned
/// ``CropInsets`` express how much of each dimension to crop as a
/// fraction [0, 1).
///
/// Thresholds are intentionally conservative: a strip must be at least
/// 3% of the dimension to count, and its per-channel variance must be
/// extremely low (< 80 on 0–255 scale). This avoids false positives on
/// dark-sky landscapes or white-wall studio shots.
enum BorderDetector {

    /// Returns `.zero` if no borders were detected.
    static func detect(_ url: URL) -> CropInsets {
        guard let thumb = thumbnail(url) else { return .zero }
        let w = thumb.width
        let h = thumb.height
        guard w > 16, h > 16 else { return .zero }

        let pixels = rgbaPixels(thumb, width: w, height: h)
        guard pixels.count == w * h * 4 else { return .zero }

        let maxFraction = 0.25  // never crop more than 25% per edge
        let minStrip = 0.03     // border must be ≥3% of dimension

        let topRows    = scanRows(pixels, width: w, height: h,
                                  fromTop: true, maxFrac: maxFraction)
        let bottomRows = scanRows(pixels, width: w, height: h,
                                  fromTop: false, maxFrac: maxFraction)
        let leftCols   = scanCols(pixels, width: w, height: h,
                                  fromLeft: true, maxFrac: maxFraction)
        let rightCols  = scanCols(pixels, width: w, height: h,
                                  fromLeft: false, maxFrac: maxFraction)

        let top    = Double(topRows)    / Double(h)
        let bottom = Double(bottomRows) / Double(h)
        let left   = Double(leftCols)   / Double(w)
        let right  = Double(rightCols)  / Double(w)

        return CropInsets(
            top:    top    >= minStrip ? top    : 0,
            bottom: bottom >= minStrip ? bottom : 0,
            left:   left   >= minStrip ? left   : 0,
            right:  right  >= minStrip ? right  : 0
        )
    }

    // MARK: — Edge scanning

    /// Variance threshold per channel. A pure-color strip (e.g.
    /// black letterbox) has variance ≈ 0; a noisy one from JPEG
    /// compression might reach 20–40. 80 leaves headroom for
    /// compression artifacts while rejecting actual image content.
    private static let varianceThreshold: Double = 80

    /// Scan rows from one edge inward. Returns how many rows are
    /// considered a uniform-color border strip.
    private static func scanRows(
        _ pixels: [UInt8], width w: Int, height h: Int,
        fromTop: Bool, maxFrac: Double
    ) -> Int {
        let maxRows = Int(Double(h) * maxFrac)
        var borderRows = 0
        for step in 0..<maxRows {
            let row = fromTop ? step : (h - 1 - step)
            if rowVariance(pixels, row: row, width: w) < varianceThreshold {
                borderRows += 1
            } else {
                break
            }
        }
        return borderRows
    }

    /// Scan columns from one edge inward.
    private static func scanCols(
        _ pixels: [UInt8], width w: Int, height h: Int,
        fromLeft: Bool, maxFrac: Double
    ) -> Int {
        let maxCols = Int(Double(w) * maxFrac)
        var borderCols = 0
        for step in 0..<maxCols {
            let col = fromLeft ? step : (w - 1 - step)
            if colVariance(pixels, col: col, width: w, height: h) < varianceThreshold {
                borderCols += 1
            } else {
                break
            }
        }
        return borderCols
    }

    /// Max per-channel variance across R, G, B for one row.
    private static func rowVariance(
        _ pixels: [UInt8], row: Int, width: Int
    ) -> Double {
        var sumR = 0.0, sumG = 0.0, sumB = 0.0
        var sqR  = 0.0, sqG  = 0.0, sqB  = 0.0
        let base = row * width * 4
        for x in 0..<width {
            let i = base + x * 4
            let r = Double(pixels[i]),
                g = Double(pixels[i + 1]),
                b = Double(pixels[i + 2])
            sumR += r; sumG += g; sumB += b
            sqR += r * r; sqG += g * g; sqB += b * b
        }
        let n = Double(width)
        func v(_ s: Double, _ sq: Double) -> Double {
            sq / n - (s / n) * (s / n)
        }
        return max(v(sumR, sqR), max(v(sumG, sqG), v(sumB, sqB)))
    }

    /// Max per-channel variance across R, G, B for one column.
    private static func colVariance(
        _ pixels: [UInt8], col: Int, width: Int, height: Int
    ) -> Double {
        var sumR = 0.0, sumG = 0.0, sumB = 0.0
        var sqR  = 0.0, sqG  = 0.0, sqB  = 0.0
        for y in 0..<height {
            let i = (y * width + col) * 4
            let r = Double(pixels[i]),
                g = Double(pixels[i + 1]),
                b = Double(pixels[i + 2])
            sumR += r; sumG += g; sumB += b
            sqR += r * r; sqG += g * g; sqB += b * b
        }
        let n = Double(height)
        func v(_ s: Double, _ sq: Double) -> Double {
            sq / n - (s / n) * (s / n)
        }
        return max(v(sumR, sqR), max(v(sumG, sqG), v(sumB, sqB)))
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

    /// 32-bit RGBX pixel buffer. CGContext requires 4 bytes per pixel
    /// for RGB color spaces — 24-bit (3 bytes) is not a supported
    /// configuration and silently fails.
    private static func rgbaPixels(
        _ image: CGImage, width: Int, height: Int
    ) -> [UInt8] {
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixels,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return [] }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }
}
