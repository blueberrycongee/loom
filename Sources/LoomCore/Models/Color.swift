import Foundation

/// A CIE L*a*b* color.
///
/// We store dominant color in L*a*b* (not RGB or HSL) because perceptual
/// distance in Lab approximates "how different do these colors look to a
/// human". That's exactly what the color-harmony clusterer wants.
///
///   • L* ∈ [0, 100]   — lightness
///   • a* ∈ [-128, 127] — green (-) ↔ red (+)
///   • b* ∈ [-128, 127] — blue  (-) ↔ yellow (+)
public struct LabColor: Hashable, Sendable, Codable {
    public let l: Double
    public let a: Double
    public let b: Double

    public init(l: Double, a: Double, b: Double) {
        self.l = l
        self.a = a
        self.b = b
    }

    /// CIEDE2000 is more accurate, but plain ΔE76 is enough for clustering
    /// and avoids a meaningful CPU cost when scored thousands of times per
    /// shuffle. We revisit if perceptual accuracy ever becomes the bottleneck.
    public func deltaE(_ other: LabColor) -> Double {
        let dL = l - other.l
        let da = a - other.a
        let db = b - other.b
        return (dL * dL + da * da + db * db).squareRoot()
    }

    /// Chroma (distance from the neutral axis). High-chroma = saturated.
    public var chroma: Double { (a * a + b * b).squareRoot() }

    /// Hue angle in radians, 0 = +a* axis, π/2 = +b* axis, etc.
    /// Undefined when chroma is near zero; callers should check ``isNeutral``.
    public var hue: Double { atan2(b, a) }

    /// True when the color is close enough to neutral that hue is meaningless.
    public var isNeutral: Bool { chroma < 4.0 }

    public static let black  = LabColor(l: 0,     a: 0, b: 0)
    public static let white  = LabColor(l: 100,   a: 0, b: 0)
    public static let midGray = LabColor(l: 50,   a: 0, b: 0)
}

/// Color temperature in Kelvin. Used as a secondary cue for "warm" vs "cool"
/// groupings that color-harmony alone misses.
public struct ColorTemperature: Hashable, Sendable, Codable {
    public let kelvin: Double

    public init(kelvin: Double) { self.kelvin = kelvin }

    public var isWarm: Bool { kelvin < 5000 }
    public var isCool: Bool { kelvin > 6500 }

    public static let neutral = ColorTemperature(kelvin: 5500)
}
