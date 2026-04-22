import AVFoundation
import Foundation
import Vision
import LoomCore

/// The live hand-tracking capture layer.
///
/// Owns an ``AVCaptureSession`` tied to the front camera, runs
/// ``VNDetectHumanHandPoseRequest`` on ~15 frames per second, derives a
/// smoothed openness scalar + palm velocity, and publishes
/// ``HandEvent``s through a single ``AsyncStream``.
///
/// Thread model:
///   • Public API (`events()`, `stop()`) is called from the main actor.
///   • All per-frame processing happens on a dedicated capture queue
///     (`loom.handsense.capture`) — the same queue we hand to
///     ``AVCaptureVideoDataOutput`` as its delegate queue, so frames and
///     state mutations are serialized by construction.
///   • ``AsyncStream.Continuation`` is thread-safe; `yield` can be called
///     from the capture queue directly.
///
/// Every threshold, alpha, or cooldown in here reads from
/// ``HandSenseTuning`` — tune the whole feature from that one enum.
final class HandSense: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {

    // MARK: — Queue + session

    private let queue = DispatchQueue(label: "loom.handsense.capture", qos: .userInitiated)
    private var session: AVCaptureSession?

    // Continuation is set once from `events()` (main actor), then only
    // read from the capture queue via `yield`. AsyncStream.Continuation
    // is thread-safe for yields.
    nonisolated(unsafe) private var continuation: AsyncStream<HandEvent>.Continuation?
    nonisolated(unsafe) private var hasStarted = false

    // MARK: — Processing state (owned by `queue`)

    private var smoothedOpenness: Double = 0.5
    private var lastEmittedOpenness: Double = 0.5
    private var lastPalmX: Double = 0.5
    private var lastFrameTime: Date = .distantPast
    private var lastSwipeTime: Date = .distantPast
    private var lastConfidentFrameTime: Date = .distantPast
    private var handIsLost: Bool = true
    private var lastProcessTime: Date = .distantPast

    private let targetFPS: Double = 15.0

    /// Reused per frame — creating a fresh VNRequest every frame wastes
    /// millions of allocations over a session.
    private let handRequest: VNDetectHumanHandPoseRequest = {
        let r = VNDetectHumanHandPoseRequest()
        r.maximumHandCount = 1
        return r
    }()

    // MARK: — Public API

    func events() -> AsyncStream<HandEvent> {
        precondition(!hasStarted, "HandSense.events() called twice")
        hasStarted = true

        return AsyncStream { cont in
            self.continuation = cont
            cont.onTermination = { [weak self] _ in
                self?.stop()
            }
            self.queue.async {
                self.setupSession()
            }
        }
    }

    func stop() {
        queue.async {
            self.session?.stopRunning()
            self.session = nil
        }
    }

    // MARK: — Session setup

    private func setupSession() {
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        // Prefer the front camera for a self-facing mirror — the user
        // moves their hand and sees it match on screen.
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video)
        guard
            let device,
            let input = try? AVCaptureDeviceInput(device: device)
        else {
            continuation?.yield(.failed("No camera available"))
            return
        }
        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }

        session.commitConfiguration()
        session.startRunning()
        self.session = session
    }

    // MARK: — Per-frame processing

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = Date()
        // Throttle to targetFPS. Vision hand pose is heavy; saves ~60%
        // CPU vs processing every frame, with no perceptible gesture lag.
        guard now.timeIntervalSince(lastProcessTime) >= (1.0 / targetFPS) else {
            return
        }
        lastProcessTime = now

        // Front-camera orientation: ".leftMirrored" flips the image so
        // "right in Vision's frame" corresponds to the user's right hand
        // moving right. Swipe velocity reads naturally.
        let handler = VNImageRequestHandler(
            cmSampleBuffer: sampleBuffer,
            orientation: .leftMirrored,
            options: [:]
        )
        do {
            try handler.perform([handRequest])
        } catch {
            return
        }

        guard let observation = handRequest.results?.first else {
            handleMissingHand(now: now)
            return
        }
        processHand(observation, now: now)
    }

    private func processHand(_ obs: VNHumanHandPoseObservation, now: Date) {
        guard
            let wrist = try? obs.recognizedPoint(.wrist),
            Double(wrist.confidence) > HandSenseTuning.jointConfidenceFloor
        else {
            handleMissingHand(now: now)
            return
        }

        let tipJoints: [VNHumanHandPoseObservation.JointName] = [
            .thumbTip, .indexTip, .middleTip, .ringTip, .littleTip
        ]
        var tipPoints: [CGPoint] = []
        var confidenceSum: Double = Double(wrist.confidence)
        for key in tipJoints {
            guard
                let point = try? obs.recognizedPoint(key),
                Double(point.confidence) > HandSenseTuning.jointConfidenceFloor
            else { continue }
            tipPoints.append(point.location)
            confidenceSum += Double(point.confidence)
        }
        guard tipPoints.count >= 3 else {
            handleMissingHand(now: now)
            return
        }

        // Openness = average fingertip-to-wrist distance, mapped through
        // the calibration range to [0, 1].
        let wristLoc = wrist.location
        let avgSpan = tipPoints
            .map { hypot(Double($0.x - wristLoc.x), Double($0.y - wristLoc.y)) }
            .reduce(0, +) / Double(tipPoints.count)
        let range = HandSenseTuning.maxFingerSpan - HandSenseTuning.minFingerSpan
        let rawOpenness = max(0, min(1, (avgSpan - HandSenseTuning.minFingerSpan) / range))

        // Exponential smoothing — absorbs hand jitter.
        let alpha = HandSenseTuning.opennessSmoothingAlpha
        smoothedOpenness = alpha * rawOpenness + (1 - alpha) * smoothedOpenness

        let avgConfidence = confidenceSum / Double(tipPoints.count + 1)

        // Palm velocity for swipe detection.
        let palmX = Double(wristLoc.x)
        let palmY = Double(wristLoc.y)
        let dt = max(0.001, now.timeIntervalSince(lastFrameTime))
        let vx = (palmX - lastPalmX) / dt
        lastPalmX = palmX
        lastFrameTime = now
        lastConfidentFrameTime = now
        handIsLost = false

        // Emit update only when the smoothed value left the deadzone —
        // cheap backpressure, plus it keeps the view tree from
        // re-rendering on every micro-breath.
        if abs(smoothedOpenness - lastEmittedOpenness) >= HandSenseTuning.opennessDeadzone {
            lastEmittedOpenness = smoothedOpenness
            continuation?.yield(.update(
                HandObservation(
                    openness: smoothedOpenness,
                    palm: CGPoint(x: palmX, y: palmY),
                    confidence: avgConfidence,
                    timestamp: now
                )
            ))
        }

        // Swipe detection — gated by both a velocity threshold and a
        // cooldown so one fast flick emits exactly one event, not a
        // stream-of-events over the frames the hand is still moving.
        if abs(vx) >= HandSenseTuning.swipeVelocityThreshold,
           now.timeIntervalSince(lastSwipeTime) >= HandSenseTuning.swipeCooldown {
            lastSwipeTime = now
            continuation?.yield(.gesture(vx > 0 ? .swipeRight : .swipeLeft))
        }
    }

    /// No confident hand this frame. Emit `.lost` once after a grace
    /// window so a single dropped frame doesn't toggle state — hand
    /// pose is flaky at edge-of-frame positions.
    private func handleMissingHand(now: Date) {
        guard !handIsLost else { return }
        if now.timeIntervalSince(lastConfidentFrameTime) >= HandSenseTuning.lostAfter {
            handIsLost = true
            continuation?.yield(.lost)
        }
    }
}
