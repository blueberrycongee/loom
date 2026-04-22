import Foundation

/// An opaque embedding produced by Vision's `VNGenerateImageFeaturePrintRequest`.
///
/// Vision gives us a `VNFeaturePrintObservation` whose raw bytes are a
/// 768-dim float32 vector. We store the raw bytes and a tiny bit of metadata
/// so distances stay cheap.
public struct FeaturePrint: Hashable, Sendable, Codable {
    public let version: Int
    public let bytes: Data

    public init(version: Int, bytes: Data) {
        self.version = version
        self.bytes = bytes
    }

    /// Float32 count in the embedding. Vision's v1 is 768; guard for future
    /// model shifts.
    public var dimension: Int { bytes.count / MemoryLayout<Float>.size }

    /// Euclidean distance. Vision also ships `computeDistance(_:_:)` for
    /// signed-distance semantics when both observations are live; for persisted
    /// bytes we recompute ourselves. Vision's prints are L2-normalised, so L2
    /// distance and cosine distance rank identically.
    public func distance(to other: FeaturePrint) -> Double {
        guard dimension == other.dimension, dimension > 0 else { return .infinity }
        return bytes.withUnsafeBytes { (a: UnsafeRawBufferPointer) -> Double in
            other.bytes.withUnsafeBytes { (b: UnsafeRawBufferPointer) -> Double in
                let af = a.bindMemory(to: Float.self)
                let bf = b.bindMemory(to: Float.self)
                var acc: Float = 0
                for i in 0..<dimension {
                    let d = af[i] - bf[i]
                    acc += d * d
                }
                return Double(acc.squareRoot())
            }
        }
    }
}
