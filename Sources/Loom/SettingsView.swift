import SwiftUI
import AppKit
import LoomCore
import LoomDesign

/// The app's Settings surface.
///
/// Opened via ⌘, (standard macOS shortcut) or the gear button on the wall
/// (top-right). Four tabs:
///
///   • General — language override
///   • Library — current source, change, clear
///   • Privacy — offline / on-device guarantees, clear-index action
///   • About   — version, license, GitHub
///
/// Styling follows the paper-canvas aesthetic: surface-on-canvas cards,
/// warm charcoal ink, terracotta accents. Kept deliberately compact
/// (~520×380) so the window feels in-product, not like a generic
/// Preferences panel.
struct SettingsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "slider.horizontal.3") }

            LibrarySettings()
                .tabItem { Label("Library", systemImage: "folder") }

            PrivacySettings()
                .tabItem { Label("Privacy", systemImage: "lock.shield") }

            AboutSettings()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding(LoomSpacing.lg)
        .frame(width: 520, height: 420)
        .background(Palette.canvas)
    }
}

// MARK: — General

private struct GeneralSettings: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        SettingsScroll {
            SettingsSection(title: "Language") {
                Picker("", selection: Binding(
                    get: { app.languagePreference },
                    set: { app.setLanguage($0) }
                )) {
                    ForEach(LanguagePreference.allCases, id: \.self) { pref in
                        Text(pref.displayName).tag(pref)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            SettingsSection(title: "Keyboard") {
                KeyboardCheatsheet()
            }
        }
    }
}

private struct KeyboardCheatsheet: View {
    // Tuples of (key, localized description key).
    private let rows: [(String, String)] = [
        ("␣",     "Shuffle"),
        ("⌘1–⌘7", "Change style"),
        ("⌘O",    "Pick Library…"),
        ("⌘S",    "Save Wall as Favorite"),
        ("⌘E",    "Export as PNG…"),
        ("⌘⇧P",  "Export as PDF…"),
        ("⌘⇧L",  "Clear Locks")
    ]

    var body: some View {
        VStack(spacing: LoomSpacing.xs) {
            ForEach(rows, id: \.0) { row in
                HStack {
                    Text(LocalizedStringKey(row.1))
                        .font(LoomType.caption)
                        .foregroundStyle(Palette.inkMuted)
                    Spacer()
                    Text(row.0)
                        .font(LoomType.mono)
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, LoomSpacing.sm)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Palette.surfaceElevated)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .strokeBorder(Palette.hairline, lineWidth: 1)
                                )
                        )
                }
            }
        }
    }
}

// MARK: — Library

private struct LibrarySettings: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        SettingsScroll {
            SettingsSection(title: "Current library") {
                HStack(spacing: LoomSpacing.sm) {
                    Image(systemName: iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Palette.brass)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(libraryName)
                            .font(LoomType.heading)
                            .foregroundStyle(Palette.ink)
                        Text("\(app.photos.count) photos")
                            .font(LoomType.monoSm)
                            .foregroundStyle(Palette.inkFaint)
                    }
                    Spacer()
                }
                .padding(LoomSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: LoomRadius.card, style: .continuous)
                        .fill(Palette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: LoomRadius.card, style: .continuous)
                        .strokeBorder(Palette.hairline, lineWidth: 1)
                )
            }

            SettingsSection(title: "Source") {
                HStack(spacing: LoomSpacing.sm) {
                    Button {
                        NotificationCenter.default.post(name: .loomPickLibrary, object: nil)
                    } label: {
                        Label("Change folder…", systemImage: "folder.badge.plus")
                    }
                    Button {
                        NotificationCenter.default.post(name: .loomPickPhotosLibrary, object: nil)
                    } label: {
                        Label("Use Photos Library", systemImage: "photo.on.rectangle.angled")
                    }
                    Spacer()
                }
            }
        }
    }

    private var libraryName: String {
        guard let url = app.libraryURL else { return String(localized: "No library") }
        if url.path == "/photokit" { return String(localized: "Photos Library") }
        return url.lastPathComponent
    }

    private var iconName: String {
        guard let url = app.libraryURL else { return "square.stack.3d.up.slash" }
        return url.path == "/photokit" ? "photo.on.rectangle.angled" : "folder.fill"
    }
}

// MARK: — Privacy

private struct PrivacySettings: View {

    var body: some View {
        SettingsScroll {
            SettingsSection(title: "Privacy") {
                VStack(alignment: .leading, spacing: LoomSpacing.sm) {
                    Bullet(icon: "bolt.slash.fill",
                           text: "Loom runs entirely on-device. No cloud, no account.")
                    Bullet(icon: "internaldrive",
                           text: "Your photos never leave this Mac. The local index is per-library and can be wiped with one click.")
                }
            }

            SettingsSection(title: "Clear Index") {
                Button(role: .destructive) {
                    NotificationCenter.default.post(name: .loomClearIndex, object: nil)
                } label: {
                    Label("Clear Index", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: — About

private struct AboutSettings: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        SettingsScroll {
            VStack(alignment: .leading, spacing: LoomSpacing.lg) {
                HStack(spacing: LoomSpacing.md) {
                    Image(systemName: "square.on.square.dashed")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(Palette.brass)
                        .frame(width: 56, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: LoomRadius.card, style: .continuous)
                                .fill(Palette.surface)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Loom")
                            .font(LoomType.displayS)
                            .foregroundStyle(Palette.ink)
                        HStack(spacing: LoomSpacing.xs) {
                            Text("Version")
                                .font(LoomType.caption)
                                .foregroundStyle(Palette.inkFaint)
                            Text(versionString)
                                .font(LoomType.mono)
                                .foregroundStyle(Palette.inkMuted)
                        }
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: LoomSpacing.xs) {
                    Button {
                        if let url = URL(string: "https://github.com/blueberrycongee/loom") {
                            openURL(url)
                        }
                    } label: {
                        Label("github.com/blueberrycongee/loom", systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.link)
                }
                Spacer()
            }
        }
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}

// MARK: — Building blocks

private struct SettingsScroll<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LoomSpacing.lg) {
                content
            }
            .padding(LoomSpacing.md)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: LoomSpacing.sm) {
            Text(title)
                .font(LoomType.micro)
                .microTracking()
                .foregroundStyle(Palette.inkFaint)
            content
        }
    }
}

private struct Bullet: View {
    let icon: String
    let text: LocalizedStringKey
    var body: some View {
        HStack(alignment: .top, spacing: LoomSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.brass)
                .frame(width: 18)
                .padding(.top, 3)
            Text(text)
                .font(LoomType.caption)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
