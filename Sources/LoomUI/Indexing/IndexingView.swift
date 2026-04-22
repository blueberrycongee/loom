import SwiftUI
import LoomDesign

/// Indexing progress chrome — a quiet screen. No big bar, no percentage in
/// giant numbers. A soft shuttle moves left-to-right, the count climbs, and a
/// single line of micro-copy tells you what's happening.
public struct IndexingView: View {

    let progress: Double   // 0 ... 1
    let message: String

    public init(progress: Double, message: String) {
        self.progress = progress
        self.message = message
    }

    public var body: some View {
        VStack(spacing: LoomSpacing.lg) {
            Spacer()

            VStack(spacing: LoomSpacing.md) {
                ShuttleBar(progress: progress)
                    .frame(maxWidth: 380, maxHeight: 2)

                Text(message)
                    .font(LoomType.body)
                    .foregroundStyle(Palette.inkMuted)
                    .transition(.opacity)

                Text("\(Int((progress * 100).rounded()))%")
                    .font(LoomType.monoSm)
                    .foregroundStyle(Palette.inkFaint)
            }

            Spacer()

            Text("Weaving the index")
                .font(LoomType.micro)
                .microTracking()
                .foregroundStyle(Palette.inkFaint)
                .padding(.bottom, LoomSpacing.lg)
        }
        .padding(LoomSpacing.xl)
        .animation(LoomMotion.breathe, value: message)
    }
}

/// The shuttle bar: a brass sliver travels inside a neutral track; when the
/// actual progress passes the sliver, it catches up. Feels like a physical
/// shuttle weaving back and forth.
private struct ShuttleBar: View {

    let progress: Double
    @State private var shuttle: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.hairline)

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
