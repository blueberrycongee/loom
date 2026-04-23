import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import LoomCore

/// A content-addressed thumbnail cache.
///
/// Thumbnails live at
/// `~/Library/Application Support/Loom/Thumbs/<size>/<first2>/<id>.jpg`
///
/// The `<first2>` fan-out keeps directory listings short on huge libraries
/// (HFS+ can get slow past ~4k entries per directory). Files are JPEG
/// because disk is tight and the quality loss at 95% is imperceptible at
/// tile sizes.
public final class ThumbnailCache {

    public enum Size: Int, CaseIterable, Sendable {
        case grid = 320      // for the index browser grid
        case tile = 2048     // for the wall at display resolution
    }

    private let root: URL

    public init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.root = base
            .appendingPathComponent("Loom", isDirectory: true)
            .appendingPathComponent("Thumbs", isDirectory: true)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    public func url(for id: PhotoID, size: Size) -> URL {
        let hex = id.rawValue
        let bucket = String(hex.prefix(2))
        return root
            .appendingPathComponent("\(size.rawValue)", isDirectory: true)
            .appendingPathComponent(bucket, isDirectory: true)
            .appendingPathComponent("\(hex).jpg")
    }

    public func contains(_ id: PhotoID, size: Size) -> Bool {
        FileManager.default.fileExists(atPath: url(for: id, size: size).path)
    }

    /// Generate (if missing) and return the on-disk URL of the thumbnail.
    /// Returns `nil` if the source image can't be read.
    @discardableResult
    public func ensure(for id: PhotoID, source: URL, size: Size) -> URL? {
        let dest = url(for: id, size: size)
        if FileManager.default.fileExists(atPath: dest.path) { return dest }

        guard let src = CGImageSourceCreateWithURL(source as CFURL, nil) else { return nil }
        // Prefer embedded preview when present (fast, correct for RAW;
        // effectively free for JPEG/HEIC which already are the "preview").
        // Falls back to a full decode when the file has no embedded thumb.
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform:    true,
            kCGImageSourceThumbnailMaxPixelSize:           size.rawValue,
            kCGImageSourceShouldCacheImmediately:          true
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else {
            return nil
        }

        try? FileManager.default.createDirectory(
            at: dest.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard let destCF = CGImageDestinationCreateWithURL(
            dest as CFURL,
            UTType.jpeg.identifier as CFString,
            1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destCF, cg, [
            kCGImageDestinationLossyCompressionQuality: 0.92 as CFNumber
        ] as CFDictionary)
        return CGImageDestinationFinalize(destCF) ? dest : nil
    }

    /// Delete every cached thumbnail. Wired to the "Clear Index" setting.
    public func wipe() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: root.path) {
            try fm.removeItem(at: root)
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
        }
    }
}
