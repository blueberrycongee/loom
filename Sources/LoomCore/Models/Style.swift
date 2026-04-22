import Foundation

/// A wall style. Each value is backed by its own `LayoutEngine` and
/// aesthetic-scoring profile.
///
/// Ordering here is intentional: the first case is the app's default, and
/// the menu / picker lists styles in this order. Exhibit is the default
/// because Loom's identity is a hand-printed catalogue, not a photo grid.
public enum Style: String, CaseIterable, Sendable, Codable, Identifiable {
    case exhibit    // handcrafted composition with breathing room — default
    case tapestry   // justified rows, uniform row height
    case editorial  // one hero + satellites
    case gallery    // golden-ratio grid, generous whitespace
    case collage    // overlap, rotation, torn edges
    case minimal    // 3–5 photos, high contrast
    case vintage    // polaroid-framed, mild skew

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .exhibit:   return String(localized: "Exhibit")
        case .tapestry:  return String(localized: "Tapestry")
        case .editorial: return String(localized: "Editorial")
        case .gallery:   return String(localized: "Gallery")
        case .collage:   return String(localized: "Collage")
        case .minimal:   return String(localized: "Minimal")
        case .vintage:   return String(localized: "Vintage")
        }
    }

    public var tagline: String {
        switch self {
        case .exhibit:   return String(localized: "Handcrafted composition · breathing room")
        case .tapestry:  return String(localized: "Justified rows · woven like a textile")
        case .editorial: return String(localized: "One hero · supporting satellites")
        case .gallery:   return String(localized: "Golden-ratio grid · generous whitespace")
        case .collage:   return String(localized: "Overlap · rotation · torn edges")
        case .minimal:   return String(localized: "Three to five photos · high contrast")
        case .vintage:   return String(localized: "Polaroid frames · mild skew")
        }
    }

    /// Keyboard shortcut key for ⌘N.
    public var shortcutDigit: Int {
        switch self {
        case .exhibit:   return 1
        case .tapestry:  return 2
        case .editorial: return 3
        case .gallery:   return 4
        case .collage:   return 5
        case .minimal:   return 6
        case .vintage:   return 7
        }
    }
}

/// The axis we cluster on when picking a shortlist for a wall. Users can flip
/// this from the toolbar (⌥⌘ + C/M/S/P).
public enum ClusterAxis: String, CaseIterable, Sendable, Codable {
    case color    // color harmony (default)
    case mood     // semantic / CLIP-style embedding
    case scene    // scene classification
    case people   // face clusters
    case time     // capture-time proximity

    public var displayName: String {
        switch self {
        case .color:  return String(localized: "Color")
        case .mood:   return String(localized: "Mood")
        case .scene:  return String(localized: "Scene")
        case .people: return String(localized: "People")
        case .time:   return String(localized: "Time")
        }
    }
}
