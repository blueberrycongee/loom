import CoreGraphics
import Foundation

/// Platform-free gesture primitives shared between the capture layer
/// (`HandSense`, in the Loom target) and the UI (`WallCanvas`,
/// `AppModel`). Kept in LoomCore so both can reference them without
/// introducing a cross-target dependency.
///
/// A ``HandSense`` session publishes ``HandEvent``s. The rendering layer
/// reads the resulting ``HandObservation`` off ``AppModel`` and
/// interprets it — this file defines *what* gets said, not *how*.
public enum HandEvent: Sendable, Equatable {

    /// A smoothed continuous sample. Emitted when the smoothed openness
    /// has moved past the deadzone relative to the last emit.
    case update(HandObservation)

    /// A discrete gesture that's already been cooldown-gated upstream.
    case gesture(HandGesture)

    /// No hand detected for the recently-elapsed window. UI should
    /// ease back to the neutral state (openness → 0.5).
    case lost

    /// Fatal or recoverable capture failure. String is human-readable.
    case failed(String)
}

/// A smoothed snapshot of the tracked hand at an instant.
public struct HandObservation: Sendable, Equatable {

    /// 0 = tight fist; 1 = fully open palm; 0.5 is the rest / neutral
    /// state the renderer treats as "the composition as the composer
    /// intended".
    public let openness: Double

    /// Palm center in the camera frame, normalized [0…1]. Front-camera
    /// frames are mirrored before sampling so *right* here always
    /// corresponds to *the user's right hand movement*, regardless of
    /// which side the camera sees it on.
    public let palm: CGPoint

    /// Average confidence across the joints we sampled. Consumers can
    /// attenuate effects when confidence is low (e.g. fade openness
    /// toward 0.5 rather than applying it fully).
    public let confidence: Double

    public let timestamp: Date

    public init(openness: Double, palm: CGPoint, confidence: Double, timestamp: Date) {
        self.openness = openness
        self.palm = palm
        self.confidence = confidence
        self.timestamp = timestamp
    }

    public static let neutral = HandObservation(
        openness: 0.5,
        palm: CGPoint(x: 0.5, y: 0.5),
        confidence: 0,
        timestamp: .distantPast
    )
}

public enum HandGesture: Sendable, Equatable {
    case swipeLeft
    case swipeRight
}

// MARK: — Tuning constants

/// All thresholds, cooldowns, and mapping ranges in one place so a future
/// ergonomics pass retunes the whole feature from here.
public enum HandSenseTuning {

    // Smoothing + deadzone
    public static let opennessSmoothingAlpha: Double = 0.15
    public static let opennessDeadzone: Double      = 0.03

    // Openness calibration (average fingertip-to-wrist distance in
    // Vision's normalized image coords).
    public static let minFingerSpan: Double = 0.06   // fist
    public static let maxFingerSpan: Double = 0.28   // open palm

    // Confidence floor under which a frame is ignored.
    public static let jointConfidenceFloor: Double = 0.20

    // Swipe detection
    public static let swipeVelocityThreshold: Double  = 1.6   // normalized x-per-second
    public static let swipeCooldown: TimeInterval     = 0.8

    // Recovery
    public static let lostAfter: TimeInterval = 1.2   // emit .lost after N sec without a confident frame

    // How openness maps to tile-layout scale. These feed
    // ``HandSenseTuning.spreadFactor(for:)`` — the WallCanvas scales tile
    // positions around the canvas center by this factor.
    public static let minSpreadFactor: Double = 0.55     // openness=0 → tight
    public static let neutralSpreadFactor: Double = 1.00 // openness=0.5 → composed layout
    public static let maxSpreadFactor: Double = 1.35     // openness=1 → dispersed but not flying away

    /// Map openness [0, 1] to a position-scale factor around canvas
    /// center. Piecewise linear so 0.5 is exactly "no change".
    public static func spreadFactor(for openness: Double) -> Double {
        let o = max(0, min(1, openness))
        if o <= 0.5 {
            let t = o / 0.5
            return minSpreadFactor + (neutralSpreadFactor - minSpreadFactor) * t
        } else {
            let t = (o - 0.5) / 0.5
            return neutralSpreadFactor + (maxSpreadFactor - neutralSpreadFactor) * t
        }
    }
}
