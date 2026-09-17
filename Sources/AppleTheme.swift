import SwiftUI
import AppKit

/// NSVisualEffectView wrapper for macOS native vibrancy and frosted glass effects
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = state
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = state
    }
}

/// Apple Liquid Glass Design System Tokens & Modifiers
/// Reference: https://github.com/naplesblue/apple-design-skill
enum AppleTheme {
    // MARK: - Colors (Neutrals & Accents)
    static let ground = Color.clear
    static let surface = Color(nsColor: .controlBackgroundColor).opacity(0.72)
    static let rowHover = Color.primary.opacity(0.035)
    static let track = Color(nsColor: .separatorColor).opacity(0.3)
    static let hairline = Color.primary.opacity(0.075)
    static let blue = Color(red: 0.0, green: 0.443, blue: 0.890) // Apple Blue #0071e3
    static let green = Color(red: 0.20, green: 0.78, blue: 0.35) // Apple Green #34c759

    // MARK: - Text Colors
    static let textPrimary = Color(nsColor: .labelColor)
    static let textSecondary = Color(nsColor: .secondaryLabelColor)
    static let textTertiary = Color(nsColor: .tertiaryLabelColor)

    // MARK: - Radius Tiers
    static let radiusPanel: CGFloat = 12
    static let radiusCard: CGFloat = 9

    // MARK: - Typography (Apple HIG Standard Scale)
    enum Typography {
        /// 15pt Semibold - Window Title / Primary Header ("吃药提醒")
        static let title = Font.system(size: 15, weight: .semibold)
        /// 14pt Semibold - Navigation / Section Title ("添加药物", "所有药物")
        static let navTitle = Font.system(size: 14, weight: .semibold)
        /// 13pt Medium - Card Primary Title (Medication name)
        static let bodyTitle = Font.system(size: 13, weight: .medium)
        /// 13pt Regular - Standard body text / nav action
        static let body = Font.system(size: 13, weight: .regular)
        /// 12pt Medium - Subheading / Action Buttons ("服药", "补服", "所有药物")
        static let subheadlineMedium = Font.system(size: 12, weight: .medium)
        /// 12pt Regular - Subtitle / Dosage ("500mg", "1片")
        static let subheadline = Font.system(size: 12, weight: .regular)
        /// 11pt Semibold - Group / Section Header ("上午", "基本信息")
        static let sectionHeader = Font.system(size: 11, weight: .semibold)
        /// 11pt Medium - Badges / Status / Pills ("已服", "漏服", "周一")
        static let captionMedium = Font.system(size: 11, weight: .medium)
        /// 11pt Regular - Minor descriptions / Secondary dates
        static let caption = Font.system(size: 11, weight: .regular)
        /// 10pt Medium - Micro badges / Section counts / Icons
        static let microMedium = Font.system(size: 10, weight: .medium)
        /// 10pt Regular - Notes / Tertiary info
        static let micro = Font.system(size: 10, weight: .regular)

        // Monospaced Numbers (for clocks, counts, percentages)
        /// 12pt Monospaced - Scheduled times ("08:30")
        static let time = Font.system(size: 12, weight: .medium, design: .default).monospacedDigit()
        /// 11pt Monospaced - Stat numbers & counts ("1 / 3")
        static let counter = Font.system(size: 11, weight: .regular, design: .default).monospacedDigit()
    }
}

// MARK: - Unified Surface Modifier
struct AppleUnifiedPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppleTheme.radiusPanel, style: .continuous)
                    .fill(AppleTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppleTheme.radiusPanel, style: .continuous)
                    .strokeBorder(AppleTheme.hairline, lineWidth: 0.7)
            )
            .shadow(color: Color.black.opacity(0.035), radius: 5, x: 0, y: 1.5)
    }
}

extension View {
    func appleUnifiedPanel() -> some View {
        modifier(AppleUnifiedPanelModifier())
    }
}
