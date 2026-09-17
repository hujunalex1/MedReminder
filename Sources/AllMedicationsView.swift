import SwiftUI

/// Lists all medications for management inside a unified Apple-grade panel with hairline dividers.
@MainActor
struct AllMedicationsView: View {

    @Environment(MedicationStore.self) private var store

    let onBack: () -> Void
    let onEdit: (Medication) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                            .font(AppleTheme.Typography.captionMedium)
                        Text("返回")
                            .font(AppleTheme.Typography.subheadlineMedium)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .foregroundStyle(AppleTheme.textSecondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("所有药物")
                    .font(AppleTheme.Typography.navTitle)
                    .tracking(-0.15)
                    .foregroundStyle(AppleTheme.textPrimary)

                Spacer()

                Color.clear.frame(width: 48, height: 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .background(.ultraThinMaterial)

            Rectangle()
                .fill(AppleTheme.hairline)
                .frame(height: 0.5)

            if store.medications.isEmpty {
                emptyState
            } else {
                medList
            }
        }
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }

    // MARK: - List (Unified Panel)

    private var medList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(store.medications.enumerated()), id: \.element.id) { index, med in
                    if index > 0 {
                        Rectangle()
                            .fill(AppleTheme.hairline)
                            .frame(height: 0.5)
                            .padding(.leading, 48)
                    }

                    MedicationManageRow(
                        med: med,
                        onToggle: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                store.toggleMedication(med)
                            }
                        },
                        onEdit: { onEdit(med) },
                        onDelete: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                store.deleteMedication(med)
                            }
                        }
                    )
                }
            }
            .appleUnifiedPanel()
            .padding(14)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            UnifiedPillIcon(size: 48, cornerRadius: 12)

            Text("还没有添加任何药物")
                .font(AppleTheme.Typography.bodyTitle)
                .foregroundStyle(AppleTheme.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Medication Manage Row

@MainActor
private struct MedicationManageRow: View {

    let med: Medication
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            // Unified Icon
            UnifiedPillIcon(size: 26, cornerRadius: 6)
                .opacity(med.isActive ? 1.0 : 0.45)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(med.name)
                        .font(AppleTheme.Typography.bodyTitle)
                        .tracking(-0.15)
                        .foregroundStyle(med.isActive ? AppleTheme.textPrimary : AppleTheme.textSecondary)

                    Text(med.dosage)
                        .font(AppleTheme.Typography.subheadline)
                        .foregroundStyle(AppleTheme.textSecondary)
                }

                HStack(spacing: 4) {
                    Text(med.frequency.displayText)
                        .font(AppleTheme.Typography.caption)
                        .foregroundStyle(AppleTheme.textSecondary)

                    Text("·")
                        .font(AppleTheme.Typography.caption)
                        .foregroundStyle(AppleTheme.textTertiary)

                    Text(med.times.map(\.formatted).joined(separator: ", "))
                        .font(AppleTheme.Typography.counter)
                        .foregroundStyle(AppleTheme.textTertiary)
                }
            }

            Spacer()

            // Action buttons on hover
            if isHovered {
                HStack(spacing: 4) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(AppleTheme.Typography.microMedium)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.primary.opacity(0.05)))
                            .foregroundStyle(AppleTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .help("编辑")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(AppleTheme.Typography.microMedium)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.red.opacity(0.08)))
                            .foregroundStyle(Color.red.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .help("删除")
                }
                .transition(.opacity)
            }

            // Active toggle
            Toggle("", isOn: Binding(
                get: { med.isActive },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isHovered ? AppleTheme.rowHover : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("编辑") { onEdit() }
            Button(med.isActive ? "停用" : "启用") { onToggle() }
            Divider()
            Button("删除", role: .destructive) { onDelete() }
        }
    }
}
