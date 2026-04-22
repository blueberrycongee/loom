import Foundation

/// Persists the user's photo-folder choice across launches.
///
/// On macOS, sandboxed apps can only reach a user-chosen folder via a
/// *security-scoped bookmark* returned by `NSOpenPanel`. We store that bookmark
/// in `UserDefaults` so we can resolve it (and start/stop access) on the next
/// launch without re-prompting the user.
///
/// Even when not sandboxed, using the bookmark API costs nothing and makes
/// the future sandbox transition a no-op.
public enum LibraryBookmark {

    private static let key = "loom.libraryBookmark"

    public static func save(_ url: URL) throws {
        let data = try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        UserDefaults.standard.set(data, forKey: key)
    }

    public static func load() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var stale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        ) else { return nil }
        // If the bookmark is stale (user moved the folder) we let the caller
        // re-prompt — returning the stale URL would silently break indexing.
        return stale ? nil : url
    }

    public static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// RAII helper that starts access on construction and stops it on deinit.
    /// Use as:
    /// ```
    /// let _scope = LibraryBookmark.Scope(url)
    /// try read(from: url)
    /// ```
    public final class Scope {
        let url: URL
        let entered: Bool

        public init(_ url: URL) {
            self.url = url
            self.entered = url.startAccessingSecurityScopedResource()
        }

        deinit {
            if entered { url.stopAccessingSecurityScopedResource() }
        }
    }
}
