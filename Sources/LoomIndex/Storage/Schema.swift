import Foundation

/// SQL schema + forward-only migrations.
///
/// The `user_version` PRAGMA tracks the current schema revision. On open, the
/// store runs every migration whose index is greater than the stored version
/// in order, each inside its own transaction. Migrations are **append-only**:
/// never edit an existing one, add a new one.
enum Schema {

    static let current: Int32 = 1

    static let migrations: [Int32: String] = [
        1: """
        CREATE TABLE photos (
            id               TEXT PRIMARY KEY NOT NULL,
            url              TEXT NOT NULL,
            width            INTEGER NOT NULL,
            height           INTEGER NOT NULL,
            captured_at      REAL,
            dominant_l       REAL NOT NULL,
            dominant_a       REAL NOT NULL,
            dominant_b       REAL NOT NULL,
            color_kelvin     REAL NOT NULL,
            feature_version  INTEGER,
            feature_bytes    BLOB,
            indexed_at       REAL NOT NULL
        );

        CREATE INDEX photos_indexed_at    ON photos(indexed_at);
        CREATE INDEX photos_captured_at   ON photos(captured_at);
        CREATE INDEX photos_color_kelvin  ON photos(color_kelvin);

        CREATE TABLE libraries (
            root_url    TEXT PRIMARY KEY NOT NULL,
            bookmark    BLOB NOT NULL,
            last_scan   REAL,
            photo_count INTEGER NOT NULL DEFAULT 0
        );

        CREATE TABLE favorites (
            id           TEXT PRIMARY KEY NOT NULL,
            name         TEXT NOT NULL,
            style        TEXT NOT NULL,
            axis         TEXT NOT NULL,
            seed         INTEGER NOT NULL,
            photo_ids    TEXT NOT NULL,      -- newline-joined PhotoIDs
            canvas_w     REAL NOT NULL,
            canvas_h     REAL NOT NULL,
            thumbnail    BLOB,
            created_at   REAL NOT NULL
        );
        """
    ]

    static func migrate(_ db: Database) throws {
        let version = try readUserVersion(db)
        let keys = migrations.keys.sorted()
        for v in keys where v > version {
            let sql = migrations[v]!
            try db.transaction {
                try db.exec(sql)
                try db.exec("PRAGMA user_version = \(v);")
            }
        }
    }

    private static func readUserVersion(_ db: Database) throws -> Int32 {
        let stmt = try db.prepare("PRAGMA user_version;")
        _ = try stmt.step()
        return Int32(stmt.int(0))
    }
}
