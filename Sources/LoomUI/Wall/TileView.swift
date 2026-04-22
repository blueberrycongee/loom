import SwiftUI
import AppKit
import LoomCore
import LoomDesign
import LoomIndex

/// One photo on the wall.
///
/// Loads its thumbnail from `ThumbnailCache.Size.tile` — a 1024px JPEG,
/// baked on-demand because tile thumbnails are heavier than grid ones and
/// most wall photos never get shown before the next Shuffle.
///
/// The dominant-color swatch underneath the image gives the wall its
/// immediate palette even before any thumbnails paint, which matters because
/// a wall is about gestalt first, detail second.
struct TileView: View {

    let tile: Tile
    let photo: Photo?
    let style: Style
    let isLocked: Bool
    let isInteracting: Bool
    let onToggleLock: (() -> Void)?
    let onResize: ((ResizeCorner, TileDragPhase) -> Void)?
    let onMove: ((TileDragPhase) -> Void)?

    private let thumbnails = ThumbnailCache()
    @State private var image: NSImage?
    @State private var hovered = false
    @State private var moving = false

    init(
        tile: Tile,
        photo: Photo?,
        style: Style = .tapestry,
        isLocked: Bool = false,
        isInteracting: Bool = false,
        onToggleLock: (() -> Void)? = nil,
        onResize: ((ResizeCorner, TileDragPhase) -> Void)? = nil,
        onMove: ((TileDragPhase) -> Void)? = nil
    ) {
        self.tile = tile
        self.photo = photo
        self.style = style
        self.isLocked = isLocked
        self.isInteracting = isInteracting
        self.onToggleLock = onToggleLock
        self.onResize = onResize
        self.onMove = onMove
    }

    /// True when the tile should render in an "active" state — mouse
    /// is over it, the user is dragging it, or ``WallCanvas`` told us
    /// this tile is the one currently being resized/moved (which can
    /// outlast a brief mouse-exit during the drag).
    private var active: Bool { hovered || moving || isInteracting }

    var body: some View {
        Group {
            if style == .vintage {
                polaroid
            } else {
                plainTile
            }
        }
        .overlay(
            // Brass hairline while a drag is in flight — signals "you've
            // grabbed this one". Soft enough to not compete with the
            // photo's own edge.
            RoundedRectangle(cornerRadius: LoomRadius.tile, style: .continuous)
                .strokeBorder(Palette.brass.opacity(moving || isInteracting ? 0.55 : 0),
                              lineWidth: 1.5)
                .allowsHitTesting(false)
                .animation(LoomMotion.snap, value: moving || isInteracting)
        )
        .overlay(alignment: .topTrailing) {
            LockBadge(isLocked: isLocked, hovered: active)
                .padding(8)
        }
        .overlay(cornerHandles)
        .animation(LoomMotion.snap, value: active && onResize != nil)
        .frame(width: tile.frame.width, height: tile.frame.height)
        .scaleEffect(moving ? 1.04 : (active ? 1.015 : 1.0))
        .rotationEffect(.radians(tile.rotation))
        .shadow(
            color: LoomShadow.tone.opacity(moving ? 0.32 : 0),
            radius: moving ? 18 : 0,
            x: 0,
            y: moving ? 10 : 0
        )
        .gesture(moveDragGesture)
        .onHover { hovered = $0 }
        .animation(LoomMotion.hover, value: hovered)
        .animation(LoomMotion.snap, value: moving)
        .onTapGesture(count: 2) { onToggleLock?() }
        .task(id: photo?.id) {
            await load()
        }
    }

    // MARK: — Corner handles

