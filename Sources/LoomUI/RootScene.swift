import SwiftUI
import LoomCore
import LoomDesign

/// The top-level scene content. Switches between landing / indexing / ready
/// with a shared cross-fade, keeps the grain overlay constant across phases
/// so the warmth is continuous, and hosts the toolbar chrome.
public struct RootScene: View {

    @Environment(AppModel.self) private var app

    public init() {}

    public var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()
            Palette.canvasVignette.ignoresSafeArea().allowsHitTesting(false)

            content
                .transition(.opacity.combined(with: .scale(scale: 0.992)))

            NoiseTexture(baseOpacity: 0.032)
                .ignoresSafeArea()
        }
        .animation(LoomMotion.breathe, value: phaseKey)
    }

    private var phaseKey: String {
        switch app.phase {
        case .landing:  return "landing"
        case .indexing: return "indexing"
        case .ready:    return "ready"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch app.phase {
        case .landing:
            LandingView()
        case .indexing(let progress, let message):
            IndexingView(progress: progress, message: message)
        case .ready:
            WallScene()
        }
    }
}
