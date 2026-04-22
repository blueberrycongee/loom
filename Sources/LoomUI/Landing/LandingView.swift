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
/// Aesthetics: oversized rounded wordmark, drifting warm threads behind it,
/// and a single primary button. No tutorials, no marketing copy, no fine
/// print.
public struct LandingView: View {

    @Environment(AppModel.self) private var app

    public init() {}

    public var body: some View {
        content
    }

    private var content: some View {
        VStack(spacing: 0) {
            // Push content to the visual sweet-spot (~40 % from top).
            Spacer()
            Spacer()

            VStack(spacing: LoomSpacing.xl) {
                WordmarkLoom()
                    .foregroundStyle(Palette.ink)

                VStack(spacing: LoomSpacing.lg) {
                    Text("Weave your photos into a wall.")
                        .font(LoomType.body)
                        .foregroundStyle(Palette.inkMuted)

                    // Tiny brass dot — a quiet punctuation between promise
                    // and action.
                    Capsule()
                        .fill(Palette.brass.opacity(0.35))
                        .frame(width: 3, height: 3)

                    VStack(spacing: LoomSpacing.lg) {
                        PickLibraryButton {
                            NotificationCenter.default.post(name: .loomPickLibrary, object: nil)
                        }

                        PhotosLibraryButton()
                    }
                }
            }

            Spacer()
            Spacer()
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

// MARK: — Wordmark

/// The wordmark. Rounded SF Pro display weight, with a single faintly
/// animated underline thread that traces across the width every ~9 s — a
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
                        period: 9
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
            let segmentW = w * 0.28
            let travel = (w + segmentW) * phase - segmentW
            Capsule()
                .fill(Palette.brass.opacity(0.40))
                .frame(width: segmentW, height: 1.5)
                .offset(x: travel)
        }
    }
}

// MARK: — Buttons

/// Secondary CTA that links the Photos library (M7, skeleton).
///
/// Rendered as a plain text button so the primary CTA dominates visually.
/// Hover brightens the ink to invite interaction without adding visual
/// weight.
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
            .foregroundStyle(hovered ? Palette.inkMuted : Palette.inkFaint)
            .padding(.horizontal, LoomSpacing.sm)
            .padding(.vertical, LoomSpacing.xs)
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
            .scaleEffect(hovering ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .brassShadow()
        .onHover { hovering = $0 }
        .animation(LoomMotion.hover, value: hovering)
        .keyboardShortcut("o", modifiers: .command)
    }
}
