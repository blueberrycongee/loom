import Foundation

/// App-wide notification names.
///
/// Declared in LoomCore so both the `Loom` executable target (which posts
/// some of these from the menu bar) and the `LoomUI` target (which subscribes
/// to others from inside views) can see them without creating a
/// cross-target dependency.
///
/// NotificationCenter is deliberately low-tech for this event surface. When
/// the app grows more subsystems wanting to coordinate, we'll replace this
/// with a dedicated typed router — but until then, the zero-dependency
/// broadcast fits the usage pattern.
public extension Notification.Name {
    static let loomShuffle              = Notification.Name("loom.shuffle")
    static let loomPickLibrary          = Notification.Name("loom.pickLibrary")
    static let loomFavoriteSave         = Notification.Name("loom.favoriteSave")
    static let loomFavoriteSavePayload  = Notification.Name("loom.favoriteSavePayload")
    static let loomFavoriteApply        = Notification.Name("loom.favoriteApply")
    static let loomExportPNG            = Notification.Name("loom.exportPNG")
    static let loomExportPDF            = Notification.Name("loom.exportPDF")
}
