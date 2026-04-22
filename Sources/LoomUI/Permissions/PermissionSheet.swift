import SwiftUI
import AppKit
import LoomCore
import LoomDesign

/// A dark-surface sheet that explains a permission request in Loom's voice
/// before the system's TCC dialog arrives.
///
/// Apple's HIG recommends prefacing a privacy-sensitive system prompt with
/// an in-app explanation: users see the *why* in your app's voice, then
/// the one-shot system dialog has context. If the user declines our
/// in-app preamble we never trigger the system prompt — they can return
/// later.
///
/// For the denied case, the system prompt won't reappear by design, so
/// we open System Settings → Privacy & Security → Photos via the modern
/// URL scheme (`x-apple.systempreferences:com.apple.preference.security?Privacy_Photos`).
/// The modal turns into a banner-style "go here to grant" rather than
/// pretending the Allow button still works.
public struct PermissionSheet: View {

    public let prompt: PermissionPrompt
    public let onAllow: @MainActor () -> Void
    public let onDismiss: @MainActor () -> Void

    @Environment(\.openURL) private var openURL

    public init(
        prompt: PermissionPrompt,
        onAllow: @escaping @MainActor () -> Void,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.prompt = prompt
        self.onAllow = onAllow
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: LoomSpacing.lg) {
            header
            body(for: prompt)
            actions(for: prompt)
        }
        .padding(LoomSpacing.xl)
        .frame(width: 460)
        .background(Palette.surface)
        .overlay(
            RoundedRectangle(cornerRadius: LoomRadius.sheet, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: LoomRadius.sheet, style: .continuous))
        .surfaceShadow()
    }

    // MARK: — Header

    private var header: some View {
        HStack(spacing: LoomSpacing.md) {
            ZStack {
                Circle()
                    .fill(Palette.brassFill)
                    .frame(width: 56, height: 56)
                Image(systemName: icon(for: prompt))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Palette.canvas)
            }
            .brassShadow()

            VStack(alignment: .leading, spacing: 2) {
                // Title / subtitle are LocalizedStringKey so they flip with
                // the SwiftUI environment locale on an in-app language
                // change — String(localized:) baked the call-time locale
                // and would have stayed stale here.
                Text(title(for: prompt))
                    .font(LoomType.displayS)
                    .foregroundStyle(Palette.ink)
                Text(subtitle(for: prompt))
                    .font(LoomType.caption)
                    .foregroundStyle(Palette.inkFaint)
            }
        }
    }

    @ViewBuilder
    private func body(for prompt: PermissionPrompt) -> some View {
        switch prompt {
        case .photosExplainer:
            Text("Loom reads your photos locally to compose aesthetic walls — analysing each one for color and visual similarity so every Shuffle produces a wall that belongs together.")
                .font(LoomType.body)
                .foregroundStyle(Palette.inkMuted)
                .lineSpacing(4)

            PrivacyBullets(items: [
                ("bolt.slash.fill",   "Nothing uploads."),
                ("internaldrive",     "Index lives on this Mac."),
                ("xmark.bin",         "One-click wipe in Settings.")
            ])

        case .photosDenied:
            Text("You previously declined Photos access. macOS won't show the permission dialog again — to index your Photos library you'll need to grant access manually in System Settings.")
                .font(LoomType.body)
                .foregroundStyle(Palette.inkMuted)
                .lineSpacing(4)

        case .photosRestricted:
            Text("Photos access is restricted on this Mac, typically by an MDM profile or parental controls. Folder mode will still let you weave walls from photos anywhere on disk.")
                .font(LoomType.body)
                .foregroundStyle(Palette.inkMuted)
                .lineSpacing(4)

        case .cameraExplainer:
            Text("Hand gestures need camera access. Loom reads your palm in real time — open your hand to spread the wall, make a fist to gather it, shake to shuffle. Video is processed frame by frame in memory and never recorded.")
                .font(LoomType.body)
                .foregroundStyle(Palette.inkMuted)
                .lineSpacing(4)

            PrivacyBullets(items: [
                ("bolt.slash.fill",  "Nothing recorded."),
                ("bolt.horizontal", "Nothing uploads."),
                ("switch.2",         "Turn off any time in Settings.")
            ])

        case .cameraDenied:
            Text("You previously declined camera access. macOS won't show the permission dialog again — to use hand gestures you'll need to grant access manually in System Settings.")
                .font(LoomType.body)
                .foregroundStyle(Palette.inkMuted)
                .lineSpacing(4)
        }
    }

    // MARK: — Actions

    @ViewBuilder
    private func actions(for prompt: PermissionPrompt) -> some View {
        HStack(spacing: LoomSpacing.sm) {
            Button("Not now", action: onDismiss)
                .buttonStyle(.plain)
                .font(LoomType.body)
                .foregroundStyle(Palette.inkMuted)
                .padding(.horizontal, LoomSpacing.md)
                .padding(.vertical, LoomSpacing.sm)

            Spacer()

            switch prompt {
            case .photosExplainer:
                PrimaryCapsule(title: "Allow Access", systemImage: "checkmark.seal.fill") {
                    onAllow()
                }
            case .photosDenied:
                PrimaryCapsule(title: "Open System Settings", systemImage: "arrow.up.right.square") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
                        openURL(url)
                    }
                    onDismiss()
                }
            case .photosRestricted:
                PrimaryCapsule(title: "Use a folder instead", systemImage: "folder.badge.plus") {
                    onAllow()   // caller treats as "route to folder picker"
                }
            case .cameraExplainer:
                PrimaryCapsule(title: "Allow Access", systemImage: "checkmark.seal.fill") {
                    onAllow()
                }
            case .cameraDenied:
                PrimaryCapsule(title: "Open System Settings", systemImage: "arrow.up.right.square") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                        openURL(url)
                    }
                    onDismiss()
                }
            }
        }
    }

    // MARK: — Copy

    private func icon(for p: PermissionPrompt) -> String {
        switch p {
        case .photosExplainer:   return "photo.on.rectangle.angled"
        case .photosDenied:      return "lock.fill"
        case .photosRestricted:  return "lock.shield.fill"
        case .cameraExplainer:   return "hand.raised.fill"
        case .cameraDenied:      return "lock.fill"
        }
    }

    private func title(for p: PermissionPrompt) -> LocalizedStringKey {
        switch p {
        case .photosExplainer:   return "Access your Photos"
        case .photosDenied:      return "Photos access is off"
        case .photosRestricted:  return "Photos is restricted"
        case .cameraExplainer:   return "Turn on hand gestures"
        case .cameraDenied:      return "Camera access is off"
        }
    }

    private func subtitle(for p: PermissionPrompt) -> LocalizedStringKey {
        switch p {
        case .photosExplainer:   return "Loom · needs read-only access"
        case .photosDenied:      return "Granted in System Settings"
        case .photosRestricted:  return "Managed by this Mac's profile"
        case .cameraExplainer:   return "Loom · needs camera access"
        case .cameraDenied:      return "Granted in System Settings"
        }
    }
}

