import SwiftUI

/// Corner-radius tokens.
///
/// Photo tiles are sharp-cornered (0pt) — the photo IS the tile, and
/// rounded corners add a "digital frame" that fights the paper-canvas
/// metaphor. Cards, popovers, sheets step up. Pill-shaped controls use
/// ``pill`` which is then clipped to `capsule`.
public enum LoomRadius {
    public static let hairline: CGFloat = 2
    public static let tile:     CGFloat = 0
    public static let card:     CGFloat = 14
    public static let sheet:    CGFloat = 20
    public static let window:   CGFloat = 12
    public static let pill:     CGFloat = 999
}

/// Spacing scale — a 4pt grid everywhere.
public enum LoomSpacing {
    public static let xxs: CGFloat = 2
    public static let xs:  CGFloat = 4
    public static let sm:  CGFloat = 8
    public static let md:  CGFloat = 12
    public static let lg:  CGFloat = 20
    public static let xl:  CGFloat = 32
    public static let xxl: CGFloat = 56
}
