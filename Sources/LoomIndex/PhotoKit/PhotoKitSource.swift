import Foundation
import Photos

/// Enumerates photos the Photos app manages, as a second data source next to
/// ``FolderSource``.
///
/// **Status — M7 scaffold.** This enumerates assets and resolves per-asset
/// file URLs lazily via ``PHContentEditingInput``. The full indexer
/// integration (wiring the extractor pipeline to this source) lands in a
/// follow-up commit; right now the code stands ready to be called by a
/// PhotoKit-aware variant of the Indexer actor.
///
/// Why PHContentEditingInput instead of PHImageManager?
///   • `PHContentEditingInput.fullSizeImageURL` returns a real file URL
///     inside the Photos library bundle, so all existing extractors
///     (ImageIO, Core Image, Vision) continue to work without per-backend
///     dispatch.
///   • It honors Photos' security-scope; we don't need to copy bytes to a
///     temp location.
public enum PhotoKitSource {

    /// Enumerate image assets in the user's Photos library, optionally
    /// restricted to a given album / smart collection.
    public static func fetchImageAssets() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        return PHAsset.fetchAssets(with: options)
    }

    /// Count without materialising the fetch result's objects.
    public static func imageCount() -> Int {
        fetchImageAssets().count
    }

    /// Resolve a single asset's real file URL for read-only processing.
    ///
    /// PhotoKit requires this to be async because the bundle may need to
    /// rehydrate from iCloud before we can touch bytes. The caller decides
    /// policy (fail vs wait) by choosing `options.isNetworkAccessAllowed`.
    public static func resolveFileURL(for asset: PHAsset) async -> URL? {
        await withCheckedContinuation { continuation in
            let options = PHContentEditingInputRequestOptions()
            options.isNetworkAccessAllowed = false
            options.canHandleAdjustmentData = { _ in false }
            asset.requestContentEditingInput(with: options) { input, _ in
                continuation.resume(returning: input?.fullSizeImageURL)
            }
        }
    }

    /// Observe the Photos library for add/delete events. Pass the returned
    /// token to ``stopObserving`` when done. The handler runs on the main
    /// actor.
    public static func observeLibrary(
        _ handler: @escaping @MainActor @Sendable () -> Void
    ) -> PhotoKitObserver {
        let observer = PhotoKitObserver(handler: handler)
        PHPhotoLibrary.shared().register(observer)
        return observer
    }

    public static func stopObserving(_ observer: PhotoKitObserver) {
        PHPhotoLibrary.shared().unregisterChangeObserver(observer)
    }
}

public final class PhotoKitObserver: NSObject, PHPhotoLibraryChangeObserver {
    private let handler: @MainActor @Sendable () -> Void

    fileprivate init(handler: @escaping @MainActor @Sendable () -> Void) {
        self.handler = handler
    }

    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in handler() }
    }
}
