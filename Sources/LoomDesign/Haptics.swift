#if canImport(AppKit)
import AppKit
#endif

/// Trackpad haptics, judiciously applied.
///
/// On macOS, ``NSHapticFeedbackManager`` emits subtle Force-Touch thumps. Good
/// haptics feel like the UI has inertia; bad haptics feel like a sales pitch.
/// Loom uses them for exactly three moments:
///
///   • ``shuffle`` — a double-tap of `.levelChange` at the moment tiles
///     re-deal, so the hand feels the event even when the eye is elsewhere.
///   • ``snap`` — `.alignment` when a dragged tile snaps to a grid guide.
///   • ``confirm`` — `.generic` when a destructive choice is accepted.
public enum Haptics {

    public static func shuffle() {
        #if canImport(AppKit)
        let m = NSHapticFeedbackManager.defaultPerformer
        m.perform(.levelChange, performanceTime: .now)
        // Second tap 40ms later, forming a "tock-tock" rather than a single
        // thud — this matches the weave motion's two-phase feel.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
            m.perform(.levelChange, performanceTime: .now)
        }
        #endif
    }

    public static func snap() {
        #if canImport(AppKit)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        #endif
    }

    public static func confirm() {
        #if canImport(AppKit)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }
}
