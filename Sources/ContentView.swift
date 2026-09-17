import SwiftUI

/// Main popover view: today's medication schedule following Apple Liquid Glass design language.
@MainActor
struct ContentView: View {

    @Environment(MedicationStore.self) private var store
    @State private var screen: Screen = .today
    @State private var editingMedication: Medication?
    @State private var isHoveredAdd = false

    enum Screen: Equatable {
        case today, add, manage
    }

    var body: some View {
        ZStack {
            switch screen {
            case .today:
                todayView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .leading)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
            case .add:
                AddMedicationView(
                    editing: editingMedication,
                    onDone: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            editingMedication = nil
                            screen = .today
                        }
                    }
                )
                .environment(store)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .trailing))
                ))
            case .manage:
                AllMedicationsView(
                    onBack: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            screen = .today
                        }
                    },
                    onEdit: { med in
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            editingMedication = med
                            screen = .add
                        }
                    }
                )
                .environment(store)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .trailing))
                ))
            }
        }
        .frame(width: 360, height: 500)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }

    // MARK: - Today view

    private var todayView: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            if store.todayProgress.total > 0 {
                progressBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }

            Rectangle()
                .fill(AppleTheme.hairline)
                .frame(height: 0.5)

            if store.todayDoses.isEmpty {
                emptyState
            } else {
                doseList
            }

            Rectangle()
                .fill(AppleTheme.hairline)
                .frame(height: 0.5)

            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("今日用药")
                    .font(AppleTheme.Typography.title)
                    .tracking(-0.25)
                    .foregroundStyle(AppleTheme.textPrimary)

                headerSubtitle
            }

            Spacer()

            // Quick add button
            Button(action: {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    editingMedication = nil
                    screen = .add
                }
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(isHoveredAdd ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04))
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(Color.primary.opacity(isHoveredAdd ? 0.12 : 0.05), lineWidth: 0.6)
                    )
                    .foregroundStyle(AppleTheme.textPrimary)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) {
                    isHoveredAdd = hovering
                }
            }
            .help("添加新药物")
        }
    }

    private var headerSubtitle: some View {
        let all = store.todayDoses
        return HStack(spacing: 5) {
            Text(todayString)
                .font(AppleTheme.Typography.caption)
                .foregroundStyle(AppleTheme.textSecondary)

            Text("·")
                .font(AppleTheme.Typography.caption)
                .foregroundStyle(AppleTheme.textTertiary)

            if all.isEmpty {
                Text("今日暂无用药")
                    .font(AppleTheme.Typography.caption)
                    .foregroundStyle(AppleTheme.textTertiary)
            } else {
                let unfinished = all.filter { $0.displayStatus != .taken && $0.displayStatus != .skipped }.count
                if unfinished == 0 {
                    Text("全部已服完 ✨")
                        .font(AppleTheme.Typography.captionMedium)
                        .foregroundStyle(AppleTheme.green)
                } else {
                    Text("\(unfinished) 剂待服")
                        .font(AppleTheme.Typography.captionMedium)
                        .foregroundStyle(AppleTheme.blue)
                }
            }
        }
    }

    // MARK: - Progress Bar (Apple Meter Spec)

    private var progressBar: some View {
        let progress = store.todayProgress
        let ratio = progress.total > 0 ? Double(progress.completed) / Double(progress.total) : 0.0

        return VStack(spacing: 6) {
            HStack {
                Text("今日进度")
                    .font(AppleTheme.Typography.captionMedium)
                    .foregroundStyle(AppleTheme.textSecondary)

                Spacer()

                Text("\(progress.completed) / \(progress.total)")
                    .font(AppleTheme.Typography.counter)
                    .foregroundStyle(AppleTheme.textPrimary)

                Text("(\(Int(ratio * 100))%)")
                    .font(AppleTheme.Typography.micro)
                    .foregroundStyle(AppleTheme.textTertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppleTheme.track)
                        .frame(height: 4.5)

                    Capsule()
                        .fill(AppleTheme.blue)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * ratio)), height: 4.5)
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: ratio)
                }
            }
            .frame(height: 4.5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .appleUnifiedPanel()
    }

    // MARK: - Dose list (Unified Panels)

    private var doseList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(store.todayDosesByTime, id: \.period) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        // Section label
                        HStack(spacing: 4) {
                            Text(group.period.rawValue)
                                .font(AppleTheme.Typography.sectionHeader)
                                .foregroundStyle(AppleTheme.textSecondary)

                            Spacer()

                            Text("\(group.doses.count)")
                                .font(AppleTheme.Typography.counter)
                                .foregroundStyle(AppleTheme.textTertiary)
                        }
                        .padding(.horizontal, 6)

                        // Unified Panel with hairline dividers
                        VStack(spacing: 0) {
                            ForEach(Array(group.doses.enumerated()), id: \.element.id) { index, dose in
                                if index > 0 {
                                    Rectangle()
                                        .fill(AppleTheme.hairline)
                                        .frame(height: 0.5)
                                        .padding(.leading, 48)
                                }

                                MedicationRowView(
                                    dose: dose,
                                    onTaken: {
                                        store.markDose(
                                            medicationId: dose.medication.id,
                                            scheduledTime: dose.time.dateToday(),
                                            status: .taken
                                        )
                                    },
                                    onSkipped: {
                                        store.markDose(
                                            medicationId: dose.medication.id,
                                            scheduledTime: dose.time.dateToday(),
                                            status: .skipped
                                        )
                                    },
                                    onRevoke: {
                                        store.revokeDose(
                                            medicationId: dose.medication.id,
                                            scheduledTime: dose.time.dateToday()
                                        )
                                    }
                                )
                            }
                        }
                        .appleUnifiedPanel()
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    screen = .manage
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .font(AppleTheme.Typography.captionMedium)
                    Text("所有药物")
                        .font(AppleTheme.Typography.captionMedium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundStyle(AppleTheme.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("退出")
                    .font(AppleTheme.Typography.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(AppleTheme.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()

            UnifiedPillIcon(size: 48, cornerRadius: 12)

            VStack(spacing: 4) {
                Text("暂无待服药物")
                    .font(AppleTheme.Typography.navTitle)
                    .tracking(-0.15)
                    .foregroundStyle(AppleTheme.textPrimary)

                Text("今天没有需要服用的药物，可在下方添加新提醒")
                    .font(AppleTheme.Typography.subheadline)
                    .foregroundStyle(AppleTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    editingMedication = nil
                    screen = .add
                }
            }) {
                Text("添加药物")
                    .font(AppleTheme.Typography.subheadlineMedium)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppleTheme.blue)
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private var todayString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: Date())
    }
}
