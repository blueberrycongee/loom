import Foundation
import SwiftUI

/// How tightly photos are packed on the wall.
///
/// Expressed as a multiplier on the composer's baseline tile area: higher
/// multipliers mean bigger tiles (fewer of them); lower means smaller
/// (more of them). The user picks this in Settings; the composer reads it
/// on every Shuffle and sizes the target count accordingly.
///
/// Style-specific caps still apply — Exhibit/Editorial are hero layouts
/// with hardcoded 1+N tiles, and Minimal intentionally stays at 3–5. The
/// density knob most visibly affects Tapestry, Gallery, Collage, Vintage.
public enum WallDensity: String, CaseIterable, Sendable, Codable {
    case roomy
    case balanced
    case dense

    public var id: String { rawValue }

    /// Multiplier applied to the composer's baseline tile area. >1 yields
    /// bigger tiles (because area / baseline drops), <1 yields smaller.
    public var tileAreaFactor: Double {
        switch self {
        case .roomy:    1.7
        case .balanced: 1.0
        case .dense:    0.55
        }
    }

    public var displayName: LocalizedStringKey {
        switch self {
        case .roomy:    return "Roomy"
        case .balanced: return "Balanced"
        case .dense:    return "Dense"
        }
    }

    // MARK: — Persistence

    private static let storageKey = "loom.wallDensity"

    public static var persisted: WallDensity {
        get {
            guard
                let raw = UserDefaults.standard.string(forKey: storageKey),
                let value = WallDensity(rawValue: raw)
            else { return .balanced }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }
}
