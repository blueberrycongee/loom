import Foundation
import LoomCore
import LoomIndex

/// Binds the Favorites UI to SQLite.
///
/// Held by `LoomApp` as a companion to `LibraryCoordinator`. Re-creates the
/// backing store when the library changes, because each library has its own
/// SQLite file (favorites belong to a library — they reference its PhotoIDs
/// and those don't generalise across folders).
@MainActor
final class FavoritesCoordinator {

    private(set) var favorites: [Favorite] = []
    private var store: FavoritesStore?

    func open(forLibraryRoot url: URL) {
        // Match the path scheme used by Indexer.
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbPath = appSupport
            .appendingPathComponent("Loom", isDirectory: true)
            .appendingPathComponent("Indexes", isDirectory: true)
            .appendingPathComponent(PhotoIdentity.id(for: url).rawValue)
            .appendingPathExtension("sqlite")
            .path
        store = try? FavoritesStore(path: dbPath)
        reload()
    }

    func save(_ favorite: Favorite) {
        guard let store else { return }
        try? store.save(favorite)
        reload()
    }

    func delete(_ id: UUID) {
        guard let store else { return }
        try? store.delete(id)
        reload()
    }

    private func reload() {
        favorites = (try? store?.list()) ?? []
    }
}
