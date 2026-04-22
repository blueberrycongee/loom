import SwiftUI

/// Loom's type system.
///
/// Two families, used with intent:
///   • **Display** — `.rounded` SF Pro, for the brand mark and section titles.
///     Rounded feels soft, approachable, a little craft-y — which matches the
///     "loom / weaving" metaphor.
///   • **Text** — system SF Pro, for everything functional. We don't mix
///     rounded and default on the same line; rounded is reserved for moments
///     that carry aesthetic weight.
///
/// Sizes follow a 1.25 minor-third scale, hand-tuned at the small end.
public enum LoomType {

    // MARK: — Display (rounded)

    public static let displayXL: Font = .system(size: 56, weight: .semibold, design: .rounded)
    public static let displayL:  Font = .system(size: 42, weight: .semibold, design: .rounded)
    public static let displayM:  Font = .system(size: 30, weight: .semibold, design: .rounded)
    public static let displayS:  Font = .system(size: 22, weight: .medium,   design: .rounded)

    // MARK: — Text

    public static let title:   Font = .system(size: 20, weight: .semibold)
    public static let heading: Font = .system(size: 16, weight: .semibold)
    public static let body:    Font = .system(size: 14, weight: .regular)
    public static let caption: Font = .system(size: 12, weight: .regular)
    public static let micro:   Font = .system(size: 10, weight: .medium).smallCaps()

    // MARK: — Mono

    public static let mono:   Font = .system(size: 12, weight: .regular, design: .monospaced)
    public static let monoSm: Font = .system(size: 10, weight: .regular, design: .monospaced)
}

// MARK: — Tracking (letter-spacing) conventions

public extension View {
    /// Tightens tracking for big display sizes where default kerning feels
    /// airy.
    func displayTracking() -> some View { self.tracking(-0.6) }
    /// Adds small-caps feel by widening tracking slightly. Pair with
    /// ``LoomType.micro``.
    func microTracking() -> some View  { self.tracking(1.2) }
}
