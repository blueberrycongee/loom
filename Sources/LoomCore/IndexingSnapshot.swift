import Foundation

/// A progress snapshot the UI can bind to — the LoomCore mirror of
/// ``LoomIndex.IndexProgress`` (which lives in LoomIndex and can't be seen
/// from LoomCore where ``AppModel.Phase`` is declared).
///
/// The coordinator maps one to the other; the critical difference is this
/// type holds only **structured data** (stage + counts), not a pre-formatted
/// message string. The indexing view builds the localized message at
/// render time via ``LocalizedStringKey`` so an in-app language switch
/// updates the visible text immediately — a pre-formatted String would
/// have baked in the call-time locale and stayed stale.
public struct IndexingSnapshot: Equatable, Sendable {

    public enum Stage: Equatable, Sendable {
        case discovering
        case extracting
        case thumbnailing
        case done
        case failed(String)
    }

    public let stage: Stage
    public let completed: Int
    public let total: Int

    public init(stage: Stage, completed: Int = 0, total: Int = 0) {
        self.stage = stage
        self.completed = completed
        self.total = total
    }

    public var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1.0, Double(completed) / Double(total))
    }

    public static let discovering = IndexingSnapshot(stage: .discovering)
}
