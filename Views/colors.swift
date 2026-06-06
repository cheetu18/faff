//
//  colors.swift
//  faff
//
//  Created by kyle reddy  on 1/6/25.
//
//  Theme system: selectable "color packs" + a reusable Liquid Glass surface.
//
import Foundation
import SwiftUI

// MARK: - Legacy named colors (kept for backward compatibility)
// These are the original Mallard Duck palette values. They are still
// referenced by a few detail views, so we keep them defined. New UI should
// prefer the active `AppTheme` (see ThemeManager) instead of these constants.
extension Color {
    static let duckGold = Color(red: 0.96, green: 0.78, blue: 0.30)
    static let mallardGreen = Color(red: 0.0, green: 0.45, blue: 0.35)
    static let cream = Color(red: 0.98, green: 0.98, blue: 0.98)
    static let duckSlate = Color(red: 0.27, green: 0.35, blue: 0.45)
    static let duckWing = Color(red: 0.35, green: 0.45, blue: 0.55)
    static let duckNest = Color(red: 0.0, green: 0.55, blue: 0.45)
    static let duckSunset = Color(red: 0.6, green: 0.3, blue: 0.5)
    static let creamColor = Color(red: 0.98, green: 0.96, blue: 0.94)
    static let duckCream = Color(red: 0.98, green: 0.96, blue: 0.94)
    static let duckWhite = Color.white
    static let duckFeet = Color(red: 0.85, green: 0.35, blue: 0.25)
}

// Small convenience for building colors from hex-ish RGB triples.
private extension Color {
    init(_ r: Double, _ g: Double, _ b: Double) {
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - AppTheme

/// A semantic palette. Views read these roles instead of hard-coded colors so
/// that switching color packs restyles the whole app.
struct AppTheme: Equatable {
    let id: String
    let name: String
    let symbol: String          // SF Symbol shown in the picker
    let isDark: Bool

    let background: Color        // screen background
    let surface: Color          // cards / panels
    let surfaceStroke: Color     // hairline border on surfaces
    let primary: Color          // main brand color / primary buttons
    let secondary: Color        // supporting brand color
    let accent: Color           // highlights, word chips
    let textPrimary: Color
    let textSecondary: Color
    let onPrimary: Color        // text / icons sitting on `primary`

    /// Distinct color per media type, derived from the pack.
    func media(_ type: MediaType) -> Color {
        switch type {
        case .book:    return accent
        case .podcast: return secondary
        case .movie:   return primary
        case .other:   return textSecondary
        }
    }

    /// Color tint used by the glass surfaces for this pack.
    var glassTint: Color { surface }
}

// MARK: - Color Packs

enum ColorPack: String, CaseIterable, Identifiable {
    case rubberDucky    // classic black / yellow / orange — the default
    case mallard        // slate + mallard green + gold
    case midnightDrake  // dark mode
    case pinkPreen      // soft pink
    case bluebill       // cool blue

    var id: String { rawValue }

    var theme: AppTheme {
        switch self {
        case .rubberDucky:
            // Classic rubber-duck colors: charcoal black, duck-body yellow,
            // and a bill-orange supporting tone.
            return AppTheme(
                id: rawValue,
                name: "Rubber Ducky",
                symbol: "bird.fill",
                isDark: false,
                background:     Color(0.99, 0.97, 0.91),
                surface:        .white,
                surfaceStroke:  Color(0.16, 0.16, 0.18).opacity(0.15),
                primary:        Color(0.16, 0.16, 0.18),
                secondary:      Color(0.95, 0.55, 0.13),
                accent:         Color(0.97, 0.78, 0.16),
                textPrimary:    Color(0.15, 0.15, 0.16),
                textSecondary:  Color(0.46, 0.44, 0.40),
                onPrimary:      .white
            )
        case .mallard:
            return AppTheme(
                id: rawValue,
                name: "Mallard",
                symbol: "bird.circle.fill",
                isDark: false,
                background:     Color(0.98, 0.96, 0.94),
                surface:        .white,
                surfaceStroke:  Color(0.27, 0.35, 0.45).opacity(0.18),
                primary:        Color(0.27, 0.35, 0.45),
                secondary:      Color(0.0, 0.45, 0.35),
                accent:         Color(0.96, 0.78, 0.30),
                textPrimary:    Color(0.20, 0.27, 0.36),
                textSecondary:  Color(0.45, 0.52, 0.60),
                onPrimary:      .white
            )
        case .midnightDrake:
            return AppTheme(
                id: rawValue,
                name: "Midnight Drake",
                symbol: "moon.stars.fill",
                isDark: true,
                background:     Color(0.10, 0.09, 0.16),
                surface:        Color(0.17, 0.16, 0.25),
                surfaceStroke:  Color(0.55, 0.50, 0.95).opacity(0.30),
                primary:        Color(0.56, 0.51, 0.95),
                secondary:      Color(0.40, 0.72, 0.95),
                accent:         Color(0.96, 0.62, 0.86),
                textPrimary:    Color(0.94, 0.94, 0.98),
                textSecondary:  Color(0.66, 0.65, 0.78),
                onPrimary:      .white
            )
        case .pinkPreen:
            return AppTheme(
                id: rawValue,
                name: "Pink Preen",
                symbol: "sparkles",
                isDark: false,
                background:     Color(0.99, 0.96, 0.97),
                surface:        .white,
                surfaceStroke:  Color(0.85, 0.40, 0.55).opacity(0.20),
                primary:        Color(0.85, 0.40, 0.55),
                secondary:      Color(0.56, 0.42, 0.72),
                accent:         Color(0.97, 0.74, 0.52),
                textPrimary:    Color(0.32, 0.20, 0.28),
                textSecondary:  Color(0.58, 0.46, 0.53),
                onPrimary:      .white
            )
        case .bluebill:
            return AppTheme(
                id: rawValue,
                name: "Bluebill",
                symbol: "water.waves",
                isDark: false,
                background:     Color(0.94, 0.97, 0.99),
                surface:        .white,
                surfaceStroke:  Color(0.10, 0.45, 0.65).opacity(0.20),
                primary:        Color(0.10, 0.45, 0.65),
                secondary:      Color(0.20, 0.62, 0.72),
                accent:         Color(0.96, 0.72, 0.35),
                textPrimary:    Color(0.12, 0.25, 0.35),
                textSecondary:  Color(0.40, 0.55, 0.62),
                onPrimary:      .white
            )
        }
    }
}

// MARK: - ThemeManager

/// Holds the active color pack and persists the choice. Inject into the
/// environment at the app root and observe it where the UI needs to react.
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private let storageKey = "selectedColorPack"

    @Published var pack: ColorPack {
        didSet { UserDefaults.standard.set(pack.rawValue, forKey: storageKey) }
    }

    var theme: AppTheme { pack.theme }

    init() {
        let saved = UserDefaults.standard.string(forKey: storageKey) ?? ""
        pack = ColorPack(rawValue: saved) ?? .rubberDucky
    }
}

// MARK: - Liquid Glass surface

extension View {
    /// A reusable "Liquid Glass" surface.
    ///
    /// On iOS 26+ this uses Apple's real `.glassEffect`. On earlier systems it
    /// falls back to a translucent material so the app still looks glassy.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 20,
                   tint: Color? = nil,
                   interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular.tint(tint).interactive(interactive),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            self.background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }
}
// Note: `mediaColor(_:)` and `mediaSymbol(_:)` live in the Model layer
// (Enums.swift / MediaItem.swift). New UI prefers `AppTheme.media(_:)`.
