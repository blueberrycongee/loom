import Foundation
import CryptoKit
import LoomCore

/// Deterministic ID generation for photos.
///
/// We hash the *absolute file path* rather than file contents: content
/// hashing would require reading the whole file on every scan, which is the
/// thing we're trying to avoid. Two edge cases the caller should know about:
///
///   • If a file is moved/renamed, it gets a new ID. The old row is orphaned
///     until the next reconcile pass, which deletes rows whose files no
///     longer exist.
///   • If a file is edited in place, the ID stays the same. We detect edits
///     by comparing `mtime` against `indexed_at` during scan.
///
/// Collision probability with a 64-bit prefix over realistic library sizes
/// (≤ 10⁶ photos) is < 10⁻⁷ — acceptable for a local-only index.
public enum PhotoIdentity {
    public static func id(for url: URL) -> PhotoID {
        let digest = SHA256.hash(data: Data(url.path.utf8))
        let hex = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        return PhotoID(hex)
    }
}
