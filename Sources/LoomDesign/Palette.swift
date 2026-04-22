import SwiftUI

/// The Loom palette.
///
/// Loom's canvas is dark by design — photos carry the color, so the chrome
/// stays out of the way. The dark is warm (a touch of ochre in the black) to
/// avoid the clinical OLED feel. Accent is **brass**: a muted warm amber that
/// reads as "hand-finished" rather than "tech startup blue".
///
/// Colors are declared as static `Color` values so they compose naturally in
/// SwiftUI. For AppKit bridges, use ``nsColor`` / ``cgColor`` on demand.
public enum Palette {

    // MARK: — Canvas

    /// Default window background. Near-black, warm.
    public static let canvas = Color(red: 0.055, green: 0.055, blue: 0.063)          // #0E0E10
    /// One step up from canvas, for raised surfaces (sheets, popovers).
    public static let surface = Color(red: 0.102, green: 0.102, blue: 0.114)         // #1A1A1D
    /// Two steps up — for cards inside sheets, or the wall's chrome bar.
    public static let surfaceElevated = Color(red: 0.145, green: 0.145, blue: 0.157) // #252528
    /// Hairline divider. Deliberately low-contrast so it suggests, not states.
    public static let hairline = Color.white.opacity(0.06)

    // MARK: — Ink

    /// Primary foreground text.
    public static let ink = Color(red: 0.95, green: 0.94, blue: 0.92)                // #F2F0EB
    /// Secondary text — labels, timestamps.
    public static let inkMuted = Color.white.opacity(0.58)
    /// Tertiary — captions, hints, "press Space to shuffle" nudges.
    public static let inkFaint = Color.white.opacity(0.32)

    // MARK: — Accent

    /// Loom's signature warm amber. Used for the Shuffle CTA, focus rings,
    /// progress bars, and exactly nothing else without a reason.
    public static let brass = Color(red: 0.788, green: 0.647, blue: 0.482)           // #C9A57B
    /// A slightly brighter brass for hover / pressed states.
    public static let brassLift = Color(red: 0.847, green: 0.718, blue: 0.553)       // #D8B78D
    /// Deepest brass — used on copper-plate surfaces that need an accent wash.
    public static let brassShade = Color(red: 0.667, green: 0.518, blue: 0.357)      // #AA845B

    // MARK: — Semantic

    public static let success = Color(red: 0.506, green: 0.706, blue: 0.529)         // #81B487
    public static let warning = Color(red: 0.882, green: 0.702, blue: 0.396)         // #E1B365
    public static let danger  = Color(red: 0.831, green: 0.447, blue: 0.408)         // #D47268
}

// MARK: — Gradient helpers

public extension Palette {
    /// Subtle vertical vignette applied behind the wall to lift its edges.
    static let canvasVignette = LinearGradient(
        stops: [
            .init(color: Color.black.opacity(0.22), location: 0.00),
            .init(color: Color.clear,               location: 0.35),
            .init(color: Color.clear,               location: 0.65),
            .init(color: Color.black.opacity(0.28), location: 1.00)
        ],
        startPoint: .top, endPoint: .bottom
    )

    /// Brass-on-brass gradient for the primary button's fill.
    static let brassFill = LinearGradient(
        colors: [brassLift, brass, brassShade],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}
