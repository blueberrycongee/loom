import SwiftUI
import AppKit
import LoomCore
import LoomDesign

/// A small pill in the top-left of the wall that shows the current library
/// source and lets the user switch to a different one — without needing to
/// find the File menu.
///
/// Before this, the only way to change the source after the first pick was
/// ⌘O or `File → Pick Library…`. Both invisible. This chip surfaces the
/// affordance.
///
/// Displays three states:
///   • Folder library — folder icon + basename + photo count; menu offers
///     Change Folder / Use Photos Library / Reveal in Finder.
///   • Photos library — `photo.on.rectangle.angled` icon + "Photos Library"
///     label + count; menu offers Change Folder / Use Photos Library.
///   • No library (shouldn't render in .ready but handled defensively).
public struct LibraryChip: View {

    @Environment(AppModel.self) private var app
    @State private var hovered = false

    public init() {}

    public var body: some View {
        Menu {
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

            if let folder = folderURL {
                Divider()
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([folder])
                } label: {
                    Label("Reveal in Finder", systemImage: "magnifyingglass.circle")
                }
                Button {
                    NSWorkspace.shared.open(folder)
                } label: {
                    Label("Open in Finder", systemImage: "arrow.up.right.square")
                }
            }
        } label: {
            label
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        // No .fixedSize() here — the inner label handles width via the
        // 340pt max-width cap + truncation on the folder name, so the
        // chip stays within the top-left region instead of extending
        // across the wall on long folder names.
        .onHover { hovered = $0 }
        .animation(LoomMotion.hover, value: hovered)
    }

    // MARK: — Label

    private var label: some View {
        HStack(spacing: LoomSpacing.xs) {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Palette.brass)

            // Folder basenames can be arbitrarily long. Let the Text
            // truncate (middle ellipsis) rather than demanding ideal
            // width via .fixedSize — on narrow windows the chip would
            // otherwise overflow toward the right edge and collide with
            // SettingsChip. Surrounding items are .fixedSize() so only
            // this one flexes when the 340pt frame cap bites.
            libraryNameText
                .font(LoomType.caption)
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .truncationMode(.middle)

            Text("·")
                .font(LoomType.caption)
                .foregroundStyle(Palette.inkFaint)
                .fixedSize()

            Text(LocalizedStringResource("\(app.photos.count) photos"))
                .font(LoomType.monoSm)
                .foregroundStyle(Palette.inkMuted)
                .lineLimit(1)
                .fixedSize()

            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Palette.inkFaint)
                .padding(.leading, 2)
        }
        .padding(.horizontal, LoomSpacing.md)
        .padding(.vertical, LoomSpacing.xs + 2)
        .background(
            Capsule()
                .fill(Palette.surface.opacity(0.88))
                .background(.ultraThinMaterial, in: Capsule())
        )
        .overlay(Capsule().strokeBorder(Palette.hairline, lineWidth: 1))
        .frame(maxWidth: 340, alignment: .leading)
        .offset(y: hovered ? -1 : 0)
    }

    // MARK: — Derived

    /// The library label as a ``Text``. This returns Text (rather than
    /// String / LocalizedStringKey) because the folder-name case holds
    /// user data (which must NOT be translated — "Travel 2024" stays
    /// "Travel 2024" in every language) while the sentinel cases
    /// ("Photos Library", "No library") are app strings (which must
    /// translate). Only Text gives us one return type that expresses
    /// both.
    private var libraryNameText: Text {
        guard let url = app.libraryURL else {
            return Text("No library")
        }
        if url.path == "/photokit" {
            return Text("Photos Library")
        }
        let name = url.lastPathComponent
        return Text(verbatim: name.isEmpty ? url.path : name)
    }

    private var iconName: String {
        guard let url = app.libraryURL else { return "square.stack.3d.up.slash" }
        return url.path == "/photokit"
            ? "photo.on.rectangle.angled"
            : "folder.fill"
    }

    /// The folder URL, or nil if the current source is Photos library /
    /// nothing. Drives the Finder-only menu items.
    private var folderURL: URL? {
        guard let url = app.libraryURL, url.path != "/photokit" else { return nil }
        return url
    }
}
