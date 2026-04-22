import SwiftUI
import LoomCore
import LoomDesign

struct SettingsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "slider.horizontal.3") }
            PrivacySettings()
                .tabItem { Label("Privacy", systemImage: "lock.shield") }
        }
        .padding(LoomSpacing.lg)
        .frame(width: 480, height: 320)
        .background(Palette.surface)
    }
}

private struct GeneralSettings: View {
    var body: some View {
        VStack(alignment: .leading, spacing: LoomSpacing.md) {
            Text("General")
                .font(LoomType.title)
                .foregroundStyle(Palette.ink)
            Text("Loom runs entirely on-device. No cloud, no account.")
                .font(LoomType.body)
                .foregroundStyle(Palette.inkMuted)
            Spacer()
        }
        .padding(LoomSpacing.md)
    }
}

private struct PrivacySettings: View {
    var body: some View {
        VStack(alignment: .leading, spacing: LoomSpacing.md) {
            Text("Privacy")
                .font(LoomType.title)
                .foregroundStyle(Palette.ink)
            Text("Your photos never leave this Mac. The local index is per-library and can be wiped with one click.")
                .font(LoomType.body)
                .foregroundStyle(Palette.inkMuted)
            Spacer()
            Button(role: .destructive) {
                // TODO: wire to IndexStore.wipe()
            } label: {
                Text("Clear Index")
            }
        }
        .padding(LoomSpacing.md)
    }
}
