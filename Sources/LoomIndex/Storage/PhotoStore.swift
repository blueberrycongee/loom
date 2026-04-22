import Foundation
import LoomCore

/// CRUD façade for the `photos` table. Owns its own connection; safe to use
/// from one actor at a time.
public final class PhotoStore {

    private let db: Database

    public init(path: String) throws {
        self.db = try Database(path: path)
        try Schema.migrate(db)
    }

    // MARK: — Write

    public func upsert(_ photo: Photo) throws {
        let stmt = try db.prepare("""
            INSERT INTO photos
                (id, url, width, height, captured_at,
                 dominant_l, dominant_a, dominant_b, color_kelvin,
                 feature_version, feature_bytes, indexed_at)
            VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)
            ON CONFLICT(id) DO UPDATE SET
                url             = excluded.url,
                width           = excluded.width,
                height          = excluded.height,
                captured_at     = excluded.captured_at,
                dominant_l      = excluded.dominant_l,
                dominant_a      = excluded.dominant_a,
                dominant_b      = excluded.dominant_b,
                color_kelvin    = excluded.color_kelvin,
                feature_version = excluded.feature_version,
                feature_bytes   = excluded.feature_bytes,
                indexed_at      = excluded.indexed_at;
            """)
        stmt.bind(1, photo.id.rawValue)
            .bind(2, photo.url.path)
            .bind(3, photo.pixelSize.width)
            .bind(4, photo.pixelSize.height)
        if let captured = photo.capturedAt {
            stmt.bind(5, captured.timeIntervalSince1970)
        } else {
            stmt.bindNull(5)
        }
        stmt.bind(6, photo.dominantColor.l)
            .bind(7, photo.dominantColor.a)
            .bind(8, photo.dominantColor.b)
            .bind(9, photo.colorTemperature.kelvin)
        if let fp = photo.featurePrint {
            stmt.bind(10, fp.version).bind(11, fp.bytes)
        } else {
            stmt.bindNull(10).bindNull(11)
        }
        stmt.bind(12, photo.indexedAt.timeIntervalSince1970)
        _ = try stmt.step()
    }

    public func upsert(_ batch: [Photo]) throws {
        try db.transaction {
            for p in batch { try upsert(p) }
        }
    }

    public func delete(_ id: PhotoID) throws {
        let stmt = try db.prepare("DELETE FROM photos WHERE id = ?1;")
        stmt.bind(1, id.rawValue)
        _ = try stmt.step()
    }

    // MARK: — Read

    public func count() throws -> Int {
        let stmt = try db.prepare("SELECT COUNT(*) FROM photos;")
        _ = try stmt.step()
        return stmt.int(0)
    }

    public func all(limit: Int = 50_000) throws -> [Photo] {
        let stmt = try db.prepare("""
            SELECT id, url, width, height, captured_at,
                   dominant_l, dominant_a, dominant_b, color_kelvin,
                   feature_version, feature_bytes, indexed_at
            FROM photos
            ORDER BY captured_at DESC
            LIMIT ?1;
            """)
        stmt.bind(1, limit)
        var out: [Photo] = []
        while try stmt.step() {
            out.append(decode(stmt))
        }
        return out
    }

    public func find(_ id: PhotoID) throws -> Photo? {
        let stmt = try db.prepare("""
            SELECT id, url, width, height, captured_at,
                   dominant_l, dominant_a, dominant_b, color_kelvin,
                   feature_version, feature_bytes, indexed_at
            FROM photos WHERE id = ?1 LIMIT 1;
            """)
        stmt.bind(1, id.rawValue)
        return try stmt.step() ? decode(stmt) : nil
    }

    public func knownIDs() throws -> Set<PhotoID> {
        let stmt = try db.prepare("SELECT id FROM photos;")
        var out: Set<PhotoID> = []
        while try stmt.step() {
            out.insert(PhotoID(stmt.text(0)))
        }
        return out
    }

    // MARK: — Decoder

    private func decode(_ stmt: Statement) -> Photo {
        let captured = stmt.doubleOrNil(4).map { Date(timeIntervalSince1970: $0) }
        let featureVersion = stmt.intOrNil(9)
        let featureBytes = stmt.blobOrNil(10)
        let fp: FeaturePrint?
        if let v = featureVersion, let b = featureBytes {
            fp = FeaturePrint(version: v, bytes: b)
        } else {
            fp = nil
        }
        return Photo(
            id: PhotoID(stmt.text(0)),
            url: URL(fileURLWithPath: stmt.text(1)),
            pixelSize: PixelSize(width: stmt.int(2), height: stmt.int(3)),
            capturedAt: captured,
            dominantColor: LabColor(l: stmt.double(5), a: stmt.double(6), b: stmt.double(7)),
            colorTemperature: ColorTemperature(kelvin: stmt.double(8)),
            featurePrint: fp,
            indexedAt: Date(timeIntervalSince1970: stmt.double(11))
        )
    }
}
