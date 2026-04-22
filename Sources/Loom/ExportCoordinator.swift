import AppKit
import Foundation
import UniformTypeIdentifiers
import LoomCore
import LoomUI

/// Bridges ``NSSavePanel`` with ``WallRenderer``.
///
/// Listens on `.loomExportPNG` and `.loomExportPDF` notifications, prompts
/// the user for a destination, then drives the off-screen renderer.
@MainActor
final class ExportCoordinator {

    private let app: AppModel

    init(app: AppModel) {
        self.app = app
        register()
    }

    private func register() {
        let center = NotificationCenter.default
        center.addObserver(
            forName: .loomSnapshotWall,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.snapshotWall() }
        }
        center.addObserver(
            forName: .loomExportPNG,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.exportPNG() }
        }
        center.addObserver(
            forName: .loomExportPDF,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.exportPDF() }
        }
    }

    private func snapshotWall() {
        guard !app.wall.isEmpty else { return }
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        let name = "Loom-Wall-\(df.string(from: Date())).png"
        let url = desktop.appendingPathComponent(name)
        _ = WallRenderer.renderToPNG(
            wall: app.wall,
            photos: app.photos,
            scale: 3.0,
            applyCropInsets: app.autoTrimEnabled,
            to: url
        )
    }

    private func exportPNG() {
        guard !app.wall.isEmpty else { return }
        savePanel(
            suggested: "\(app.wall.style.displayName).png",
            contentType: .png
        ) { url in
            _ = WallRenderer.renderToPNG(
                wall: self.app.wall,
                photos: self.app.photos,
                scale: 3.0,
                applyCropInsets: self.app.autoTrimEnabled,
                to: url
            )
        }
    }

    private func exportPDF() {
        guard !app.wall.isEmpty else { return }
        savePanel(
            suggested: "\(app.wall.style.displayName).pdf",
            contentType: .pdf
        ) { url in
            _ = WallRenderer.renderToPDF(
                wall: self.app.wall,
                photos: self.app.photos,
                applyCropInsets: self.app.autoTrimEnabled,
                to: url
            )
        }
    }

    private func savePanel(
        suggested name: String,
        contentType: UTType,
        then body: @escaping (URL) -> Void
    ) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.allowedContentTypes = [contentType]
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in body(url) }
        }
    }
}
