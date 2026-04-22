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

            if let prompt = app.permissionPrompt {
                PermissionScrim(prompt: prompt)
                    .transition(.opacity)
            }
        }
        .animation(LoomMotion.breathe, value: phaseKey)
        .animation(LoomMotion.breathe, value: app.permissionPrompt)
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

/// A dimmed scrim backdrop + centered ``PermissionSheet``. Tapping outside
/// the sheet dismisses; the sheet's own buttons drive the affirmative
/// responses. Posts ``.loomPermissionAllow`` when the user accepts so the
/// coordinator can follow up (trigger the system dialog / re-attempt the
/// library open).
private struct PermissionScrim: View {
    let prompt: PermissionPrompt
    @Environment(AppModel.self) private var app

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { app.dismissPermissionPrompt() }

            PermissionSheet(
                prompt: prompt,
                onAllow: {
                    NotificationCenter.default.post(
                        name: .loomPermissionAllow, object: prompt
                    )
                    app.dismissPermissionPrompt()
                },
                onDismiss: {
                    app.dismissPermissionPrompt()
                }
            )
            .transition(.scale(scale: 0.96).combined(with: .opacity))
        }
    }
}
