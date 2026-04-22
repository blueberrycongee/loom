import Foundation
import SwiftUI

/// User-facing language override. Defaults to ``system`` — respect the
/// Mac's language — but lets the user pin Loom to English or Chinese
/// regardless of system preference.
///
/// The preference is persisted via UserDefaults (so it survives launches)
/// and applied at runtime by ``LoomApp`` through
/// `.environment(\.locale, preference.locale)`, which flips every
/// SwiftUI `Text(_: LocalizedStringKey)` immediately without an app
/// restart.
public enum LanguagePreference: String, CaseIterable, Sendable, Codable {
    case system
    case english
    case chinese

    public var id: String { rawValue }

    /// The `Locale` to inject into the view tree, or nil to use the system
    /// default.
    public var locale: Locale? {
        switch self {
        case .system:  return nil
        case .english: return Locale(identifier: "en")
        case .chinese: return Locale(identifier: "zh-Hans")
        }
    }

    /// Picker-label strings. Returned as ``LocalizedStringKey`` so the
    /// Settings picker switches languages live via the Environment locale
    /// — `String(localized:)` would bake in the call-time locale and miss
    /// the in-app override.
    ///
    /// Convention: language labels display in their *native* script —
    /// "English" stays "English" in Chinese UI; "中文" stays "中文" in
    /// English UI. This is the standard macOS Language-picker style and
    /// helps users who don't read the current UI language find their
    /// own.
    public var displayName: LocalizedStringKey {
        switch self {
        case .system:  return "Follow system"
        case .english: return "English"
        case .chinese: return "中文"
        }
    }

    // MARK: — Persistence

    private static let storageKey = "loom.languagePreference"

    public static var persisted: LanguagePreference {
        get {
            let raw = UserDefaults.standard.string(forKey: storageKey) ?? ""
            return LanguagePreference(rawValue: raw) ?? .system
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }
}
