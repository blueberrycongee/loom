import SwiftUI

/// Loom's motion tokens.
///
/// Three curves cover 95% of cases:
///   • ``snap`` — fast, crisp, high-damping. Button presses, focus rings.
///   • ``breathe`` — medium spring with just-detectable bounce. Panels,
///     sheets, state transitions.
///   • ``weave`` — the signature curve for Shuffle. Slower, with a satisfying
///     arc: photos land on their new spots like a loom shuttle completing a
///     pass.
///
/// Always animate with a token; never with an inline `.easeInOut`. That way
/// we can retune the entire app's feel from one place.
public enum LoomMotion {

    public static let snap:    Animation = .spring(response: 0.24, dampingFraction: 0.92, blendDuration: 0.12)
    public static let breathe: Animation = .spring(response: 0.38, dampingFraction: 0.82, blendDuration: 0.18)
    public static let weave:   Animation = .spring(response: 0.58, dampingFraction: 0.78, blendDuration: 0.22)

    /// For entrances / exits where a spring overshoots awkwardly.
    public static let ease:    Animation = .easeInOut(duration: 0.22)

    /// Use for hover / pointer-over highlights — barely-there, 60fps-friendly.
    public static let hover:   Animation = .easeOut(duration: 0.12)

    /// Stagger children of a parent animation by this many seconds × index.
    public static let stagger: Double = 0.024
}

/// Convenience: `withLoomAnimation(.weave) { state.shuffle() }`.
public func withLoomAnimation<Result>(
    _ animation: Animation = LoomMotion.breathe,
    _ body: () throws -> Result
) rethrows -> Result {
    try withAnimation(animation, body)
}
