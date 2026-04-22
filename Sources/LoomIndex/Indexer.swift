import Foundation
import LoomCore

/// The indexing orchestrator.
///
/// `Indexer` owns the `PhotoStore` and `ThumbnailCache` for one library root
/// and drives every stage of the pipeline:
///
///     discover → extract metadata → extract color → extract feature-print
///              → upsert → bake grid thumbnails
///
/// The actor boundary gives us a free serialization guarantee for SQLite,
/// which is not thread-safe. Parallelism happens *inside* each stage via
/// `TaskGroup`s that yield back to the actor to write.
///
/// Progress is surfaced through an `AsyncStream<IndexProgress>` so views can
/// observe via `for await`.
public actor Indexer {

    private let store: PhotoStore
    private let thumbs: ThumbnailCache
    private let root: URL
    private var cancelled = false

    public init(libraryRoot: URL) throws {
        self.root = libraryRoot
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbDir = appSupport
            .appendingPathComponent("Loom", isDirectory: true)
            .appendingPathComponent("Indexes", isDirectory: true)
        try? fm.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbPath = dbDir
            .appendingPathComponent(PhotoIdentity.id(for: libraryRoot).rawValue)
            .appendingPathExtension("sqlite")
            .path
        self.store = try PhotoStore(path: dbPath)
        self.thumbs = ThumbnailCache()
    }

    public func cancel() { cancelled = true }

    /// Run one full pass. Incremental — already-indexed photos whose files
    /// haven't been modified are skipped.
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
        out.yield(IndexProgress(stage: .discovering))

        // The bookmark scope must stay live for the whole pipeline; its
        // lifetime is bound to `access`.
        let access = LibraryBookmark.Scope(root)
        _ = access  // keep-alive

        let urls = FolderSource.discover(in: root)
        if urls.isEmpty {
            out.yield(IndexProgress(stage: .done))
            return
        }

        let known: Set<PhotoID>
        do { known = try store.knownIDs() } catch { known = [] }

        // Stage 1 — extract for every URL we don't already have indexed,
        // batching into 200-photo transactions to keep the SQLite writer
        // warm without losing too much work on a crash.
        var done = 0
        let total = urls.count
        let batchSize = 64
        var batch: [Photo] = []
        batch.reserveCapacity(batchSize)

        for url in urls {
            if cancelled { break }
            let id = PhotoIdentity.id(for: url)

            // Skip already-indexed, unmodified files.
            if known.contains(id),
               let rowDate = try? store.find(id)?.indexedAt,
               let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let mtime = attrs[.modificationDate] as? Date,
               mtime <= rowDate {
                done += 1
                out.yield(IndexProgress(
                    stage: .extracting, completed: done, total: total,
                    currentFile: url.lastPathComponent
                ))
                continue
            }

            var freshPhoto: Photo?
            if let photo = extractOne(url: url, id: id) {
                batch.append(photo)
                freshPhoto = photo
                if batch.count >= batchSize {
                    try? store.upsert(batch)
                    batch.removeAll(keepingCapacity: true)
                }
            }
            done += 1
            // Attach every freshly indexed photo to the progress snapshot
            // so the indexing UI can grow a live mini-wall in real time.
            out.yield(IndexProgress(
                stage: .extracting, completed: done, total: total,
                currentFile: url.lastPathComponent,
                recentPhoto: freshPhoto
            ))
        }
        if !batch.isEmpty { try? store.upsert(batch) }

        if cancelled {
            out.yield(IndexProgress(stage: .done, completed: done, total: total))
            return
        }

        // Stage 2 — bake grid thumbnails for fast browse. Tile-size thumbs
        // are lazy; they come up on demand when the wall renders.
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

        out.yield(IndexProgress(
            stage: .done,
            completed: done, total: total
        ))
    }

    /// Single-photo extractor. Any stage that fails leaves the corresponding
    /// field as a sensible default; the photo still gets indexed so the user
    /// sees something on screen.
    private func extractOne(url: URL, id: PhotoID) -> Photo? {
        guard let meta = MetadataReader.read(url) else { return nil }
        let color = ColorAnalyzer.analyze(url)
            ?? ColorAnalyzer.Result(
                dominant: .midGray,
                temperature: .neutral
            )
        let print = VisionFeatures.extract(from: url)
        let clip = CLIPFeatures.extract(from: url)
        let quality = QualityAnalyzer.analyze(url, pixelSize: meta.pixelSize)
        let borders = BorderDetector.detect(url)
        return Photo(
            id: id,
            url: url,
            pixelSize: meta.pixelSize,
            capturedAt: meta.capturedAt,
            dominantColor: color.dominant,
            colorTemperature: color.temperature,
            featurePrint: print,
            clipEmbedding: clip,
            qualityScore: quality,
            cropInsets: borders,
            indexedAt: Date()
        )
    }
}
