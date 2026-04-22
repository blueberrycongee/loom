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
        /// Indexing the chosen library.
        case indexing(progress: Double, message: String)
        /// Library ready; a wall has been composed (or is empty awaiting Shuffle).
        case ready
    }

    public var phase: Phase = .landing
    public var style: Style = .tapestry
    public var axis: ClusterAxis = .color
    public var wall: Wall = .empty

    /// URL of the folder the user picked, if any. Persisted via a
    /// security-scoped bookmark inside ``LibraryBookmark``.
    public var libraryURL: URL?

    /// Full set of photos in the active library's index, newest first.
    /// Populated by the Indexer once it reaches the `done` stage.
    public var photos: [Photo] = []

    public init() {}

    public func setStyle(_ s: Style) { style = s }
    public func setAxis(_ a: ClusterAxis) { axis = a }

    public func setPhotos(_ p: [Photo]) { photos = p }

    public func setPhase(_ p: Phase) { phase = p }
}
