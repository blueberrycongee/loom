import Foundation

/// A permission prompt the UI should show, driven from ``AppModel``.
///
/// The shape is deliberately tiny so the core doesn't depend on AppKit /
/// Photos / Vision — the coordinator translates system auth status into one
/// of these cases, and LoomUI translates the case into a presentation.
///
/// When nil (the default), no prompt is showing. Setting it to a case
/// surfaces the corresponding sheet in RootScene; dismissing sets it back
/// to nil.
public enum PermissionPrompt: Equatable, Sendable {

    /// Shown on first-ever Photos-library request (status .notDetermined).
    /// The sheet explains *why* before the system's TCC prompt appears —
    /// so the user sees the reason in the app's voice, and the one-shot
    /// system dialog arrives with context rather than cold.
    case photosExplainer

    /// Shown when the user has previously denied Photos access. The system
    /// dialog won't reappear; the only path forward is System Settings. We
    /// surface a deep link + instructions instead of a dead-end.
    case photosDenied

    /// Shown when Photos access is .restricted (MDM / parental controls).
    /// Explains that this isn't user-fixable and points at folder mode as
    /// a workaround.
    case photosRestricted

    /// Shown on first enablement of the hand-gesture feature, before
    /// the TCC camera prompt fires.
    case cameraExplainer

    /// Shown when camera access has previously been denied. Deep-links
    /// to System Settings → Privacy & Security → Camera.
    case cameraDenied
}
