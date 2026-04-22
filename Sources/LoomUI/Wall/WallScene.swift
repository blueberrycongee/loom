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
        // Two layers, not three stacked at .bottom: the canvas+hint live
        // in a centered ZStack (so the hint sits in the middle of the
        // wall area), and the chrome is an overlay pinned to the bottom.
        // Keeping them in the same .bottom-aligned ZStack was parking the
        // hint's baseline right where the chrome sat and clipping it
        // behind the capsule.
        ZStack {
            canvas
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            emptyHint
                .opacity(app.wall.isEmpty ? 1 : 0)
                .animation(LoomMotion.breathe, value: app.wall.isEmpty)
        }
        .overlay(alignment: .bottom) {
            WallChrome(shuffle: shuffleNow)
                .padding(.bottom, LoomSpacing.xl)
        }
        .overlay(alignment: .topLeading) {
            LibraryChip()
                .padding(LoomSpacing.md)
        }
        .overlay(alignment: .topTrailing) {
            SettingsChip()
                .padding(LoomSpacing.md)
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
                    let next = effectiveCanvas(new)
                    canvasSize = next
                    // Real-time reflow: every resize re-lays the wall on the
                    // new canvas using the current seed. The composition
                    // *adapts*, not just scales — portrait windows get
                    // cascade-vertical, wide ones get cascadeLeft/Right, etc.
                    reflowToCurrentCanvas()
                }
                .overlay(WallCanvas(photos: app.photos))
                .padding(LoomSpacing.xl)
        }
    }

    private func reflowToCurrentCanvas() {
        guard !app.wall.isEmpty else { return }
        let size = canvasSize.width > 100 ? canvasSize : CGSize(width: 1200, height: 700)
        let reflowed = Composer.reflow(
            app.wall,
            toCanvas: size,
            library: app.photos
        )
        // .snap (fast spring) rather than .weave — during a resize drag we
        // don't want the full staggered wave, we want tiles to glide to
        // their new frames. Wall.id is preserved by reflow() so the
        // per-tile .animation(_:, value: wall.id) watchers don't re-fire.
        withLoomAnimation(LoomMotion.snap) {
            app.wall = reflowed
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
        // Centered — no bottom padding (the chrome is its own overlay
        // pinned to the bottom, so we don't need to budget room for it
        // in the hint's own layout).
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
