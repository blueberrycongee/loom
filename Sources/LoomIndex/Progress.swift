import Foundation
import LoomCore

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

    /// If this snapshot corresponds to a freshly indexed photo, the photo
    /// is attached so the UI can render the live mini-wall. Not every
    /// snapshot carries one (coarse progress updates don't), so consumers
    /// should treat its absence as "no news, just a tick".
    public let recentPhoto: Photo?

    public init(
        stage: Stage,
        completed: Int = 0,
        total: Int = 0,
        currentFile: String? = nil,
        recentPhoto: Photo? = nil
    ) {
        self.stage = stage
        self.completed = completed
        self.total = total
        self.currentFile = currentFile
        self.recentPhoto = recentPhoto
    }

    /// Fraction in [0, 1]. Safe to call during discovery (returns 0).
    public var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1.0, Double(completed) / Double(total))
    }

    public var message: String {
        switch stage {
        case .discovering:
            return String(localized: "Finding photos…")
        case .extracting:
            return String(localized: "Analysing \(completed) of \(total)…")
        case .thumbnailing:
            return String(localized: "Baking previews \(completed) of \(total)…")
        case .done:
            return String(localized: "\(completed) photos ready.")
        case .failed(let why):
            return String(localized: "Indexing failed: \(why)")
        }
    }
}
