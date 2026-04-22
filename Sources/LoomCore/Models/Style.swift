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
        case .exhibit:   return "Exhibit"
        case .tapestry:  return "Tapestry"
        case .editorial: return "Editorial"
        case .gallery:   return "Gallery"
        case .collage:   return "Collage"
        case .minimal:   return "Minimal"
        case .vintage:   return "Vintage"
        }
    }

    public var tagline: String {
        switch self {
        case .exhibit:   return "Handcrafted composition · breathing room"
        case .tapestry:  return "Justified rows · woven like a textile"
        case .editorial: return "One hero · supporting satellites"
        case .gallery:   return "Golden-ratio grid · generous whitespace"
        case .collage:   return "Overlap · rotation · torn edges"
        case .minimal:   return "Three to five photos · high contrast"
        case .vintage:   return "Polaroid frames · mild skew"
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
        case .color:  return "Color"
        case .mood:   return "Mood"
        case .scene:  return "Scene"
        case .people: return "People"
        case .time:   return "Time"
        }
    }
}
