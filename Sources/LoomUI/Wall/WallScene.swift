import SwiftUI
import LoomCore
import LoomCompose
import LoomDesign

/// The wall surface — the default "ready" view.
///
/// Layout:
///
///   ┌─────────────────────────────────────────┐
///   │                                         │
///   │           WallCanvas (fills)            │
///   │                                         │
///   │                                         │
///   │        ╭────── WallChrome ──────╮       │
///   │        │ axis · style · shuffle │       │
///   │        ╰────────────────────────╯       │
///   └─────────────────────────────────────────┘
///
/// On first appearance with an empty wall, shuffles immediately — the user
/// should see a composed wall, not a "press Shuffle" label.
public struct WallScene: View {

    @Environment(AppModel.self) private var app
    @State private var canvasSize: CGSize = .zero

    private let composer = Composer(candidates: 4)

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            canvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            emptyHint
                .opacity(app.wall.isEmpty ? 1 : 0)
                .animation(LoomMotion.breathe, value: app.wall.isEmpty)

            WallChrome(shuffle: shuffleNow)
                .padding(.bottom, LoomSpacing.xl)
        }
        .onAppear {
            // Auto-shuffle on first entry so users see a wall immediately.
            if app.wall.isEmpty && !app.photos.isEmpty {
                Task { @MainActor in
                    // Small delay so the scene has a measured canvas size.
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    shuffleNow()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .loomShuffle)) { _ in
            shuffleNow()
        }
        .onReceive(NotificationCenter.default.publisher(for: .loomFavoriteSave)) { _ in
            saveCurrentAsFavorite()
        }
        .onReceive(NotificationCenter.default.publisher(for: .loomFavoriteApply)) { note in
            if let fav = note.object as? Favorite { apply(fav) }
        }
    }

    private func saveCurrentAsFavorite() {
        guard !app.wall.isEmpty else { return }
        let name = defaultFavoriteName(for: app.wall)
        let fav = Favorite(
            name: name,
            style: app.wall.style,
            axis: app.wall.axis,
            seed: app.wall.seed,
            photoIDs: app.wall.tiles.map(\.photoID),
            canvasSize: app.wall.canvasSize
        )
        NotificationCenter.default.post(
            name: .loomFavoriteSavePayload,
            object: fav
        )
        Haptics.confirm()
    }

    private func apply(_ favorite: Favorite) {
        app.setStyle(favorite.style)
        app.setAxis(favorite.axis)
        let wall = Composer.reproduce(favorite, library: app.photos)
        withLoomAnimation(LoomMotion.weave) { app.wall = wall }
    }

    private func defaultFavoriteName(for wall: Wall) -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM d · HH:mm"
        return "\(wall.style.displayName) — \(df.string(from: Date()))"
    }

    // MARK: — Canvas

    private var canvas: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { canvasSize = effectiveCanvas(geo.size) }
                .onChange(of: geo.size) { _, new in
                    canvasSize = effectiveCanvas(new)
                }
                .overlay(WallCanvas(photos: app.photos))
                .padding(LoomSpacing.xl)
        }
    }

    private var emptyHint: some View {
        VStack(spacing: LoomSpacing.sm) {
            Text("Ready to weave")
                .font(LoomType.displayM)
                .foregroundStyle(Palette.ink)
                .displayTracking()
            Text("Press Shuffle — or hit Space.")
                .font(LoomType.body)
                .foregroundStyle(Palette.inkMuted)
        }
        .padding(.bottom, LoomSpacing.xxl)
    }

    private func effectiveCanvas(_ raw: CGSize) -> CGSize {
        // Subtract chrome padding so the wall actually fits without clipping.
        CGSize(
            width:  max(0, raw.width  - LoomSpacing.xl * 2),
            height: max(0, raw.height - LoomSpacing.xl * 2 - 120)  // chrome region
        )
    }

    // MARK: — Shuffle

    private func shuffleNow() {
        let size = canvasSize.width > 100
            ? canvasSize
            : CGSize(width: 1200, height: 700)  // fallback until GeometryReader paints

        let seedBase = UInt64(Date().timeIntervalSinceReferenceDate * 1000)
        var rng = SeededRNG(seed: seedBase ^ UInt64(app.style.hashValue & 0xFFFFFFFF))

        let wall = composer.weave(
            photos: app.photos,
            style: app.style,
            axis: app.axis,
            canvasSize: size,
            lockedPhotoIDs: app.lockedPhotoIDs,
            rng: &rng
        )
        withLoomAnimation(LoomMotion.weave) {
            app.wall = wall
        }
    }
}
