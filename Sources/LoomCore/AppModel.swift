import Foundation
import Observation

/// The root observable. Single source of truth for the active library,
/// current wall, style, axis, and indexing progress.
///
/// Kept deliberately small — most interaction goes through dedicated child
/// view-models (WallModel, IndexModel) that this observable wires together.
@Observable
public final class AppModel {

    public enum Phase: Equatable {
        /// No library chosen yet. Renders the landing hero.
        case landing
        /// Indexing the chosen library. Carries the raw snapshot (stage +
        /// counts) so the view layer formats the progress message with
        /// LocalizedStringKey at render time — a pre-formatted String
        /// would bake in the call-time locale and break in-session
        /// language switching.
        case indexing(IndexingSnapshot)
        /// Library ready; a wall has been composed (or is empty awaiting Shuffle).
        case ready
    }

    public var phase: Phase = .landing
    public var style: Style = .exhibit
    public var axis: ClusterAxis = .color
    public var wall: Wall = .empty

    /// URL of the folder the user picked, if any. Persisted via a
    /// security-scoped bookmark inside ``LibraryBookmark``.
    public var libraryURL: URL?

    /// Full set of photos in the active library's index, newest first.
    /// Populated by the Indexer once it reaches the `done` stage.
    public var photos: [Photo] = []

    /// Photos the user has pinned. These are guaranteed to appear in every
    /// Shuffle until unpinned — position may change, inclusion doesn't.
    public var lockedPhotoIDs: Set<PhotoID> = []

    /// Active permission prompt (nil = none showing). Set by the
    /// coordinator based on system auth status; RootScene renders the
    /// corresponding sheet.
    public var permissionPrompt: PermissionPrompt?

    /// A rolling buffer of the most recently indexed photos, used by the
    /// indexing view to grow a live mini-wall in real time. Capped so the
    /// array doesn't balloon during scans of 50k+ libraries.
    public var recentlyIndexed: [Photo] = []
    private let recentlyIndexedCap = 96

    /// User-facing language override. Persisted; applied at runtime via
    /// `.environment(\.locale, …)` on the root scene.
    public var languagePreference: LanguagePreference = LanguagePreference.persisted

    /// Hand-sense (camera-driven gestures) enablement. Persisted —
    /// if the user turned it on previously and granted camera access,
    /// Loom auto-starts capture next launch.
    public var handSenseEnabled: Bool = HandSensePreference.enabled

    /// Continuous openness scalar driven by ``HandSense``. 0 = fist
    /// (tiles pull together), 0.5 = neutral (composition as laid),
    /// 1 = open palm (tiles spread). Consumed by WallCanvas as a
    /// spread factor around the canvas center.
    public var wallOpenness: Double = 0.5

    /// How tightly photos pack on the wall. Read by the Composer at
    /// every Shuffle to scale the target tile count. Persisted.
    public var density: WallDensity = WallDensity.persisted

    /// Skip blurry, overexposed, and tiny photos during composition.
    /// Default on — most users want a curated wall. Power users can
    /// disable in Settings to see every photo in the library.
    public var filterQuality: Bool = QualityFilterPreference.enabled

    public init() {}

    public func setStyle(_ s: Style) { style = s }
    public func setAxis(_ a: ClusterAxis) { axis = a }

    public func setPhotos(_ p: [Photo]) { photos = p }

    public func setPhase(_ p: Phase) { phase = p }

    public func toggleLock(_ id: PhotoID) {
        if lockedPhotoIDs.contains(id) {
            lockedPhotoIDs.remove(id)
        } else {
            lockedPhotoIDs.insert(id)
        }
    }

    public func clearLocks() { lockedPhotoIDs.removeAll() }

    public func present(_ prompt: PermissionPrompt) { permissionPrompt = prompt }
    public func dismissPermissionPrompt()            { permissionPrompt = nil }

    public func pushIndexed(_ photo: Photo) {
        recentlyIndexed.append(photo)
        if recentlyIndexed.count > recentlyIndexedCap {
            recentlyIndexed.removeFirst(recentlyIndexed.count - recentlyIndexedCap)
        }
    }

    /// One-shot fill for the MiniWall replay. A single array mutation
    /// produces one SwiftUI update → one Weave stagger wave. Calling
    /// ``pushIndexed`` N times in a loop would trigger N separate
    /// animations that cancel each other.
    public func prefillIndexed(_ photos: [Photo]) {
        recentlyIndexed = Array(photos.suffix(recentlyIndexedCap))
    }

    public func clearIndexed() { recentlyIndexed.removeAll() }

    public func setLanguage(_ pref: LanguagePreference) {
        languagePreference = pref
        LanguagePreference.persisted = pref
    }

    public func setHandSenseEnabled(_ enabled: Bool) {
        handSenseEnabled = enabled
        HandSensePreference.enabled = enabled
        if !enabled {
            // Reset openness so disabling doesn't leave the wall frozen
            // in whatever spread state the last gesture produced.
            wallOpenness = 0.5
        }
    }

    public func setOpenness(_ value: Double) {
        wallOpenness = max(0, min(1, value))
    }

    public func setDensity(_ d: WallDensity) {
        density = d
        WallDensity.persisted = d
    }

    public func setFilterQuality(_ enabled: Bool) {
        filterQuality = enabled
        QualityFilterPreference.enabled = enabled
    }
}

public enum QualityFilterPreference {
    private static let key = "loom.filterQuality"

    public static var enabled: Bool {
        get {
            // Default to true on first launch (key absent → true).
            if UserDefaults.standard.object(forKey: key) == nil { return true }
            return UserDefaults.standard.bool(forKey: key)
        }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

/// Persistence for the hand-sense master switch. Kept separate from
/// ``AppModel`` so launch-time coordinators can read it before an
/// AppModel instance exists.
public enum HandSensePreference {
    private static let key = "loom.handSenseEnabled"

    public static var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
