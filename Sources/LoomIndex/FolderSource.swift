import Foundation

/// Walks a folder, yielding the paths of photo files.
///
/// Recursion uses `FileManager.enumerator` — the directory stream is lazy, so
/// a 30k-photo folder doesn't materialize all URLs at once. Hidden files are
/// skipped (who keeps `.DS_Store` photos), symlinks are followed once, and
/// bundle directories (`.photoslibrary`, `.imovielibrary`, …) are treated
/// as opaque (users should point at plain folders, not libraries).
public enum FolderSource {

    /// Photo-like extensions we index.
    ///
    /// RAW formats are included: CoreImage / ImageIO (the same stack Photos
    /// and Preview use) natively decode every major RAW format. At
    /// indexing time we prefer the **embedded JPEG preview** on each RAW
    /// file (see ``ThumbnailCache`` / ``ColorAnalyzer``) so we pay
    /// milliseconds, not seconds, per file — the embedded preview is
    /// already in the palette/exposure space the photographer committed
    /// to, which is exactly what Loom wants to analyse.
    public static let extensions: Set<String> = [
        // Common baked-in formats
        "jpg", "jpeg", "heic", "heif", "png", "tif", "tiff", "webp", "bmp", "gif",
        // RAW (decoded through ImageIO; embedded previews used when present)
        "dng",                                 // Adobe / Apple ProRAW / generic
        "cr2", "cr3", "crw",                   // Canon
        "nef", "nrw",                          // Nikon
        "arw", "srf", "sr2",                   // Sony
        "raf",                                 // Fujifilm
        "orf",                                 // Olympus
        "rw2",                                 // Panasonic
        "pef",                                 // Pentax
        "srw",                                 // Samsung
        "raw", "rwl",                          // generic
        "3fr",                                 // Hasselblad
        "erf",                                 // Epson
        "x3f",                                 // Sigma
        "mrw"                                  // Minolta / Konica
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
