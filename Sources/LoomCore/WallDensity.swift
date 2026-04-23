import Foundation

/// How tightly photos are packed on the wall.
///
/// Represented as a continuous 0...1 scalar where 0 is the most spacious
/// (fewer, larger photos) and 1 is the most compact (many more, smaller
/// photos). The composer reads this on every Shuffle and sizes the target
/// count accordingly.
///
/// Style-specific caps still apply — Exhibit/Editorial are hero layouts
/// with hardcoded 1+N tiles, and Minimal intentionally stays at 3–5. The
/// density knob most visibly affects Tapestry, Gallery, Collage, Vintage.
public struct WallDensity: Sendable, Codable, Equatable {
    /// 0 = most spacious, 1 = most compact.
    public var value: Double

    public init(_ value: Double) {
        self.value = max(0, min(1, value))
    }

    /// Multiplier applied to the composer's baseline tile area.
    /// Higher values yield bigger tiles (fewer of them);
    /// lower values yield smaller tiles (more of them).
    public var tileAreaFactor: Double {
        let maxFactor = 2.0   // spacious end
        let minFactor = 0.08  // compact end — well beyond the old "dense" 0.55
        return maxFactor - value * (maxFactor - minFactor)
    }

    // MARK: — Persistence

    private static let legacyKey = "loom.wallDensity"
    private static let storageKey = "loom.wallDensity.value"

    public static var persisted: WallDensity {
        get {
            // New format first.
            if let v = UserDefaults.standard.object(forKey: storageKey) as? Double {
                return WallDensity(v)
            }
            // One-time migration from legacy enum strings.
            if let raw = UserDefaults.standard.string(forKey: legacyKey) {
                let migrated: WallDensity
                switch raw {
                case "roomy":    migrated = WallDensity(0.0)
                case "dense":    migrated = WallDensity(1.0)
                default:         migrated = WallDensity(0.35) // balanced
                }
                UserDefaults.standard.set(migrated.value, forKey: storageKey)
                return migrated
            }
            return WallDensity(0.35) // default ~balanced
        }
        set {
            UserDefaults.standard.set(newValue.value, forKey: storageKey)
        }
    }
}
