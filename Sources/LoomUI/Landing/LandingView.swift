import SwiftUI
import LoomCore
import LoomDesign

/// The empty-wall hero.
///
/// This is the first surface the user meets. Three jobs:
///   1. State the product in one sentence.
///   2. Offer a single, obvious action: pick a library.
///   3. Feel *finished* — not a "Getting started" checklist.
///
/// Aesthetics: oversized rounded wordmark, a slow brass shimmer behind it,
/// and a single primary button. No tutorials, no marketing copy, no fine
/// print.
public struct LandingView: View {

    @Environment(AppModel.self) private var app
    @State private var shimmer: Double = 0

    public init() {}

    public var body: some View {
        ZStack {
            BrassShimmer(phase: shimmer)
                .allowsHitTesting(false)

            VStack(spacing: LoomSpacing.xl) {
                Spacer()

                VStack(spacing: LoomSpacing.sm) {
                    Text("Loom")
                        .font(LoomType.displayXL)
                        .displayTracking()
                        .foregroundStyle(Palette.ink)

                    Text("Weave your photos into a wall.")
                        .font(LoomType.body)
                        .foregroundStyle(Palette.inkMuted)
                }

                PickLibraryButton {
                    NotificationCenter.default.post(name: .loomPickLibrary, object: nil)
                }

                Spacer()

                Text("Local · offline · private")
                    .font(LoomType.micro)
                    .microTracking()
                    .foregroundStyle(Palette.inkFaint)
                    .padding(.bottom, LoomSpacing.lg)
            }
            .padding(LoomSpacing.xl)
        }
        .onAppear {
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                shimmer = 1
            }
        }
    }
}

/// A slow, almost-invisible diagonal brass wash. Takes ~18s to cross the
/// window, which is long enough that the eye registers movement only when
/// glancing away.
private struct BrassShimmer: View {
    var phase: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let maxDim = max(w, h)
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.00),
                    .init(color: Palette.brass.opacity(0.08), location: 0.48),
                    .init(color: Palette.brassLift.opacity(0.12), location: 0.50),
                    .init(color: Palette.brass.opacity(0.08), location: 0.52),
                    .init(color: .clear, location: 1.00)
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(width: maxDim * 2, height: maxDim * 2)
            .offset(
                x: -maxDim + (maxDim * 2 * CGFloat(phase)),
                y: -maxDim + (maxDim * 2 * CGFloat(phase))
            )
            .blendMode(.plusLighter)
        }
    }
}

private struct PickLibraryButton: View {
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: LoomSpacing.sm) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("Choose a photo folder")
                    .font(LoomType.heading)
            }
            .foregroundStyle(Palette.canvas)
            .padding(.horizontal, LoomSpacing.lg)
            .padding(.vertical, LoomSpacing.md)
            .background(
                Capsule().fill(Palette.brassFill)
            )
            .overlay(
                Capsule().strokeBorder(Palette.brassLift.opacity(0.6), lineWidth: 0.5)
            )
            .scaleEffect(hovering ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .brassShadow()
        .onHover { hovering = $0 }
        .animation(LoomMotion.hover, value: hovering)
        .keyboardShortcut("o", modifiers: .command)
    }
}
