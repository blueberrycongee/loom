import Foundation

/// Walks a folder, yielding the paths of photo files.
///
/// Recursion uses `FileManager.enumerator` — the directory stream is lazy, so
/// a 30k-photo folder doesn't materialize all URLs at once. Hidden files are
/// skipped (who keeps `.DS_Store` photos), symlinks are followed once, and
/// bundle directories (`.photoslibrary`, `.imovielibrary`, …) are treated
/// as opaque (users should point at plain folders, not libraries).
public enum FolderSource {

    /// Photo-like extensions we index. Kept conservative — we skip RAW for
    /// now because Vision's feature-print model expects baked-in sRGB and
    /// adding RAW decoding risks slow/incorrect results in v1.
    public static let extensions: Set<String> = [
        "jpg", "jpeg", "heic", "heif", "png", "tif", "tiff", "webp"
    ]

    /// Walk `root` recursively and return every photo URL found.
    ///
    /// This buffers results in memory; acceptable for libraries up to ~10⁵
    /// photos. The orchestrator turns the array into batches for the
    /// extractor pipeline.
    public static func discover(in root: URL) -> [URL] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .isHiddenKey, .isPackageKey]
        let options: FileManager.DirectoryEnumerationOptions =
            [.skipsHiddenFiles, .skipsPackageDescendants]

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: options,
            errorHandler: nil
        ) else { return [] }

        var out: [URL] = []
        out.reserveCapacity(1024)

        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true,
                  values?.isHidden != true,
                  values?.isPackage != true
            else { continue }
            let ext = url.pathExtension.lowercased()
            if extensions.contains(ext) {
                out.append(url)
            }
        }
        return out
    }
}
