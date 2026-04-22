import CoreGraphics
import Foundation

/// A saved wall the user chose to keep.
///
/// A Favorite is enough to *reproduce* a wall byte-for-byte on demand:
/// given the same library + (seed, style, axis, photo IDs, canvas size),
/// the composer returns the same Wall. Storing the seed plus the
/// explicit photo-ID list means favorites survive library growth — new
/// photos added later don't affect past favorites.
public struct Favorite: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let name: String
    public let style: Style
    public let axis: ClusterAxis
    public let seed: UInt64
    public let photoIDs: [PhotoID]
    public let canvasSize: CGSize
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        style: Style,
        axis: ClusterAxis,
        seed: UInt64,
        photoIDs: [PhotoID],
        canvasSize: CGSize,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.style = style
        self.axis = axis
        self.seed = seed
        self.photoIDs = photoIDs
        self.canvasSize = canvasSize
        self.createdAt = createdAt
    }
}