// MARK: — Building blocks

private struct PrivacyBullets: View {
    let items: [(icon: String, text: LocalizedStringKey)]
    var body: some View {
        VStack(alignment: .leading, spacing: LoomSpacing.sm) {
            ForEach(items.indices, id: \.self) { i in
                HStack(spacing: LoomSpacing.sm) {
                    Image(systemName: items[i].icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.brass)
                        .frame(width: 18)
                    Text(items[i].text)
                        .font(LoomType.caption)
                        .foregroundStyle(Palette.inkMuted)
                }
            }
        }
        .padding(LoomSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: LoomRadius.card, style: .continuous)
                .fill(Palette.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: LoomRadius.card, style: .continuous)
                .strokeBorder(Palette.hairline, lineWidth: 1)
        )
    }
}

private struct PrimaryCapsule: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: LoomSpacing.xs) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(LoomType.heading)
            }
            .foregroundStyle(Palette.canvas)
            .padding(.horizontal, LoomSpacing.lg)
            .padding(.vertical, LoomSpacing.md - 2)
            .background(Capsule().fill(Palette.brassFill))
            .overlay(Capsule().strokeBorder(Palette.brassLift.opacity(0.6), lineWidth: 0.5))
            .scaleEffect(hovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .brassShadow()
        .onHover { hovered = $0 }
        .animation(LoomMotion.hover, value: hovered)
    }
}
