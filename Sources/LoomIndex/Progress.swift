import Foundation

/// Progress snapshot published by the Indexer while it works.
///
/// Kept as a single value type so SwiftUI can observe it without worrying
/// about partial updates — one snapshot, one redraw.
public struct IndexProgress: Sendable, Equatable {

    public enum Stage: Sendable, Equatable {
        case discovering        // walking the folder tree
        case extracting         // running per-file extractors
        case thumbnailing       // baking tile thumbnails
        case done
        case failed(String)
    }

    public let stage: Stage
    public let completed: Int
    public let total: Int
    public let currentFile: String?

    public init(
        stage: Stage,
        completed: Int = 0,
        total: Int = 0,
        currentFile: String? = nil
    ) {
        self.stage = stage
        self.completed = completed
        self.total = total
        self.currentFile = currentFile
    }

    /// Fraction in [0, 1]. Safe to call during discovery (returns 0).
    public var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1.0, Double(completed) / Double(total))
    }

    public var message: String {
        switch stage {
        case .discovering:       return "Finding photos…"
        case .extracting:        return "Analysing \(completed) of \(total)…"
        case .thumbnailing:      return "Baking previews \(completed) of \(total)…"
        case .done:              return "\(completed) photos ready."
        case .failed(let why):   return "Indexing failed: \(why)"
        }
    }
}
