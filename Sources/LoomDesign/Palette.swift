import SwiftUI

/// The Loom palette — **paper** preset (default).
///
/// The original direction treated the canvas as a dark gallery wall with
/// brass signage. That reads as "industrial photo viewer". Loom's real
/// temperament is a hand-printed exhibit catalogue — cream paper, charcoal
/// ink, a muted terracotta accent that reads as "hand-finished" rather than
/// "premium UI". Photos carry the color; the chrome is restrained to the
/// point of disappearing.
///
/// Tokens are declared as static `Color` values so they compose naturally
/// in SwiftUI. Names retained across the dark→paper pivot (`brass`,
/// `brassLift`, `brassShade`) to avoid a churn-commit across every call
/// site — the values are now warm terracotta; think of the name as
/// "accent family" from here on.
public enum Palette {

    // MARK: — Canvas

    /// Default window background. Warm cream, the color of raw printmaking
    /// paper before the ink takes.
    public static let canvas = Color(red: 0.965, green: 0.948, blue: 0.918)          // #F6F2EA
    /// One step up from canvas, for raised surfaces (sheets, popovers).
    public static let surface = Color(red: 0.988, green: 0.975, blue: 0.948)         // #FCF8F2
    /// Two steps up — near-white, for cards inside sheets.
    public static let surfaceElevated = Color(red: 1.000, green: 0.992, blue: 0.973) // #FFFDF8
    /// Hairline divider. Warm charcoal at very low alpha so lines
    /// *suggest* rather than state.
    public static let hairline = Color(red: 0.10, green: 0.08, blue: 0.07).opacity(0.10)

    // MARK: — Ink

    /// Primary foreground text — warm charcoal, not pure black. Black on
    /// cream reads as photocopied; this reads as printed.
    public static let ink = Color(red: 0.165, green: 0.137, blue: 0.118)             // #2A231E
    /// Secondary text — labels, timestamps.
    public static let inkMuted = Color(red: 0.25, green: 0.21, blue: 0.18).opacity(0.70)
    /// Tertiary — captions, hints.
    public static let inkFaint = Color(red: 0.30, green: 0.26, blue: 0.22).opacity(0.42)

    // MARK: — Accent (terracotta)

    /// Muted terracotta — hand-mixed earth pigment. Sits on cream paper the
    /// way an ink stamp sits on a catalogue cover.
    public static let brass = Color(red: 0.706, green: 0.478, blue: 0.369)           // #B47A5E
    /// Slightly brighter terracotta for hover / pressed states.
    public static let brassLift = Color(red: 0.776, green: 0.545, blue: 0.435)       // #C68B6F
    /// Deeper terracotta — for copper-plate surfaces that need an accent wash.
    public static let brassShade = Color(red: 0.620, green: 0.408, blue: 0.310)      // #9E6850

    // MARK: — Semantic (tuned for light canvas)

    public static let success = Color(red: 0.376, green: 0.510, blue: 0.380)         // muted sage
    public static let warning = Color(red: 0.761, green: 0.510, blue: 0.220)         // burnt amber
    public static let danger  = Color(red: 0.690, green: 0.306, blue: 0.263)         // muted rust
}

// MARK: — Gradient helpers

public extension Palette {
    /// Very subtle warm vignette applied behind the wall. On paper the
    /// vignette is whispered — we don't want dark halos, just a breath of
    /// tone at the corners to lift the composition away from the edges.
    static let canvasVignette = RadialGradient(
        stops: [
            .init(color: Color.clear,                                      location: 0.00),
            .init(color: Color(red: 0.82, green: 0.78, blue: 0.72).opacity(0.00), location: 0.70),
            .init(color: Color(red: 0.82, green: 0.78, blue: 0.72).opacity(0.22), location: 1.00)
        ],
        center: .center,
        startRadius: 120,
        endRadius: 900
    )

    /// Terracotta-on-terracotta gradient for the primary CTA's fill.
    static let brassFill = LinearGradient(
        colors: [brassLift, brass, brassShade],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}
