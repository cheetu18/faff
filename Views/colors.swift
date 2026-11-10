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
    case bufflehead     // crisp white + black + iridescent sheen
    case pinkPreen      // soft pink
    case mandarin       // vivid orange + plum + teal
    case ruddy          // warm rust + sky-blue bill
    case harlequin      // dark: deep slate-blue + chestnut + white stripes

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
        case .bufflehead:
            // Crisp bufflehead white as the dominant color, with bold black
            // and a subtle iridescent green/purple sheen for accents.
            return AppTheme(
                id: rawValue,
                name: "Bufflehead",
                symbol: "circle.lefthalf.filled",
                isDark: false,
                background:     Color(0.97, 0.98, 0.99),
                surface:        .white,
                surfaceStroke:  Color(0.14, 0.16, 0.18).opacity(0.16),
                primary:        Color(0.14, 0.16, 0.18),
                secondary:      Color(0.40, 0.28, 0.55),
                accent:         Color(0.10, 0.52, 0.48),
                textPrimary:    Color(0.13, 0.15, 0.18),
                textSecondary:  Color(0.45, 0.48, 0.53),
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
        case .mandarin:
            // Ornate mandarin drake: vivid orange sail feathers, a plum breast,
            // and a teal flash.
            return AppTheme(
                id: rawValue,
                name: "Mandarin",
                symbol: "crown.fill",
                isDark: false,
                background:     Color(0.99, 0.97, 0.93),
                surface:        .white,
                surfaceStroke:  Color(0.87, 0.43, 0.13).opacity(0.20),
                primary:        Color(0.87, 0.43, 0.13),
                secondary:      Color(0.52, 0.26, 0.46),
                accent:         Color(0.10, 0.56, 0.58),
                textPrimary:    Color(0.30, 0.18, 0.12),
                textSecondary:  Color(0.52, 0.42, 0.36),
                onPrimary:      .white
            )
        case .ruddy:
            // Warm cinnamon body with the ruddy duck's signature blue bill.
            return AppTheme(
                id: rawValue,
                name: "Ruddy Duck",
                symbol: "flame.fill",
                isDark: false,
                background:     Color(0.99, 0.96, 0.92),
                surface:        .white,
                surfaceStroke:  Color(0.70, 0.30, 0.18).opacity(0.20),
                primary:        Color(0.70, 0.30, 0.18),
                secondary:      Color(0.84, 0.52, 0.24),
                accent:         Color(0.26, 0.64, 0.90),
                textPrimary:    Color(0.30, 0.17, 0.12),
                textSecondary:  Color(0.52, 0.40, 0.34),
                onPrimary:      .white
            )
        case .harlequin:
            // The only dark pack: a harlequin drake on whitewater at dusk.
            // Deep slate-blue plumage, chestnut flanks, and the bird's crisp
            // white face and neck stripes.
            return AppTheme(
                id: rawValue,
                name: "Harlequin",
                symbol: "moon.stars.fill",
                isDark: true,
                background:     Color(0.07, 0.09, 0.15),
                surface:        Color(0.13, 0.17, 0.26),
                surfaceStroke:  Color(0.93, 0.95, 0.98).opacity(0.14),
                primary:        Color(0.80, 0.42, 0.24),
                secondary:      Color(0.36, 0.48, 0.70),
                accent:         Color(0.93, 0.95, 0.98),
                textPrimary:    Color(0.93, 0.95, 0.98),
                textSecondary:  Color(0.62, 0.68, 0.78),
                onPrimary:      Color(0.07, 0.09, 0.15)
            )
        }
    }
}

// MARK: - ThemeManager

/// Holds the active color pack and persists the choice. Injected into the
/// environment at the app root; views read it with `@Environment(ThemeManager.self)`.
@MainActor
@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    private let storageKey = "selectedColorPack"

    var pack: ColorPack {
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
    /// A reusable Liquid Glass surface.
    ///
    /// This owns the whole surface treatment, edge included. Do not stack a
    /// `.stroke` overlay on top of it: the glass material already renders its
    /// own border, and drawing a second one over it reads as a hard hairline
    /// that fights the material's specular edge.
    func glassCard(cornerRadius: CGFloat = 20,
                   tint: Color? = nil,
                   interactive: Bool = false) -> some View {
        glassEffect(
            .regular.tint(tint).interactive(interactive),
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
}

// MARK: - Themed navigation title

extension View {
    /// Renders the navigation title in the theme's primary color.
    ///
    /// This replaces the old global `UINavigationBar.appearance()` override.
    /// Supplying a custom title view through the `.largeTitle` / `.title`
    /// toolbar placements is the supported route, and unlike the appearance
    /// proxy it is scoped to this view and leaves the bar's Liquid Glass
    /// scroll-edge behavior intact.
    /// Only the `.largeTitle` placement is supplied. Providing `.title` as well
    /// renders the title twice — the bar draws the inline item *and* the large
    /// one rather than swapping between them — so the inline presentation is
    /// left to `navigationTitle`, which also feeds the back button.
    /// Pass `nil` to show no visible header (e.g. a tab root whose tab label
    /// already says what it is). The view's identity stays stable either way.
    func themedNavigationTitle(_ title: String?, theme: AppTheme) -> some View {
        navigationTitle(title ?? "")
            .navigationBarTitleDisplayMode(title == nil ? .inline : .automatic)
            .toolbar {
                if let title {
                    ToolbarItem(placement: .largeTitle) {
                        Text(title)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(theme.primary)
                    }
                }
            }
    }
}

/// Groups adjacent glass surfaces so they blend and morph as one system
/// instead of compositing independently. Wrap sibling `glassCard`s in this.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        GlassEffectContainer(spacing: spacing) {
            content
        }
    }
}
// Note: `mediaColor(_:)` and `mediaSymbol(_:)` live in the Model layer
// (Enums.swift / MediaItem.swift). New UI prefers `AppTheme.media(_:)`.
