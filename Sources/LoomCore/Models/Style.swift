import Foundation

/// A wall style. Each value is backed by its own `LayoutEngine` and
/// aesthetic-scoring profile.
public enum Style: String, CaseIterable, Sendable, Codable, Identifiable {
    case tapestry   // justified rows, uniform row height — default
    case editorial  // one hero + satellites
    case gallery    // golden-ratio grid, generous whitespace
    case collage    // overlap, rotation, torn edges
    case minimal    // 3–5 photos, high contrast
    case vintage    // polaroid-framed, mild skew

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
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
        case .tapestry:  return 1
        case .editorial: return 2
        case .gallery:   return 3
        case .collage:   return 4
        case .minimal:   return 5
        case .vintage:   return 6
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
