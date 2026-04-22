import Foundation
import Photos

/// Thin wrapper over ``PHPhotoLibrary`` authorization.
///
/// The first call triggers the system prompt (using the
/// `NSPhotoLibraryUsageDescription` string from Info.plist). Subsequent calls
/// return the cached status without re-prompting.
///
/// We request `.readWrite` even though Loom only reads — the permission grant
/// covers both, and it means future features (e.g. "save a wall back to the
/// Photos library as a composite") don't need a second prompt.
public enum PhotoKitAuthorization {

    public enum Result: Sendable {
        case authorized       // full access
        case limited          // iOS-style subset — honor it
        case denied
        case restricted
        case notDetermined
    }

    public static func current() -> Result {
        adapt(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    @MainActor
    public static func request() async -> Result {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: adapt(status))
            }
        }
    }

    private static func adapt(_ status: PHAuthorizationStatus) -> Result {
        switch status {
        case .authorized:     return .authorized
        case .limited:        return .limited
        case .denied:         return .denied
        case .restricted:     return .restricted
        case .notDetermined:  return .notDetermined
        @unknown default:     return .denied
        }
    }
}
