import SwiftUI
import LoomCore
import LoomDesign

/// The "Loom is weaving the index" surface.
///
/// As photos are extracted, their dominant-color swatches appear on a live
/// mini-wall in the center of the screen. The user literally watches their
/// library being woven — no abstract percentages, just truth in motion.
///
/// Each new tile arrives with the Weave transition (scale-fade + stagger
/// delay) so the motion vocabulary matches the real Shuffle on the wall.
/// When a newly indexed photo would be the (N+1)ᵗʰ in a mini-wall of N
/// cells, the oldest cell slides out to make room — FIFO, no abrupt
/// relayouts.
public struct IndexingView: View {

    @Environment(AppModel.self) private var app
    let snapshot: IndexingSnapshot

    public init(snapshot: IndexingSnapshot) {
        self.snapshot = snapshot
    }

    public var body: some View {
        VStack(spacing: LoomSpacing.xl) {
            Spacer(minLength: LoomSpacing.xl)

            MiniWall(photos: app.recentlyIndexed)
                .frame(maxWidth: 720, maxHeight: 420)
                .padding(.horizontal, LoomSpacing.xl)

            VStack(spacing: LoomSpacing.sm) {
                ShuttleBar(progress: snapshot.fraction)
                    .frame(maxWidth: 360, maxHeight: 2)

                HStack(spacing: LoomSpacing.sm) {
                    messageText
                        .font(LoomType.body)
                        .foregroundStyle(Palette.inkMuted)
                    Text("· \(Int((snapshot.fraction * 100).rounded()))%")
                        .font(LoomType.monoSm)
                        .foregroundStyle(Palette.inkFaint)
                }
                .transition(.opacity)
            }

            Spacer()

            Text("Weaving the index")
                .font(LoomType.micro)
                .microTracking()
                .foregroundStyle(Palette.inkFaint)
                .padding(.bottom, LoomSpacing.lg)
        }
        .animation(LoomMotion.breathe, value: snapshot)
    }

    /// Built at render time via LocalizedStringKey interpolation, so
    /// an in-app language switch flips the progress copy immediately
    /// instead of requiring a fresh indexing run to re-bake the
    /// message String.
    @ViewBuilder
    private var messageText: some View {
        switch snapshot.stage {
        case .discovering:
            Text("Finding photos…")
        case .extracting:
            Text("Analysing \(snapshot.completed) of \(snapshot.total)…")
        case .thumbnailing:
            Text("Baking previews \(snapshot.completed) of \(snapshot.total)…")
        case .done:
            Text("\(snapshot.completed) photos ready.")
        case .failed(let why):
            Text("Indexing failed: \(why)")
        }
    }
}

// MARK: — Mini-wall

/// A tight grid of dominant-color swatches, one per recently-indexed photo.
/// Grid is 12 columns × N rows; newest tiles appear bottom-right, FIFO'd
/// off the top-left as the buffer fills.
private struct MiniWall: View {

    let photos: [Photo]
    private let columns = 12

    var body: some View {
        GeometryReader { geo in
            let gutter: CGFloat = 4
            let gridWidth = geo.size.width
            let cellW = (gridWidth - gutter * CGFloat(columns - 1)) / CGFloat(columns)
            let cellH = cellW  // square — keeps the grid readable at any count
            let rows = max(1, Int(ceil(Double(photos.count) / Double(columns))))
            let totalH = CGFloat(rows) * cellH + CGFloat(rows - 1) * gutter
            let startY = (geo.size.height - totalH) / 2

            ZStack(alignment: .topLeading) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { (i, photo) in
                    let r = i / columns
                    let c = i % columns
                    let x = CGFloat(c) * (cellW + gutter)
                    let y = startY + CGFloat(r) * (cellH + gutter)
                    let delay = Weave.stagger(
                        normalizedPosition: Double(i) / Double(max(1, photos.count)),
                        index: i,
                        span: 0.7
                    )
                    // Per-tile jitter rotation so the wave reads as
                    // organic, not mechanical. Deterministic on index.
                    let jitterAngle = Weave.tileJitterAngle(index: i)

                    Swatch(color: sRGB(for: photo.dominantColor))
                        .frame(width: cellW, height: cellH)
                        .position(x: x + cellW / 2, y: y + cellH / 2)
                        .transition(Self.swatchTransition(delay: delay, angle: jitterAngle))
                }
            }
            .animation(Self.swatchSettleAnimation, value: photos.count)
        }
    }

    // MARK: — Transition

    /// Richer entrance than the wall tiles: swatches tumble in from a
    /// small scale + rotation with a perceptible bounce. The stagger
    /// span (0.7s) + settle spring (0.65 response) gives the full
    /// wave ~1.4s of visual motion — enough to feel cinematic on
    /// every library open.
    private static func swatchTransition(
        delay: Double,
        angle: Double
    ) -> AnyTransition {
        .asymmetric(
            insertion: AnyTransition
                .scale(scale: 0.55)
                .combined(with: .opacity)
                .combined(with: .modifier(
                    active: SwatchRotation(angle: angle),
                    identity: SwatchRotation(angle: 0)
                ))
                .animation(
                    .spring(response: 0.65, dampingFraction: 0.72, blendDuration: 0.2)
                    .delay(delay)
                ),
            removal: AnyTransition
                .scale(scale: 1.08)
                .combined(with: .opacity)
                .animation(.easeOut(duration: 0.18))
        )
    }

    /// Settle animation for the whole grid — slightly bouncier than
    /// the wall's Weave settle so the MiniWall feels playful.
    private static let swatchSettleAnimation: Animation =
        .spring(response: 0.65, dampingFraction: 0.72, blendDuration: 0.2)

    private func sRGB(for lab: LabColor) -> Color {
        let rgb = labToSRGB(lab)
        return Color(red: rgb.r, green: rgb.g, blue: rgb.b)
    }
}

/// Rotation modifier used by the swatch insert transition.
private struct SwatchRotation: ViewModifier {
    let angle: Double
    func body(content: Content) -> some View {
        content.rotationEffect(.degrees(angle))
    }
}

/// A single dominant-color swatch — rounded rectangle with a subtle inner
/// ring so it reads as a "photo placeholder" not a primitive fill.
private struct Swatch: View {
    let color: Color
    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .overlay(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)
    }
}

// MARK: — Shuttle bar (unchanged from the previous minimal design, but
// de-duplicated here so IndexingView is self-contained)

private struct ShuttleBar: View {

    let progress: Double
    @State private var shuttle: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.hairline)
                Capsule()
                    .fill(Palette.brass.opacity(0.6))
                    .frame(width: geo.size.width * CGFloat(progress))
                Capsule()
                    .fill(Palette.brassLift)
                    .frame(width: 40, height: geo.size.height)
                    .offset(x: shuttle * (geo.size.width - 40))
                    .blendMode(.plusLighter)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    shuttle = 1
                }
            }
        }
    }
}
