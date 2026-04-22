import CoreGraphics
import Foundation

/// One composed wall.
///
/// A ``Wall`` is immutable: the composer builds one by running the layout
/// engine, and the UI renders it. To change it, the user presses Shuffle,
/// which produces a *new* Wall with a new ``id``.
///
/// The ``seed`` is the RNG seed used during composition. Saving a wall to
/// Favorites stores the seed + photos + style, so it can be reproduced
/// identically later.
public struct Wall: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let style: Style
    public let axis: ClusterAxis
    public let seed: UInt64
    public let tiles: [Tile]
    public let canvasSize: CGSize
    public let composedAt: Date

    public init(
        id: UUID = UUID(),
        style: Style,
        axis: ClusterAxis,
        seed: UInt64,
        tiles: [Tile],
        canvasSize: CGSize,
        composedAt: Date = Date()
    ) {
        self.id = id
        self.style = style
        self.axis = axis
        self.seed = seed
        self.tiles = tiles
        self.canvasSize = canvasSize
        self.composedAt = composedAt
    }

    public static let empty = Wall(
        style: .tapestry,
        axis: .color,
        seed: 0,
        tiles: [],
        canvasSize: .zero
    )

    public var isEmpty: Bool { tiles.isEmpty }
}

/// A phase of a per-tile direct-manipulation drag (resize or move).
///
/// Lives in ``LoomCore`` so both ``LoomUI.TileView`` (which emits) and
/// ``LoomUI.WallCanvas`` (which consumes) can reference the type without
/// either depending on the other.
public enum TileDragPhase: Sendable {
    case began
    case changed(CGSize)   // cumulative screen-space translation from drag start
    case ended
}

/// Which corner-handle the user is dragging during a resize. The handle's
/// *opposite* corner is the anchor — it stays pinned while the drag grows
/// or shrinks the tile along the diagonal.
public enum ResizeCorner: Sendable, Hashable {
    case topLeft, topRight, bottomLeft, bottomRight

    /// Unit-length outward direction from the tile center through the
    /// corner. Dragging along this vector grows the tile; along the
    /// opposite vector shrinks it. Used by ``WallCanvas`` to project the
    /// screen-space drag onto a single signed magnitude.
    public var outward: CGSize {
        let s = CGFloat(0.7071067811865476) // 1/√2
        switch self {
        case .topLeft:     return CGSize(width: -s, height: -s)
        case .topRight:    return CGSize(width:  s, height: -s)
        case .bottomLeft:  return CGSize(width: -s, height:  s)
        case .bottomRight: return CGSize(width:  s, height:  s)
        }
    }
}

/// A placed photo on a wall.
///
/// ``frame`` is in the wall's own coordinate system (top-left origin, points
/// — not pixels). ``rotation`` is in radians. ``z`` is draw order (lower =
/// further back) — meaningful only for Collage / Vintage where tiles can
/// overlap.
public struct Tile: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let photoID: PhotoID
    public var frame: CGRect
    public var rotation: Double
    public var z: Int

    public init(
        id: UUID = UUID(),
        photoID: PhotoID,
        frame: CGRect,
        rotation: Double = 0,
        z: Int = 0
    ) {
        self.id = id
        self.photoID = photoID
        self.frame = frame
        self.rotation = rotation
        self.z = z
    }

    public var aspect: Double {
        guard frame.height > 0 else { return 1 }
        return Double(frame.width / frame.height)
    }
}
