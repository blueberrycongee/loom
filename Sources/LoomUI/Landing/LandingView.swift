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

    public init() {}

    public var body: some View {
        ZStack {
            // Ambient procedural tapestry — teaches the product metaphor
            // without needing a library to demo against.
            LoomTapestry()

            // Soft radial vignette so the wordmark has air around it.
            RadialGradient(
                colors: [Color.clear, Palette.canvas.opacity(0.55)],
                center: .center,
                startRadius: 160,
                endRadius: 540
            )
            .allowsHitTesting(false)

            VStack(spacing: LoomSpacing.xl) {
                Spacer()

                VStack(spacing: LoomSpacing.sm) {
                    WordmarkLoom()
                        .foregroundStyle(Palette.ink)

                    Text("Weave your photos into a wall.")
                        .font(LoomType.body)
                        .foregroundStyle(Palette.inkMuted)
                }

                VStack(spacing: LoomSpacing.md) {
                    PickLibraryButton {
                        NotificationCenter.default.post(name: .loomPickLibrary, object: nil)
                    }

                    PhotosLibraryButton()
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
    }
}

/// The wordmark. Rounded SF Pro display weight, with a single faintly
/// animated underline thread that traces across the width every ~7s — a
/// quiet tie-in to the weaving metaphor without being kinetic about it.
private struct WordmarkLoom: View {

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 4) {
            Text("Loom")
                .font(LoomType.displayXL)
                .displayTracking()

            TimelineView(.animation(minimumInterval: reduceMotion ? nil : 1.0 / 30.0)) { timeline in
                let phase = reduceMotion
                    ? 0.5
                    : Weave.driftPhase(
                        time: timeline.date.timeIntervalSinceReferenceDate,
                        index: 0,
                        period: 7
                    )
                underline(phase: phase)
            }
            .frame(height: 2)
        }
    }

    private func underline(phase: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            // A short brass segment travels left → right and loops.
            let segmentW = w * 0.32
            let travel = (w + segmentW) * phase - segmentW
            Capsule()
                .fill(Palette.brass.opacity(0.55))
                .frame(width: segmentW, height: 2)
                .offset(x: travel)
        }
    }
}

/// Secondary CTA that links the Photos library (M7, skeleton).
///
/// Presented as a subdued text button under the primary folder CTA so the
/// first-use flow still points at the lower-friction, already-wired-up
/// folder path. Full indexer integration for Photos-sourced assets lands
/// after the folder path has field time.
private struct PhotosLibraryButton: View {
    @State private var hovered = false

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .loomPickPhotosLibrary, object: nil)
        } label: {
            HStack(spacing: LoomSpacing.xs) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 11, weight: .medium))
                Text("Use Photos library")
                    .font(LoomType.caption)
            }
            .foregroundStyle(Palette.inkMuted)
            .padding(.horizontal, LoomSpacing.md)
            .padding(.vertical, LoomSpacing.sm)
            .background(Capsule().fill(Palette.surface.opacity(0.5)))
            .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
            .opacity(hovered ? 1.0 : 0.8)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(LoomMotion.hover, value: hovered)
        .help("Index the Apple Photos library instead of a folder.")
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
