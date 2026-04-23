import SwiftUI
import AppKit
import LoomCore
import LoomDesign

/// Preferences panel.
///
/// Opened via ⌘, (standard macOS shortcut) or the gear button on the wall.
/// Layout follows a print-editorial rhythm: a quiet sidebar on the left,
/// generous breathing room in the content pane, and no decorative borders —
/// space itself is the divider.
struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case library = "Library"
        case privacy = "Privacy"
        case about   = "About"
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 152)
                .background(Palette.surface)

            Rectangle()
                .fill(Palette.hairline)
                .frame(width: 0.5)

            contentPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Palette.canvas)
        }
        .frame(width: 640, height: 440)
    }

    // MARK: — Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                sidebarItem(tab)
            }
            Spacer()
        }
        .padding(.top, LoomSpacing.xl)
        .padding(.horizontal, LoomSpacing.md)
    }

    private func sidebarItem(_ tab: SettingsTab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Palette.brass)
                    .frame(width: 2.5, height: 16)
                    .opacity(selectedTab == tab ? 1 : 0)
                    .animation(.easeInOut(duration: 0.16), value: selectedTab)

                Text(LocalizedStringKey(tab.rawValue))
                    .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                    .foregroundStyle(selectedTab == tab ? Palette.ink : Palette.inkFaint)

                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.vertical, 7)
            .padding(.horizontal, LoomSpacing.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: — Content pane

    @ViewBuilder
    private var contentPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch selectedTab {
                case .general: GeneralSettings()
                case .library: LibrarySettings()
                case .privacy: PrivacySettings()
                case .about:   AboutSettings()
                }
            }
            .padding(LoomSpacing.xl)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.18), value: selectedTab)
    }
}

// MARK: — General

private struct GeneralSettings: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: LoomSpacing.xxl) {
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
                .frame(maxWidth: 280)
            }

            SettingsSection(title: "Wall density") {
                VStack(alignment: .leading, spacing: LoomSpacing.md) {
                    Picker("", selection: Binding(
                        get: { app.density },
                        set: { newValue in
                            app.setDensity(newValue)
                            NotificationCenter.default.post(
                                name: .loomShuffle, object: nil
                            )
                        }
                    )) {
                        ForEach(WallDensity.allCases, id: \.self) { d in
                            Text(d.displayName).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 280)

                    Text("Roomy shows fewer, larger photos. Dense packs more per wall. Hero styles stay fixed.")
                        .font(LoomType.caption)
                        .foregroundStyle(Palette.inkFaint)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingsSection(title: "Quality filter") {
                VStack(alignment: .leading, spacing: LoomSpacing.md) {
                    Toggle(isOn: Binding(
                        get: { app.filterQuality },
                        set: { newValue in
                            app.setFilterQuality(newValue)
                            NotificationCenter.default.post(
                                name: .loomShuffle, object: nil
                            )
                        }
                    )) {
                        Text("Filter low-quality photos")
                            .font(LoomType.body)
                            .foregroundStyle(Palette.ink)
                    }
                    Text("Skip blurry, overexposed, and very small photos. Pinned photos are always shown.")
                        .font(LoomType.caption)
                        .foregroundStyle(Palette.inkFaint)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingsSection(title: "Auto trim") {
                VStack(alignment: .leading, spacing: LoomSpacing.md) {
                    Toggle(isOn: Binding(
                        get: { app.autoTrimEnabled },
                        set: { newValue in
                            app.setAutoTrimEnabled(newValue)
                            NotificationCenter.default.post(
                                name: .loomShuffle, object: nil
                            )
                        }
                    )) {
                        Text("Crop black / white borders")
                            .font(LoomType.body)
                            .foregroundStyle(Palette.ink)
                    }
                    Text("Automatically zoom past near-black or near-white letterbox edges.")
                        .font(LoomType.caption)
                        .foregroundStyle(Palette.inkFaint)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingsSection(title: "Gestures") {
                VStack(alignment: .leading, spacing: LoomSpacing.md) {
                    Toggle(isOn: Binding(
                        get: { app.handSenseEnabled },
                        set: { newValue in
                            NotificationCenter.default.post(
                                name: .loomHandSenseToggle, object: newValue
                            )
                        }
                    )) {
                        Text("Control the wall with hand gestures")
                            .font(LoomType.body)
                            .foregroundStyle(Palette.ink)
                    }
                    Text("Open your palm to spread · make a fist to gather · shake to shuffle. Camera required; video is never recorded.")
                        .font(LoomType.caption)
                        .foregroundStyle(Palette.inkFaint)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SettingsSection(title: "Keyboard") {
                KeyboardCheatsheet()
            }
        }
    }
}

private struct KeyboardCheatsheet: View {
    private let rows: [(String, String)] = [
        ("␣",     "Shuffle"),
        ("⌘1–⌘7", "Change style"),
        ("⌘O",    "Pick Library…"),
        ("⌘S",    "Save Favorite"),
        ("⌘E",    "Export as PNG…"),
        ("⌘⇧P",   "Export as PDF…"),
        ("⌘⇧L",   "Clear Locks")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: LoomSpacing.sm) {
            ForEach(rows, id: \.0) { row in
                HStack {
                    Text(LocalizedStringKey(row.1))
                        .font(LoomType.caption)
                        .foregroundStyle(Palette.inkMuted)
                    Spacer()
                    Text(row.0)
                        .font(LoomType.mono)
                        .foregroundStyle(Palette.inkFaint)
                }
                .padding(.vertical, 3)
            }
        }
        .padding(.top, LoomSpacing.xs)
    }
}

// MARK: — Library

private struct LibrarySettings: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: LoomSpacing.xxl) {
            SettingsSection(title: "Current library") {
                HStack(spacing: LoomSpacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: LoomSpacing.xs) {
                            Image(systemName: iconName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Palette.brass)
                            libraryNameText
                                .font(LoomType.heading)
                                .foregroundStyle(Palette.ink)
                        }
                        Text(LocalizedStringResource("\(app.photos.count) photos"))
                            .font(LoomType.monoSm)
                            .foregroundStyle(Palette.inkFaint)
                    }
                    Spacer()
                }
                .padding(.leading, LoomSpacing.sm)
                .overlay(
                    Rectangle()
                        .fill(Palette.brass)
                        .frame(width: 2)
                        .offset(x: -LoomSpacing.sm),
                    alignment: .leading
                )
            }

            SettingsSection(title: "Source") {
                HStack(spacing: LoomSpacing.md) {
                    Button {
                        NotificationCenter.default.post(name: .loomPickLibrary, object: nil)
                    } label: {
                        Text("Change folder…")
                    }
                    Button {
                        NotificationCenter.default.post(name: .loomPickPhotosLibrary, object: nil)
                    } label: {
                        Text("Use Photos Library")
                    }
                    Spacer()
                }
            }
        }
    }

    private var libraryNameText: Text {
        guard let url = app.libraryURL else { return Text("No library") }
        if url.path == "/photokit" { return Text("Photos Library") }
        return Text(verbatim: url.lastPathComponent)
    }

    private var iconName: String {
        guard let url = app.libraryURL else { return "square.stack.3d.up.slash" }
        return url.path == "/photokit" ? "photo.on.rectangle.angled" : "folder.fill"
    }
}

