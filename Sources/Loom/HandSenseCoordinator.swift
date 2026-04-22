import AVFoundation
import Foundation
import LoomCore

/// Bridges ``HandSense`` events to ``AppModel`` on the main actor.
///
/// Responsibilities:
///   • **Lifecycle** — start capturing when the user enables hand sense
///     (and camera permission is authorized), stop on disable.
///   • **Permission** — check status; pre-explain via ``PermissionSheet``
///     before triggering the TCC camera dialog on first enablement.
///   • **Events** — route `.update` into `app.wallOpenness`, `.gesture`
///     into a NotificationCenter post that triggers shuffle, `.lost`
///     into an ease-back-to-neutral, `.failed` into disabling the
///     feature with a user-visible sheet.
///
/// On app launch, if the user's persisted preference is "enabled" and
/// camera permission is already authorized, capture auto-starts — they
/// don't need to re-flip the Settings switch every session.
@MainActor
final class HandSenseCoordinator {

    private let app: AppModel
    private var capture: HandSense?
    private var eventTask: Task<Void, Never>?

    init(app: AppModel) {
        self.app = app
        registerNotifications()
    }

    // MARK: — Bootstrap

    /// Called once at app launch from ``LoomApp``. Auto-resumes capture
    /// if the persisted preference is on and camera is authorized.
    /// Never triggers a TCC dialog at launch — that's a cold-prompt
    /// which Apple HIG warns against.
    func bootstrap() {
        guard app.handSenseEnabled else { return }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startCapture()
        case .notDetermined, .denied, .restricted:
            // Preference says on but permission is missing — silently
            // flip the preference off. The Settings toggle stays
            // available; the user can re-enable, which re-prompts.
            app.setHandSenseEnabled(false)
        @unknown default:
            app.setHandSenseEnabled(false)
        }
    }

    // MARK: — Notifications

    private func registerNotifications() {
        let center = NotificationCenter.default
        center.addObserver(
            forName: .loomHandSenseToggle,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let enabled = note.object as? Bool else { return }
            Task { @MainActor in self?.handleToggle(enabled: enabled) }
        }
        // Camera permission sheet's "Allow" → trigger TCC.
        center.addObserver(
            forName: .loomPermissionAllow,
            object: nil, queue: .main
        ) { [weak self] note in
            guard
                let prompt = note.object as? PermissionPrompt,
                prompt == .cameraExplainer
            else { return }
            Task { @MainActor in self?.requestCameraThenStart() }
        }
    }

    // MARK: — Toggle flow

    private func handleToggle(enabled: Bool) {
        if enabled {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                app.setHandSenseEnabled(true)
                startCapture()
            case .notDetermined:
                // Keep preference off for now; show in-app explainer.
                // The sheet's Allow button runs requestCameraThenStart
                // which flips the preference + starts capture on grant.
                app.present(.cameraExplainer)
            case .denied, .restricted:
                app.present(.cameraDenied)
            @unknown default:
                app.present(.cameraDenied)
            }
        } else {
            app.setHandSenseEnabled(false)
            stopCapture()
        }
    }

    private func requestCameraThenStart() {
        Task {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run {
                if granted {
                    self.app.setHandSenseEnabled(true)
                    self.startCapture()
                } else {
                    self.app.present(.cameraDenied)
                }
            }
        }
    }

    // MARK: — Capture

    private func startCapture() {
        guard capture == nil else { return }
        let sense = HandSense()
        capture = sense
        let stream = sense.events()
        eventTask = Task { [weak self] in
            for await event in stream {
                await self?.handle(event)
            }
        }
    }

    private func stopCapture() {
        eventTask?.cancel()
        eventTask = nil
        capture?.stop()
        capture = nil
        // Ease the wall back to neutral so the UI doesn't freeze
        // whatever openness the last gesture produced.
        app.setOpenness(0.5)
    }

    // MARK: — Event → AppModel

    private func handle(_ event: HandEvent) async {
        switch event {
        case .update(let obs):
            app.setOpenness(obs.openness)
        case .gesture(.shake):
            NotificationCenter.default.post(name: .loomShuffle, object: nil)
        case .lost:
            // Ease back to neutral so the wall breathes out while the
            // hand is out of frame.
            app.setOpenness(0.5)
        case .failed(let msg):
            #if DEBUG
            print("HandSense failed: \(msg)")
            #endif
            stopCapture()
            app.setHandSenseEnabled(false)
        }
    }
}

public extension Notification.Name {
    /// Fired by the Settings toggle; coordinator picks it up and runs
    /// the permission + start-capture flow. Object is a Bool.
    static let loomHandSenseToggle = Notification.Name("loom.handSenseToggle")
}
