import SwiftUI

/// A clean Apple-grade list row designed to sit inside a unified panel with hairline dividers.
struct MedicationRowView: View {

    let dose: ScheduledDose
    let onTaken: () -> Void
    let onSkipped: () -> Void
    let onRevoke: () -> Void

    @State private var isHovered = false
    @State private var isPressedTaken = false
    @State private var isHoveredTake = false
    @State private var isHoveredSkip = false

    var body: some View {
        HStack(spacing: 8) {
            // Unified Icon
            UnifiedPillIcon(size: 24, cornerRadius: 6)

            // Info (takes available space, truncates cleanly so it NEVER pushes trailing actions)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(dose.medication.name)
                        .font(AppleTheme.Typography.bodyTitle)
                        .tracking(-0.15)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(AppleTheme.textPrimary)

                    Text(dose.medication.dosage)
                        .font(AppleTheme.Typography.subheadline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(AppleTheme.textSecondary)
                }

                if !dose.medication.notes.isEmpty {
                    Text(dose.medication.notes)
                        .font(AppleTheme.Typography.micro)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(AppleTheme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Scheduled Time (tabular-nums)
            Text(dose.time.formatted)
                .font(AppleTheme.Typography.time)
                .foregroundStyle(AppleTheme.textSecondary)

            // Status / actions
            statusActionArea
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(isHovered ? AppleTheme.rowHover : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            if dose.displayStatus == .taken {
                Button("撤销已服状态") {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        onRevoke()
                    }
                }
            } else {
                Button(dose.displayStatus == .missed ? "补服药物" : "标记为已服用") {
                    playSound()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        onTaken()
                    }
                }
                if dose.displayStatus != .skipped {
                    Button("跳过此次") {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            onSkipped()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Sound Effect

    private func playSound() {
        NSSound(named: "Tink")?.play()
    }

    // MARK: - Status & Action View

    @ViewBuilder
    private var statusActionArea: some View {
        switch dose.displayStatus {
        case .taken:
            HStack(spacing: 5) {
                HStack(spacing: 3.5) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppleTheme.green)
                    Text("已服")
                        .font(AppleTheme.Typography.captionMedium)
                        .foregroundStyle(AppleTheme.textSecondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3.5)

                if isHovered {
                    Button(action: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            onRevoke()
                        }
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(AppleTheme.Typography.microMedium)
                            .padding(4)
                            .background(Circle().fill(Color.primary.opacity(0.06)))
                            .foregroundStyle(AppleTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("撤销已服状态")
                    .transition(.opacity)
                }
            }

        case .missed:
            HStack(spacing: 6) {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(AppleTheme.Typography.microMedium)
                        .foregroundStyle(Color.red.opacity(0.85))
                    Text("漏服")
                        .font(AppleTheme.Typography.captionMedium)
                        .foregroundStyle(Color.red.opacity(0.85))
                }
                .padding(.horizontal, 4)

                Button(action: {
                    playSound()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        onTaken()
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8.5, weight: .bold))
                        Text("补服")
                            .font(AppleTheme.Typography.captionMedium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule()
                            .fill(AppleTheme.blue.opacity(0.10))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(AppleTheme.blue.opacity(0.25), lineWidth: 0.7)
                    )
                    .foregroundStyle(AppleTheme.blue)
                }
                .buttonStyle(.plain)
                .help("补卡：标记为已服用")
            }

        case .skipped:
            HStack(spacing: 6) {
                Text("已跳过")
                    .font(AppleTheme.Typography.captionMedium)
                    .foregroundStyle(AppleTheme.textTertiary)
                    .padding(.horizontal, 4)

                Button(action: {
                    playSound()
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        onTaken()
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8.5, weight: .bold))
                        Text("补服")
                            .font(AppleTheme.Typography.captionMedium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule()
                            .fill(AppleTheme.blue.opacity(0.10))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(AppleTheme.blue.opacity(0.25), lineWidth: 0.7)
                    )
                    .foregroundStyle(AppleTheme.blue)
                }
                .buttonStyle(.plain)
                .help("重新服药并标记为已服")

                if isHovered {
                    Button(action: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            onRevoke()
                        }
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(AppleTheme.Typography.microMedium)
                            .padding(4)
                            .background(Circle().fill(Color.primary.opacity(0.06)))
                            .foregroundStyle(AppleTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("恢复为未服状态")
                    .transition(.opacity)
                }
            }

        case .pending:
            HStack(spacing: 5) {
                // Primary Action: Take Button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.08)) {
                        isPressedTaken = true
                    }
                    playSound()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isPressedTaken = false
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                            onTaken()
                        }
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8.5, weight: .bold))
                        Text("服药")
                            .font(AppleTheme.Typography.captionMedium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule()
                            .fill(isHoveredTake ? AppleTheme.blue.opacity(0.18) : AppleTheme.blue.opacity(0.10))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                AppleTheme.blue.opacity(isHoveredTake ? 0.40 : 0.22),
                                lineWidth: 0.8
                            )
                    )
                    .foregroundStyle(AppleTheme.blue)
                    .scaleEffect(isPressedTaken ? 0.94 : 1.0)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.12)) {
                        isHoveredTake = hovering
                    }
                }
                .help("标记为已服用")

                // Secondary Action: Skip Button
                Button(action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        onSkipped()
                    }
                }) {
                    Text("跳过")
                        .font(AppleTheme.Typography.caption)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule()
                                .fill(isHoveredSkip ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
                        )
                        .foregroundStyle(isHoveredSkip ? AppleTheme.textSecondary : AppleTheme.textTertiary)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.12)) {
                        isHoveredSkip = hovering
                    }
                }
                .help("跳过此次")
            }
        }
    }
}
