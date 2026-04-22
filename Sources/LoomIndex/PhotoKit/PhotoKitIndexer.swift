import Foundation
import Photos
import LoomCore

/// Indexes photos managed by the Photos app (M7).
///
/// Parallel to the folder-based ``Indexer`` but walking `PHAsset` objects
/// instead of file URLs. Each asset's pixels are read through
/// ``PhotoKitSource.resolveFileURL`` — which returns the real file inside
/// the Photos library bundle — so every existing extractor (ImageIO,
/// Core Image, Vision) works unchanged.
///
/// Identity: uses `PHAsset.localIdentifier` hashed via ``PhotoIdentity.id``
/// so the PhotoID survives Photos library moves / bundle path changes.
public actor PhotoKitIndexer {

    private let store: PhotoStore
    private let thumbs: ThumbnailCache
    private var cancelled = false

    public init() throws {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbDir = appSupport
            .appendingPathComponent("Loom", isDirectory: true)
            .appendingPathComponent("Indexes", isDirectory: true)
        try? fm.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbPath = dbDir
            .appendingPathComponent("photokit")
            .appendingPathExtension("sqlite")
            .path
        self.store = try PhotoStore(path: dbPath)
        self.thumbs = ThumbnailCache()
    }

    public func cancel() { cancelled = true }

    public func run() -> AsyncStream<IndexProgress> {
        AsyncStream { continuation in
            Task { [weak self] in
                await self?.execute(continuation)
                continuation.finish()
            }
        }
    }

    public func allPhotos() throws -> [Photo] {
        try store.all()
    }

    // MARK: — Pipeline

    private func execute(_ out: AsyncStream<IndexProgress>.Continuation) async {
        let status = PhotoKitAuthorization.current()
        if status != .authorized && status != .limited {
            let result = await PhotoKitAuthorization.request()
            if result != .authorized && result != .limited {
                out.yield(IndexProgress(stage: .failed("Photos access denied — grant in System Settings → Privacy.")))
                return
            }
        }

        out.yield(IndexProgress(stage: .discovering))
        let fetch = PhotoKitSource.fetchImageAssets()
        let total = fetch.count
        guard total > 0 else {
            out.yield(IndexProgress(stage: .done))
            return
        }

        let known = (try? store.knownIDs()) ?? []

        var done = 0
        var batch: [Photo] = []
        batch.reserveCapacity(64)

        for i in 0..<total {
            if cancelled { break }
            let asset = fetch.object(at: i)
            let id = identity(for: asset)

            // Skip if already indexed and asset's modificationDate is older.
            if known.contains(id),
               let existing = try? store.find(id),
               let mtime = asset.modificationDate,
               mtime <= existing.indexedAt {
                done += 1
                out.yield(IndexProgress(
                    stage: .extracting, completed: done, total: total,
                    currentFile: "\(id.rawValue)"
                ))
                continue
            }

            guard let url = await PhotoKitSource.resolveFileURL(for: asset) else {
                done += 1; continue
            }

            if let photo = extractOne(asset: asset, id: id, url: url) {
                batch.append(photo)
                if batch.count >= 64 {
                    try? store.upsert(batch)
                    batch.removeAll(keepingCapacity: true)
                }
            }
            done += 1
            out.yield(IndexProgress(
                stage: .extracting, completed: done, total: total,
                currentFile: url.lastPathComponent
            ))
        }
        if !batch.isEmpty { try? store.upsert(batch) }

        if cancelled {
            out.yield(IndexProgress(stage: .done, completed: done, total: total))
            return
        }

        // Bake grid thumbnails.
        let photos = (try? store.all(limit: total)) ?? []
        var baked = 0
        for p in photos {
            if cancelled { break }
            _ = thumbs.ensure(for: p.id, source: p.url, size: .grid)
            baked += 1
            if baked % 16 == 0 || baked == photos.count {
                out.yield(IndexProgress(
                    stage: .thumbnailing,
                    completed: baked, total: photos.count,
                    currentFile: p.url.lastPathComponent
                ))
            }
        }

        out.yield(IndexProgress(stage: .done, completed: done, total: total))
    }

    private func extractOne(asset: PHAsset, id: PhotoID, url: URL) -> Photo? {
        // Pixel dims come from PHAsset, not the file — Photos sometimes wraps
        // HEIC bundles where ImageIO sees the preview dims.
        let size = PixelSize(width: asset.pixelWidth, height: asset.pixelHeight)

        let color = ColorAnalyzer.analyze(url)
            ?? ColorAnalyzer.Result(dominant: .midGray, temperature: .neutral)
        let print = VisionFeatures.extract(from: url)

        return Photo(
            id: id,
            url: url,
            pixelSize: size,
            capturedAt: asset.creationDate,
            dominantColor: color.dominant,
            colorTemperature: color.temperature,
            featurePrint: print,
            indexedAt: Date()
        )
    }

    /// Stable PhotoID from PhotoKit's local identifier.
    private func identity(for asset: PHAsset) -> PhotoID {
        // Reuse the SHA256-prefix scheme from PhotoIdentity so all IDs across
        // the app share one shape. Feed it the localIdentifier disguised as
        // a URL.
        let key = URL(fileURLWithPath: "/photokit/" + asset.localIdentifier)
        return PhotoIdentity.id(for: key)
    }
}
