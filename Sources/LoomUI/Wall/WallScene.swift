import SwiftUI
import LoomCore
import LoomDesign

/// Placeholder for the wall rendering scene (M2 fills this in).
public struct WallScene: View {

    @Environment(AppModel.self) private var app

    public init() {}

    public var body: some View {
        VStack(spacing: LoomSpacing.lg) {
            Text("Press Shuffle to weave")
                .font(LoomType.displayM)
                .foregroundStyle(Palette.ink)
                .displayTracking()

            Text("⎵")
                .font(LoomType.displayXL)
                .foregroundStyle(Palette.brass)
        }
    }
}