    @ViewBuilder
    private var cornerHandles: some View {
        if let onResize, active {
            ZStack {
                handle(.topLeft,     onResize: onResize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                handle(.topRight,    onResize: onResize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                handle(.bottomLeft,  onResize: onResize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                handle(.bottomRight, onResize: onResize)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            // Small inset so handles read as "at the corner" without
            // overhanging the tile's hit area — an overhang would flip
            // ``.onHover`` to false the moment the cursor left the tile
            // body, hiding the handle before the user could grab it.
            .padding(3)
            .transition(.opacity.combined(with: .scale(scale: 0.7)))
        }
    }

    private func handle(
        _ corner: ResizeCorner,
        onResize: @escaping (ResizeCorner, TileDragPhase) -> Void
    ) -> some View {
        ResizeHandle(corner: corner, onResize: onResize)
    }

    // MARK: — Move drag

    /// Click + drag anywhere on the tile body to reposition it. Resize
    /// handles sit on top and capture their own drags first, so this
    /// only fires for drags initiated on the photo itself.
    ///
    /// ``minimumDistance: 4`` keeps small clicks from being misread as
    /// moves, which preserves the double-tap lock gesture.
    private var moveDragGesture: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                guard let onMove else { return }
                if !moving {
                    moving = true
                    onMove(.began)
                }
                onMove(.changed(value.translation))
            }
            .onEnded { _ in
                guard let onMove, moving else { return }
                moving = false
                onMove(.ended)
            }
    }

    /// The default tile rendering: a photo clipped to a small rounded
    /// rectangle with a hairline border and a soft warm shadow.
    ///
    /// An earlier version feathered the edge (blurred mask bleed into the
    /// paper canvas) to read as "ink absorbed into the page" — but on
    /// real photos the feather read as *faded/white-edged photos*, which
    /// is not what anyone wants. Clean rounded corners read as "a
    /// photograph sitting on paper", which is the intended metaphor.
    private var plainTile: some View {
        ZStack {
            if let photo {
                dominantSwatch(for: photo)
            }

            if let image {
                croppedImage(Image(nsImage: image))
                    .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: LoomRadius.tile, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LoomRadius.tile, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
        .tileShadow()
    }

    /// Apply crop-insets by slightly over-scaling the image and
    /// offsetting so the border area falls outside the clip shape.
    /// The photo "zooms in" past the letterbox/border. When insets
    /// are zero the view is identical to a plain .fill.
    @ViewBuilder
    private func croppedImage(_ img: Image) -> some View {
        let insets = photo?.cropInsets ?? .zero
        if insets.isZero {
            img.resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            let scaleX = 1.0 / max(0.5, 1.0 - insets.left - insets.right)
            let scaleY = 1.0 / max(0.5, 1.0 - insets.top - insets.bottom)
            let scale = max(scaleX, scaleY)
            let dx = (insets.left - insets.right) * 0.5
            let dy = (insets.top - insets.bottom) * 0.5
            img.resizable()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(scale)
                .offset(
                    x: -dx * tile.frame.width,
                    y: -dy * tile.frame.height
                )
        }
    }

    /// Polaroid chrome: thick white border, extra-thick on the bottom for
    /// the signature space; paper-texture off-white rather than pure white.
    private var polaroid: some View {
        let paper = Color(red: 0.97, green: 0.95, blue: 0.90)
        let topMargin: CGFloat = 10
        let sideMargin: CGFloat = 10
        let bottomMargin: CGFloat = max(24, tile.frame.height * 0.18)
        return ZStack {
            paper
            VStack(spacing: 0) {
                ZStack {
                    if let photo {
                        dominantSwatch(for: photo)
                    }
                    if let image {
                        croppedImage(Image(nsImage: image))
                            .transition(.opacity)
                    }
                }
                .clipped()
                .padding(.top, topMargin)
                .padding(.horizontal, sideMargin)

                Spacer(minLength: 0)
            }
            .padding(.bottom, bottomMargin)
        }
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
        )
        .tileShadow()
    }

    private func dominantSwatch(for photo: Photo) -> some View {
        let rgb = labToSRGB(photo.dominantColor)
        return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }

    private func load() async {
        guard let photo else { return }
        image = nil
        let loaded = await Task.detached(priority: .userInitiated) {
            let url = ThumbnailCache().ensure(
                for: photo.id, source: photo.url, size: .tile
            )
            return url.flatMap { NSImage(contentsOf: $0) }
        }.value
        await MainActor.run {
            withLoomAnimation(LoomMotion.ease) { self.image = loaded }
        }
    }
}

/// A pin/lock indicator that sits in the tile's upper-right corner.
/// Visible when locked; fades in on hover when unlocked so users discover
/// the affordance.
private struct LockBadge: View {
    let isLocked: Bool
    let hovered: Bool

    var body: some View {
        ZStack {
            Circle().fill(Palette.surface.opacity(0.85))
                .background(.ultraThinMaterial, in: Circle())
            Image(systemName: isLocked ? "pin.fill" : "pin")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isLocked ? Palette.brass : Palette.inkMuted)
                .rotationEffect(.degrees(45))
        }
        .frame(width: 22, height: 22)
        .opacity(isLocked ? 1.0 : (hovered ? 0.75 : 0.0))
        .animation(LoomMotion.hover, value: hovered)
        .animation(LoomMotion.snap, value: isLocked)
        .allowsHitTesting(false)
    }
}
