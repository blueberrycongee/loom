import Foundation
import CoreGraphics
import LoomCore

/// CRUD façade for the `favorites` table.
///
/// Stored fields map directly to ``Favorite``. Photo IDs serialise as a
/// newline-joined string because SQLite doesn't have a native array type
/// and a tiny custom encoding is cheaper than pulling JSON in.
///
/// Intentionally distinct from `PhotoStore`: the same underlying
/// ``Database`` is reused via a second connection so callers on different
/// actors don't contend. The schema was declared in v1 of ``Schema``.
public final class FavoritesStore {

    private let db: Database

    public init(path: String) throws {
        self.db = try Database(path: path)
        // `Schema.migrate` is idempotent — safe to run here even if
        // PhotoStore already initialised the same file.
        try Schema.migrate(db)
    }

    // MARK: — Write

    public func save(_ favorite: Favorite) throws {
        let stmt = try db.prepare("""
            INSERT INTO favorites
                (id, name, style, axis, seed, photo_ids,
                 canvas_w, canvas_h, thumbnail, created_at)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, NULL, ?9)
            ON CONFLICT(id) DO UPDATE SET
                name       = excluded.name,
                style      = excluded.style,
                axis       = excluded.axis,
                seed       = excluded.seed,
                photo_ids  = excluded.photo_ids,
                canvas_w   = excluded.canvas_w,
                canvas_h   = excluded.canvas_h,
                created_at = excluded.created_at;
            """)
        stmt.bind(1, favorite.id.uuidString)
            .bind(2, favorite.name)
            .bind(3, favorite.style.rawValue)
            .bind(4, favorite.axis.rawValue)
            .bind(5, Int64(bitPattern: favorite.seed))
            .bind(6, favorite.photoIDs.map(\.rawValue).joined(separator: "\n"))
            .bind(7, Double(favorite.canvasSize.width))
            .bind(8, Double(favorite.canvasSize.height))
            .bind(9, favorite.createdAt.timeIntervalSince1970)
        _ = try stmt.step()
    }

    public func delete(_ id: UUID) throws {
        let stmt = try db.prepare("DELETE FROM favorites WHERE id = ?1;")
        stmt.bind(1, id.uuidString)
        _ = try stmt.step()
    }

    // MARK: — Read

    public func list(limit: Int = 100) throws -> [Favorite] {
        let stmt = try db.prepare("""
            SELECT id, name, style, axis, seed, photo_ids,
                   canvas_w, canvas_h, created_at
            FROM favorites
            ORDER BY created_at DESC
            LIMIT ?1;
            """)
        stmt.bind(1, limit)
        var out: [Favorite] = []
        while try stmt.step() {
            guard let fav = decode(stmt) else { continue }
            out.append(fav)
        }
        return out
    }

    public func count() throws -> Int {
        let stmt = try db.prepare("SELECT COUNT(*) FROM favorites;")
        _ = try stmt.step()
        return stmt.int(0)
    }

    // MARK: — Decoder

    private func decode(_ stmt: Statement) -> Favorite? {
        guard let id = UUID(uuidString: stmt.text(0)),
              let style = Style(rawValue: stmt.text(2)),
              let axis  = ClusterAxis(rawValue: stmt.text(3))
        else { return nil }
        let photoIDs = stmt.text(5)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { PhotoID(String($0)) }
        let seed = UInt64(bitPattern: stmt.int64(4))
        return Favorite(
            id: id,
            name: stmt.text(1),
            style: style,
            axis: axis,
            seed: seed,
            photoIDs: photoIDs,
            canvasSize: CGSize(width: stmt.double(6), height: stmt.double(7)),
            createdAt: Date(timeIntervalSince1970: stmt.double(8))
        )
    }
}