// MARK: — Privacy

private struct PrivacySettings: View {

    var body: some View {
        VStack(alignment: .leading, spacing: LoomSpacing.xxl) {
            SettingsSection(title: "Privacy") {
                VStack(alignment: .leading, spacing: LoomSpacing.md) {
                    Bullet(text: "Loom runs entirely on-device. No cloud, no account.")
                    Bullet(text: "Your photos never leave this Mac. The local index can be wiped with one click.")
                }
            }

            SettingsSection(title: "Clear Index") {
                Button(role: .destructive) {
                    NotificationCenter.default.post(name: .loomClearIndex, object: nil)
                } label: {
                    Text("Clear Index")
                        .font(LoomType.body)
                }
                .padding(.top, LoomSpacing.xs)
            }
        }
    }
}

// MARK: — About

private struct AboutSettings: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: LoomSpacing.xxl) {
            VStack(alignment: .leading, spacing: LoomSpacing.lg) {
                Text("Loom")
                    .font(LoomType.displayM)
                    .foregroundStyle(Palette.ink)
                    .displayTracking()

                HStack(spacing: LoomSpacing.xs) {
                    Text("Version")
                        .font(LoomType.caption)
                        .foregroundStyle(Palette.inkFaint)
                    Text(versionString)
                        .font(LoomType.mono)
                        .foregroundStyle(Palette.inkMuted)
                }
            }

            Button {
                if let url = URL(string: "https://github.com/blueberrycongee/loom") {
                    openURL(url)
                }
            } label: {
                Text("github.com/blueberrycongee/loom")
                    .font(LoomType.body)
                    .foregroundStyle(Palette.brass)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}

// MARK: — Building blocks

private struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: LoomSpacing.md) {
            HStack(spacing: LoomSpacing.sm) {
                Text(title)
                    .font(LoomType.heading)
                    .foregroundStyle(Palette.ink)

                Rectangle()
                    .fill(Palette.brass.opacity(0.45))
                    .frame(width: 16, height: 1.5)
            }

            content
        }
    }
}

private struct Bullet: View {
    let text: LocalizedStringKey
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: LoomSpacing.sm) {
            Text("·")
                .font(LoomType.body)
                .foregroundStyle(Palette.brass)
            Text(text)
                .font(LoomType.caption)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
