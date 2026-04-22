import Foundation
import SQLite3

/// A small, opinionated wrapper around the system ``SQLite3`` C API.
///
/// We deliberately don't pull in GRDB or SQLite.swift — the surface area we
/// need is tiny (open/exec/prepare/step/bind/read) and avoiding a dependency
/// keeps the build fast, the binary small, and the behaviour well understood.
///
/// Thread model: ``Database`` is **not** thread-safe. Each ``PhotoStore`` /
/// ``Indexer`` holds its own connection on its own actor.
public final class Database {

    fileprivate var handle: OpaquePointer?
    public let path: String

    public init(path: String) throws {
        self.path = path
        var h: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX
        let rc = sqlite3_open_v2(path, &h, flags, nil)
        guard rc == SQLITE_OK, let h else {
            let msg = h.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "sqlite3_open_v2 failed"
            if let h { sqlite3_close_v2(h) }
            throw SQLiteError(code: rc, message: msg)
        }
        self.handle = h
        try exec("PRAGMA journal_mode=WAL;")
        try exec("PRAGMA synchronous=NORMAL;")
        try exec("PRAGMA foreign_keys=ON;")
        try exec("PRAGMA temp_store=MEMORY;")
    }

    deinit { if let handle { sqlite3_close_v2(handle) } }

    public func exec(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(handle, sql, nil, nil, &err)
        if rc != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? "sqlite3_exec failed"
            sqlite3_free(err)
            throw SQLiteError(code: rc, message: msg)
        }
    }

    public func prepare(_ sql: String) throws -> Statement {
        var stmt: OpaquePointer?
        let rc = sqlite3_prepare_v2(handle, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let stmt else {
            throw SQLiteError(code: rc, message: errmsg)
        }
        return Statement(stmt: stmt, db: self)
    }

    public func transaction<T>(_ body: () throws -> T) throws -> T {
        try exec("BEGIN IMMEDIATE;")
        do {
            let result = try body()
            try exec("COMMIT;")
            return result
        } catch {
            try? exec("ROLLBACK;")
            throw error
        }
    }

    public var lastInsertRowID: Int64 { sqlite3_last_insert_rowid(handle) }

    fileprivate var errmsg: String {
        handle.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
    }
}

public final class Statement {

    fileprivate var stmt: OpaquePointer?
    private weak var db: Database?

    // SQLite requires SQLITE_TRANSIENT for strings/blobs whose lifetime is
    // not guaranteed to outlive the call. We capture it once.
    private static let transient = unsafeBitCast(
        OpaquePointer(bitPattern: -1),
        to: sqlite3_destructor_type.self
    )

    fileprivate init(stmt: OpaquePointer, db: Database) {
        self.stmt = stmt
        self.db = db
    }

    deinit { if let stmt { sqlite3_finalize(stmt) } }

    // MARK: — Bind (1-indexed, matching SQLite convention)

    @discardableResult
    public func bind(_ idx: Int32, _ value: Int64) -> Statement {
        sqlite3_bind_int64(stmt, idx, value); return self
    }

    @discardableResult
    public func bind(_ idx: Int32, _ value: Int) -> Statement {
        sqlite3_bind_int64(stmt, idx, Int64(value)); return self
    }

    @discardableResult
    public func bind(_ idx: Int32, _ value: Double) -> Statement {
        sqlite3_bind_double(stmt, idx, value); return self
    }

    @discardableResult
    public func bind(_ idx: Int32, _ value: String) -> Statement {
        sqlite3_bind_text(stmt, idx, value, -1, Statement.transient); return self
    }

    @discardableResult
    public func bind(_ idx: Int32, _ value: Data) -> Statement {
        value.withUnsafeBytes { raw in
            _ = sqlite3_bind_blob(stmt, idx, raw.baseAddress, Int32(raw.count), Statement.transient)
        }
        return self
    }

    @discardableResult
    public func bindNull(_ idx: Int32) -> Statement {
        sqlite3_bind_null(stmt, idx); return self
    }

    @discardableResult
    public func bind<T: SQLiteBindable>(_ idx: Int32, _ value: T?) -> Statement {
        if let v = value { v.bind(to: self, at: idx) } else { bindNull(idx) }
        return self
    }

    // MARK: — Step / read

    public func step() throws -> Bool {
        let rc = sqlite3_step(stmt)
        switch rc {
        case SQLITE_ROW:  return true
        case SQLITE_DONE: return false
        default:
            throw SQLiteError(code: rc, message: db?.errmsg ?? "step failed")
        }
    }

    public func reset() {
        sqlite3_reset(stmt)
        sqlite3_clear_bindings(stmt)
    }

    public func int(_ col: Int32) -> Int {
        Int(sqlite3_column_int64(stmt, col))
    }

    public func int64(_ col: Int32) -> Int64 {
        sqlite3_column_int64(stmt, col)
    }

    public func double(_ col: Int32) -> Double {
        sqlite3_column_double(stmt, col)
    }

    public func text(_ col: Int32) -> String {
        guard let cstr = sqlite3_column_text(stmt, col) else { return "" }
        return String(cString: cstr)
    }

    public func textOrNil(_ col: Int32) -> String? {
        sqlite3_column_type(stmt, col) == SQLITE_NULL ? nil : text(col)
    }

    public func doubleOrNil(_ col: Int32) -> Double? {
        sqlite3_column_type(stmt, col) == SQLITE_NULL ? nil : double(col)
    }

    public func intOrNil(_ col: Int32) -> Int? {
        sqlite3_column_type(stmt, col) == SQLITE_NULL ? nil : int(col)
    }

    public func blob(_ col: Int32) -> Data {
        let n = Int(sqlite3_column_bytes(stmt, col))
        guard n > 0, let p = sqlite3_column_blob(stmt, col) else { return Data() }
        return Data(bytes: p, count: n)
    }

    public func blobOrNil(_ col: Int32) -> Data? {
        sqlite3_column_type(stmt, col) == SQLITE_NULL ? nil : blob(col)
    }
}

public struct SQLiteError: Error, CustomStringConvertible {
    public let code: Int32
    public let message: String
    public var description: String { "SQLite error \(code): \(message)" }
}

/// Types that know how to bind themselves. Keeps callsites like
/// `stmt.bind(1, photo.indexedAt)` clean.
public protocol SQLiteBindable {
    func bind(to statement: Statement, at index: Int32)
}

extension Int:    SQLiteBindable { public func bind(to s: Statement, at i: Int32) { s.bind(i, self) } }
extension Int64:  SQLiteBindable { public func bind(to s: Statement, at i: Int32) { s.bind(i, self) } }
extension Double: SQLiteBindable { public func bind(to s: Statement, at i: Int32) { s.bind(i, self) } }
extension String: SQLiteBindable { public func bind(to s: Statement, at i: Int32) { s.bind(i, self) } }
extension Data:   SQLiteBindable { public func bind(to s: Statement, at i: Int32) { s.bind(i, self) } }

extension Date: SQLiteBindable {
    public func bind(to s: Statement, at i: Int32) { s.bind(i, timeIntervalSince1970) }
}
