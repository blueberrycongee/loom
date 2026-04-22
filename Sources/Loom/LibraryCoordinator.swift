import AppKit
import Foundation
import LoomCore
import LoomIndex

/// Bridges AppKit's `NSOpenPanel` with the `AppModel` + `Indexer`.
///
/// The coordinator lives on `@MainActor` — open-panel is UI, and we touch
/// `AppModel` from here. The indexing work itself runs on the `Indexer`
/// actor so we don't block the main thread.
@MainActor
final class LibraryCoordinator {

    private let app: AppModel
    private let favorites: FavoritesCoordinator?
    private var indexer: Indexer?
    private var photoKitIndexer: PhotoKitIndexer?
    private var task: Task<Void, Never>?

    init(app: AppModel, favorites: FavoritesCoordinator? = nil) {
        self.app = app
        self.favorites = favorites
        registerNotifications()
    }

    // MARK: — Notification plumbing

    private func registerNotifications() {
        let center = NotificationCenter.default
        center.addObserver(
            forName: .loomPickLibrary,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.pickLibrary() }
        }
        center.addObserver(
            forName: .loomFavoriteSavePayload,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let fav = note.object as? Favorite else { return }
            Task { @MainActor in self?.favorites?.save(fav) }
        }
        center.addObserver(
            forName: .loomPickPhotosLibrary,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.requestPhotosLibrary() }
        }
        center.addObserver(
            forName: .loomPermissionAllow,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let prompt = note.object as? PermissionPrompt else { return }
            Task { @MainActor in self?.handleAllow(prompt) }
        }
        center.addObserver(
            forName: .loomClearIndex,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.clearIndex() }
        }
    }

    /// Wipes the on-disk index + thumbnail cache for the current library
    /// and returns the app to the landing state so the user can pick
    /// fresh. Non-destructive to original photo files — only derived
    /// artefacts are removed.
    private func clearIndex() {
        task?.cancel()
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let base = appSupport.appendingPathComponent("Loom", isDirectory: true)
        // Remove Indexes/ and Thumbs/ under ~/Library/Application Support/Loom
        for sub in ["Indexes", "Thumbs"] {
            let dir = base.appendingPathComponent(sub, isDirectory: true)
            try? fm.removeItem(at: dir)
        }
        LibraryBookmark.clear()
        app.setPhotos([])
        app.clearIndexed()
        app.clearLocks()
        app.wall = .empty
        app.libraryURL = nil
        app.setPhase(.landing)
    }

    /// User tapped "Allow" in the in-app explainer. Follow up with the
    /// right next step for each prompt type.
    private func handleAllow(_ prompt: PermissionPrompt) {
        switch prompt {
        case .photosExplainer:
            // User has agreed to the preamble; now trigger the system TCC
            // prompt. On grant, immediately proceed to index.
            Task {
                let status = await PhotoKitAuthorization.request()
                await MainActor.run {
                    switch status {
                    case .authorized, .limited:
                        self.openPhotosLibrary()
                    case .denied, .restricted:
                        self.app.present(.photosDenied)
                    case .notDetermined:
                        break   // user cancelled the system dialog — do nothing
                    }
                }
            }
        case .photosDenied:
            // The sheet already deep-linked to System Settings; nothing
            // more to do until the user returns.
            break
        case .photosRestricted:
            // User chose the "use a folder instead" fallback from the
            // restricted sheet. Route to the folder picker.
            pickLibrary()
        case .cameraExplainer, .cameraDenied:
            // Camera permission flow is owned by HandSenseCoordinator.
            break
        }
    }

    /// Entry point when the user taps "Use Photos library". Routes based
    /// on current auth status rather than surfacing the system dialog
    /// cold.
    private func requestPhotosLibrary() {
        switch PhotoKitAuthorization.current() {
        case .authorized, .limited:
            openPhotosLibrary()
        case .notDetermined:
            app.present(.photosExplainer)
        case .denied:
            app.present(.photosDenied)
        case .restricted:
            app.present(.photosRestricted)
        }
    }

    /// Called at launch. If a bookmark exists, resume directly; else, the
    /// user sees the landing hero and must click the CTA.
    func bootstrap() {
        if let saved = LibraryBookmark.load() {
            openLibrary(saved)
        }
    }

    // MARK: — Folder picking

    private func pickLibrary() {
        let panel = NSOpenPanel()
        panel.title = "Choose a photo folder"
        panel.prompt = "Weave"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try LibraryBookmark.save(url)
            } catch {
                // Non-fatal; we just won't auto-resume next launch.
            }
            Task { @MainActor in self?.openLibrary(url) }
        }
    }

    // MARK: — Run

    private func openPhotosLibrary() {
        task?.cancel()
        app.libraryURL = URL(fileURLWithPath: "/photokit")
        favorites?.open(forLibraryRoot: app.libraryURL!)
        app.setPhase(.indexing(.discovering))

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let indexer = try PhotoKitIndexer()
                self.photoKitIndexer = indexer
                let stream = await indexer.run()
                for await snapshot in stream {
                    if Task.isCancelled { return }
                    let coreSnapshot = IndexingSnapshot.from(snapshot)
                    await MainActor.run {
                        self.app.setPhase(.indexing(coreSnapshot))
                        if let fresh = snapshot.recentPhoto {
                            self.app.pushIndexed(fresh)
                        }
                    }
                    if case .done = snapshot.stage {
                        let photos = (try? await indexer.allPhotos()) ?? []
                        await MainActor.run {
                            self.app.setPhotos(photos)
                            self.app.clearIndexed()
                            self.app.setPhase(.ready)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.app.setPhase(.indexing(
                        IndexingSnapshot(stage: .failed("Couldn't open Photos — \(error.localizedDescription)"))
                    ))
                }
            }
        }
    }

    private func openLibrary(_ url: URL) {
        task?.cancel()
        app.libraryURL = url
        favorites?.open(forLibraryRoot: url)
        app.setPhase(.indexing(.discovering))

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let indexer = try Indexer(libraryRoot: url)
                self.indexer = indexer
                let progress = await indexer.run()
                for await snapshot in progress {
                    if Task.isCancelled { return }
                    let coreSnapshot = IndexingSnapshot.from(snapshot)
                    await MainActor.run {
                        self.app.setPhase(.indexing(coreSnapshot))
                        if let fresh = snapshot.recentPhoto {
                            self.app.pushIndexed(fresh)
                        }
                    }
                    if case .done = snapshot.stage {
                        let photos = (try? await indexer.allPhotos()) ?? []
                        await MainActor.run {
                            self.app.setPhotos(photos)
                            self.app.clearIndexed()
                            self.app.setPhase(.ready)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.app.setPhase(.indexing(
                        IndexingSnapshot(stage: .failed(error.localizedDescription))
                    ))
                }
            }
        }
    }

}

// MARK: — Snapshot mapping

extension IndexingSnapshot {
    /// Map a ``LoomIndex.IndexProgress`` into the platform-free snapshot
    /// that ``AppModel.Phase.indexing`` carries. The mapping is total:
    /// every stage has a sensible destination and the counts pass
    /// through unchanged.
    fileprivate static func from(_ progress: IndexProgress) -> IndexingSnapshot {
        let stage: Stage = {
            switch progress.stage {
            case .discovering:       return .discovering
            case .extracting:        return .extracting
            case .thumbnailing:      return .thumbnailing
            case .done:              return .done
            case .failed(let why):   return .failed(why)
            }
        }()
        return IndexingSnapshot(
            stage: stage,
            completed: progress.completed,
            total: progress.total
        )
    }
}
