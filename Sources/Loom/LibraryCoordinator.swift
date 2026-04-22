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

    private func openLibrary(_ url: URL) {
        task?.cancel()
        app.libraryURL = url
        favorites?.open(forLibraryRoot: url)
        app.setPhase(.indexing(progress: 0, message: "Finding photos…"))

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let indexer = try Indexer(libraryRoot: url)
                self.indexer = indexer
                let progress = await indexer.run()
                for await snapshot in progress {
                    if Task.isCancelled { return }
                    await MainActor.run {
                        self.app.setPhase(.indexing(
                            progress: snapshot.fraction,
                            message: snapshot.message
                        ))
                    }
                    if case .done = snapshot.stage {
                        let photos = (try? await indexer.allPhotos()) ?? []
                        await MainActor.run {
                            self.app.setPhotos(photos)
                            self.app.setPhase(.ready)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.app.setPhase(.indexing(
                        progress: 0,
                        message: "Couldn't open that folder — \(error.localizedDescription)"
                    ))
                }
            }
        }
    }
}
