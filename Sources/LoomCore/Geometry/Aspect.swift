import CoreGraphics
import Foundation

/// Geometry helpers — mostly for the layout engines.
public enum Aspect {
    /// Canonical "aspect buckets" used by scoring and variety constraints.
    public enum Bucket: String, Sendable {
        case tallPortrait   // ≤ 0.66
        case portrait       // 0.66 – 0.90
        case square         // 0.90 – 1.12
        case landscape      // 1.12 – 1.50
        case wide           // 1.50 – 2.30
        case ultraWide      // > 2.30
    }

    public static func bucket(of aspect: Double) -> Bucket {
        switch aspect {
        case ..<0.66:   return .tallPortrait
        case ..<0.90:   return .portrait
        case ..<1.12:   return .square
        case ..<1.50:   return .landscape
        case ..<2.30:   return .wide
        default:        return .ultraWide
        }
    }

    /// Fit a source aspect into a target rect, centered. Used by tile drawing.
    public static func fit(aspect: Double, into rect: CGRect) -> CGRect {
        let target = Double(rect.width / rect.height)
        if aspect >= target {
            // source is wider than target → constrain by width
            let w = rect.width
            let h = CGFloat(Double(w) / aspect)
            let y = rect.minY + (rect.height - h) / 2
            return CGRect(x: rect.minX, y: y, width: w, height: h)
        } else {
            let h = rect.height
            let w = CGFloat(Double(h) * aspect)
            let x = rect.minX + (rect.width - w) / 2
            return CGRect(x: x, y: rect.minY, width: w, height: h)
        }
    }

    /// Fill a target rect with the source aspect, cropping overflow. Used for
    /// thumbnails and square-cropped tile previews.
    public static func fill(aspect: Double, into rect: CGRect) -> CGRect {
        let target = Double(rect.width / rect.height)
        if aspect >= target {
            let h = rect.height
            let w = CGFloat(Double(h) * aspect)
            let x = rect.minX - (w - rect.width) / 2
            return CGRect(x: x, y: rect.minY, width: w, height: h)
        } else {
            let w = rect.width
            let h = CGFloat(Double(w) / aspect)
            let y = rect.minY - (h - rect.height) / 2
            return CGRect(x: rect.minX, y: y, width: w, height: h)
        }
    }
}
