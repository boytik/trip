// VitalPalette.swift
// c13 — Smart Packing Companion
//
// Black & Gold color palette with health-inspired naming
// All colors defined as static extensions for seamless SwiftUI integration

import SwiftUI

// MARK: - Vital Palette

/// The living color system of c13 — each shade named after a vital sign or life force.
enum VitalPalette {

    // MARK: — Foundations (Dark Backgrounds)

    /// Deep obsidian — the primary canvas of every screen.
    /// RGB approximation of RAL 9005 Jet Black, adapted for OLED.
    static let obsidianPulse = Color(red: 0.06, green: 0.06, blue: 0.08)

    /// Slightly lifted dark surface — cards, sheets, elevated layers.
    static let midnightVein = Color(red: 0.10, green: 0.10, blue: 0.13)

    /// Tertiary surface for nested cards and input fields.
    static let charcoalBreath = Color(red: 0.15, green: 0.15, blue: 0.18)

    // MARK: — Accents (Gold)

    /// The hero gold — primary accent for progress rings, highlights, CTAs.
    /// Inspired by RAL 1018 Zinc Yellow, warmed into a regal gold.
    static let aureliaGlow = Color(red: 0.89, green: 0.75, blue: 0.30)

    /// Softer gold for secondary indicators, rule badges, subtle highlights.
    static let honeyElixir = Color(red: 0.80, green: 0.68, blue: 0.35)

    /// Muted gold for disabled states, placeholders, ghost elements.
    static let amberWhisper = Color(red: 0.55, green: 0.48, blue: 0.28)

    // MARK: — Neutrals (White Spectrum)

    /// Primary text on dark backgrounds — crisp ivory.
    static let ivoryBreath = Color(red: 0.95, green: 0.94, blue: 0.91)

    /// Secondary text — slightly muted for hierarchy.
    static let boneMarrow = Color(red: 0.70, green: 0.69, blue: 0.66)

    /// Tertiary / disabled text.
    static let ashVeil = Color(red: 0.45, green: 0.44, blue: 0.42)

    // MARK: — Semantic States

    /// Critical / urgent items — warm ember tone instead of harsh red.
    static let emberCore = Color(red: 0.85, green: 0.30, blue: 0.25)

    /// Success / packed / completed — calm teal-green pulse.
    static let verdantPulse = Color(red: 0.20, green: 0.78, blue: 0.55)

    /// Info / rule-added badge — cool steel-blue.
    static let cyanVital = Color(red: 0.30, green: 0.65, blue: 0.85)

    /// Warning / approaching deadline — warm amber signal.
    static let feverSignal = Color(red: 0.92, green: 0.60, blue: 0.20)

    // MARK: — Gradients

    /// Background gradient for the main canvas — subtle depth.
    static let obsidianGradient = LinearGradient(
        colors: [obsidianPulse, midnightVein.opacity(0.95)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Gold shimmer for progress rings and celebratory moments.
    static let aureliaShimmer = LinearGradient(
        colors: [aureliaGlow, honeyElixir],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Card surface gradient for depth perception.
    static let cardVeinGradient = LinearGradient(
        colors: [midnightVein, charcoalBreath.opacity(0.7)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Ember gradient for critical state emphasis.
    static let emberGradient = LinearGradient(
        colors: [emberCore, emberCore.opacity(0.7)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Convenience Shape Styles

extension ShapeStyle where Self == Color {

    /// Quick access: `background(.vitalObsidian)`
    static var vitalObsidian: Color { VitalPalette.obsidianPulse }
    static var vitalMidnight: Color { VitalPalette.midnightVein }
    static var vitalCharcoal: Color { VitalPalette.charcoalBreath }
    static var vitalGold: Color { VitalPalette.aureliaGlow }
    static var vitalHoney: Color { VitalPalette.honeyElixir }
    static var vitalIvory: Color { VitalPalette.ivoryBreath }
    static var vitalBone: Color { VitalPalette.boneMarrow }
    static var vitalAsh: Color { VitalPalette.ashVeil }
    static var vitalEmber: Color { VitalPalette.emberCore }
    static var vitalGreen: Color { VitalPalette.verdantPulse }
    static var vitalCyan: Color { VitalPalette.cyanVital }
}

// MARK: - View Modifiers for Common Styles

extension View {

    /// Applies the standard dark card style with rounded corners and subtle border.
    func vitalCardStyle(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(VitalPalette.midnightVein)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(VitalPalette.aureliaGlow.opacity(0.12), lineWidth: 0.5)
            )
    }

    /// Applies a gold-accented card for highlighted / active elements.
    func vitalGoldCardStyle(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(VitalPalette.midnightVein)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(VitalPalette.aureliaGlow.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: VitalPalette.aureliaGlow.opacity(0.08), radius: 8, y: 4)
    }

    /// Standard screen background — deep obsidian filling all safe areas.
    func vitalScreenBackground() -> some View {
        self
            .background(VitalPalette.obsidianPulse.ignoresSafeArea())
    }
}

// MARK: - Typography Helpers

/// Health-inspired text style presets.
enum VitalTypography {

    /// Hero numbers (progress %, countdown timers).
    static func heroDigit() -> Font {
        .system(size: 52, weight: .bold, design: .rounded)
    }

    /// Large title text.
    static func vitalTitle() -> Font {
        .system(size: 32, weight: .bold, design: .rounded)
    }

    /// Section headers.
    static func sectionPulse() -> Font {
        .system(size: 22, weight: .semibold, design: .rounded)
    }

    /// Body text.
    static func bodyRhythm() -> Font {
        .system(size: 18, weight: .regular, design: .default)
    }

    /// Caption / secondary info.
    static func captionMurmur() -> Font {
        .system(size: 17, weight: .medium, design: .default)
    }

    /// Tiny badge / rule source labels.
    static func microSignal() -> Font {
        .system(size: 15, weight: .semibold, design: .rounded)
    }
}
