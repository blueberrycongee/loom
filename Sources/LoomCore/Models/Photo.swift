import Foundation

/// A photo that Loom knows about. This is the row model in the SQLite index
/// and the currency of every downstream subsystem.
///
/// ``Photo`` holds *only* lightweight metadata. The pixels live on disk
/// (``url``) and are loaded on-demand by the thumbnail cache or the wall
/// renderer.
///
/// Equality and hashing are by ``id``; two rows with the same identifier are
/// the same photo even if their derived fields (e.g. dominant color) have
/// been re-extracted.
public struct Photo: Identifiable, Hashable, Sendable {

    public let id: PhotoID
    public let url: URL
    public let pixelSize: PixelSize
    public let capturedAt: Date?
    public let dominantColor: LabColor
    public let colorTemperature: ColorTemperature
    public let featurePrint: FeaturePrint?
    public let indexedAt: Date

    public init(
        id: PhotoID,
        url: URL,
        pixelSize: PixelSize,
        capturedAt: Date? = nil,
        dominantColor: LabColor,
        colorTemperature: ColorTemperature,
        featurePrint: FeaturePrint? = nil,
        indexedAt: Date
    ) {
        self.id = id
        self.url = url
        self.pixelSize = pixelSize
        self.capturedAt = capturedAt
        self.dominantColor = dominantColor
        self.colorTemperature = colorTemperature
        self.featurePrint = featurePrint
        self.indexedAt = indexedAt
    }

    /// Native aspect ratio (width / height). Drives justified row packing.
    public var aspect: Double { pixelSize.aspect }

    public func hash(into h: inout Hasher) { h.combine(id) }
    public static func == (l: Photo, r: Photo) -> Bool { l.id == r.id }
}

/// A stable identifier. First 16 hex chars of SHA-256(fileURL.path) —
/// collision-resistant and reproducible without a central counter.
public struct PhotoID: RawRepresentable, Hashable, Sendable, Codable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

/// Pixel dimensions of the stored image.
public struct PixelSize: Hashable, Sendable, Codable {
    public let width: Int
    public let height: Int
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
    /// width / height, clamped to sane bounds to survive corrupt metadata.
    public var aspect: Double {
        let w = max(1, width), h = max(1, height)
        return Double(w) / Double(h)
    }
    /// True for square-ish photos (within 2%).
    public var isSquare: Bool { abs(aspect - 1.0) < 0.02 }
}
