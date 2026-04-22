import Foundation
import Vision
import LoomCore

/// Wraps ``VNGenerateImageFeaturePrintRequest`` into a clean one-shot call.
///
/// Vision's feature-print is a 768-dim L2-normalised embedding produced by a
/// screener model optimised for visual similarity (not semantics). It's
/// perfect for clustering photos that *look* similar — same scene, same
/// palette, same composition — without any training or downloaded model.
///
/// Revision 2 (the one pinned here) is the current best, available on
/// macOS 14+.
enum VisionFeatures {

    static let requestRevision = VNGenerateImageFeaturePrintRequest.currentRevision

    /// Extract a feature-print. Returns `nil` if Vision refused the file
    /// (unreadable, corrupt, or unsupported format) rather than throwing —
    /// one bad photo shouldn't sink the whole index run.
    static func extract(from url: URL) -> FeaturePrint? {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = requestRevision

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            return nil
        }

        // The raw bytes are stored on the observation; copy them out so the
        // buffer lifetime is decoupled from the Vision request.
        let bytes = observation.data
        return FeaturePrint(version: Int(observation.requestRevision), bytes: bytes)
    }
}
