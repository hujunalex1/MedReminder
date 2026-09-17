import SwiftUI

/// A native, refined form for adding or editing medications adhering to Apple Liquid Glass design language.
@MainActor
struct AddMedicationView: View {

    @Environment(MedicationStore.self) private var store

    let editing: Medication?
    let onDone: () -> Void

    // MARK: - Form state

    @State private var name = ""
    @State private var dosage = ""
    @State private var times: [Date] = []
    @State private var frequencyType: FrequencyType = .daily
    @State private var selectedWeekdays: Set<Int> = []
    /// Phase anchor of an `everyOtherDay` schedule. Kept across edits: it is the
    /// only thing that says which day is a dose day, so rebuilding it from
    /// "today" on every save would shift the whole cycle by a day.
    @State private var everyOtherStart = Date()
    @State private var notes = ""
    @State private var showDeleteConfirm = false

    enum FrequencyType: String, CaseIterable {
        case daily      = "每天"
        case everyOther = "隔一天"
        case weekdays   = "指定星期"
    }

    // MARK: - Init

    init(editing: Medication? = nil, onDone: @escaping () -> Void) {
        self.editing = editing
        self.onDone  = onDone

        if let med = editing {
            _name   = State(initialValue: med.name)
            _dosage = State(initialValue: med.dosage)
            _notes  = State(initialValue: med.notes)
            _times  = State(initialValue: med.times.map { $0.dateToday() })
            switch med.frequency {
            case .daily:
                _frequencyType = State(initialValue: .daily)
            case .everyOtherDay(let start):
                _frequencyType   = State(initialValue: .everyOther)
                _everyOtherStart = State(initialValue: start)
            case .weekdays(let days):
                _frequencyType    = State(initialValue: .weekdays)
                _selectedWeekdays = State(initialValue: days)
            }
        } else {
            let cal = Calendar.current
            _times = State(initialValue: [
                cal.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
            ])
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// The selected times as times of day, in the order shown.
    private var selectedTimes: [TimeOfDay] {
        times.map { TimeOfDay.fromDate($0) }
    }

    /// Selected times that already passed today. Only worth warning about while
    /// adding: for an existing medication a past time is simply today's dose.
    private var pastTimes: [TimeOfDay] {
        guard editing == nil else { return [] }
        let now = Date()
        return selectedTimes.filter { $0.dateToday() < now }
    }

    /// Selected times that appear more than once. Saving merges them, since a
    /// dose is identified by (medication, minute): keeping both would show two
    /// rows sharing one record and double-count towards today's progress.
    private var duplicateTimes: [TimeOfDay] {
        var seen = Set<TimeOfDay>()
        var duplicates: [TimeOfDay] = []
        for time in selectedTimes where !seen.insert(time).inserted && !duplicates.contains(time) {
            duplicates.append(time)
        }
        return duplicates
    }

    /// Next whole hour (from 20:00, wrapping around) not already in the list, so
    /// tapping "添加更多服药时间" twice does not append the same time twice.
    private func nextFreeTime() -> Date {
        let cal = Calendar.current
        let used = Set(selectedTimes.map { $0.hour * 60 + $0.minute })
        let hour = (0..<24).map { (20 + $0) % 24 }.first { !used.contains($0 * 60) } ?? 20
        return cal.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            navBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)

            Rectangle()
                .fill(AppleTheme.hairline)
                .frame(height: 0.5)

            ScrollView {
                VStack(spacing: 14) {
                    // Card 1: 基本信息
                    basicInfoCard

                    // Card 2: 提醒与频次
                    scheduleCard

                    // Card 3: 备注说明
                    notesCard

                    if editing != nil {
                        deleteMedicationCard
                    }
                }
                .padding(14)
            }
        }
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
    }

    // MARK: - Navigation Bar

    private var navBar: some View {
        HStack {
            Button("取消") {
                onDone()
            }
            .buttonStyle(.plain)
            .font(AppleTheme.Typography.body)
            .foregroundStyle(AppleTheme.textSecondary)
            .frame(width: 48, alignment: .leading)

            Spacer()

            Text(editing == nil ? "添加药物" : "编辑药物")
                .font(AppleTheme.Typography.navTitle)
                .tracking(-0.15)
                .foregroundStyle(AppleTheme.textPrimary)

            Spacer()

            Button("保存") {
                save()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!isValid)
            .frame(width: 48, alignment: .trailing)
        }
    }

    private let quickDosagePresets = [
        "1片", "2片", "半片", "1粒", "2粒", "1袋", "10ml", "1支", "500mg"
    ]

    // MARK: - Card 1: Basic Info

    private var basicInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("基本信息")
                .font(AppleTheme.Typography.sectionHeader)
                .foregroundStyle(AppleTheme.textSecondary)

            VStack(spacing: 8) {
                TextField("药品名称 (如: 阿莫西林)", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("剂量规格 (如: 500mg, 1片)", text: $dosage)
                    .textFieldStyle(.roundedBorder)

                // 常用规格/剂量快速填充
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(AppleTheme.Typography.microMedium)
                        Text("常用规格快速填充")
                            .font(AppleTheme.Typography.microMedium)
                    }
                    .foregroundStyle(AppleTheme.textTertiary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(quickDosagePresets, id: \.self) { preset in
                                Button(action: {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        dosage = preset
                                    }
                                }) {
                                    Text(preset)
                                        .font(AppleTheme.Typography.captionMedium)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3.5)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(dosage == preset ? AppleTheme.blue.opacity(0.16) : Color.primary.opacity(0.04))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .strokeBorder(
                                                    dosage == preset ? AppleTheme.blue.opacity(0.35) : Color.primary.opacity(0.06),
                                                    lineWidth: 0.7
                                                )
                                        )
                                        .foregroundStyle(dosage == preset ? AppleTheme.blue : AppleTheme.textSecondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .appleUnifiedPanel()
    }

    // MARK: - Card 2: Schedule & Frequency

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("提醒与频次")
                .font(AppleTheme.Typography.sectionHeader)
                .foregroundStyle(AppleTheme.textSecondary)

            // Frequency Segmented Control
            Picker("", selection: $frequencyType) {
                ForEach(FrequencyType.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)

            // Weekdays selector if enabled
            if frequencyType == .weekdays {
                HStack(spacing: 4) {
                    ForEach(1...7, id: \.self) { day in
                        let dayNames = ["", "一", "二", "三", "四", "五", "六", "日"]
                        let isSelected = selectedWeekdays.contains(day)

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                if isSelected {
                                    selectedWeekdays.remove(day)
                                } else {
                                    selectedWeekdays.insert(day)
                                }
                            }
                        }) {
                            Text(dayNames[day])
                                .font(AppleTheme.Typography.captionMedium)
                                .frame(maxWidth: .infinity)
                                .frame(height: 26)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(isSelected ? AppleTheme.blue : Color.primary.opacity(0.04))
                                )
                                .foregroundStyle(isSelected ? Color.white : AppleTheme.textPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity)
            }

            Rectangle()
                .fill(AppleTheme.hairline)
                .frame(height: 0.5)

            // Scheduled Times list
            VStack(spacing: 8) {
                ForEach(times.indices, id: \.self) { i in
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(AppleTheme.Typography.caption)
                            Text("服药时间 \(i + 1)")
                                .font(AppleTheme.Typography.subheadline)
                        }
                        .foregroundStyle(AppleTheme.textSecondary)

                        Spacer()

                        DatePicker("", selection: $times[i], displayedComponents: .hourAndMinute)
                            .labelsHidden()

                        if times.count > 1 {
                            Button(action: {
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                    _ = times.remove(at: i)
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(AppleTheme.Typography.body)
                                    .foregroundStyle(Color.red.opacity(0.75))
                            }
                            .buttonStyle(.plain)
                            .help("删除此时间")
                        }
                    }
                }

                Button(action: {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                        times.append(nextFreeTime())
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(AppleTheme.Typography.caption)
                        Text("添加更多服药时间")
                            .font(AppleTheme.Typography.captionMedium)
                    }
                    .foregroundStyle(AppleTheme.blue)
                    .padding(.top, 2)
                }
                .buttonStyle(.plain)

                if !duplicateTimes.isEmpty || !pastTimes.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        if !duplicateTimes.isEmpty {
                            timeHint("有重复的服药时间，保存时会自动合并")
                        }
                        if !pastTimes.isEmpty {
                            timeHint("\(pastTimes.map(\.formatted).joined(separator: "、")) 今天已过，明天才会开始提醒")
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(12)
        .appleUnifiedPanel()
    }

    private func timeHint(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle")
                .font(AppleTheme.Typography.micro)
            Text(text)
                .font(AppleTheme.Typography.micro)
        }
        .foregroundStyle(AppleTheme.textTertiary)
    }

    // MARK: - Card 3: Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("用药备注 (可选)")
                .font(AppleTheme.Typography.sectionHeader)
                .foregroundStyle(AppleTheme.textSecondary)

            TextField("如：饭后温水送服、不可空腹等", text: $notes)
                .textFieldStyle(.roundedBorder)
        }
        .padding(12)
        .appleUnifiedPanel()
    }

    // MARK: - Card 4: Delete Action (Editing only)

    private var deleteMedicationCard: some View {
        Group {
            if showDeleteConfirm {
                // Asked inline for the same reason as the manage list: a
                // confirmationDialog presented from this panel never came up,
                // which left deletion unreachable. The card swaps itself for
                // the question instead, so the second tap happens right here.
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(AppleTheme.Typography.microMedium)
                        Text("删除后，该药物的全部服药打卡记录会被一并清除，且无法恢复")
                            .font(AppleTheme.Typography.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Color.red.opacity(0.85))

                    HStack(spacing: 8) {
                        Button(action: {
                            if let med = editing {
                                store.deleteMedication(med)
                            }
                            onDone()
                        }) {
                            Text("确认删除")
                                .font(AppleTheme.Typography.captionMedium)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.red.opacity(0.14)))
                                .overlay(Capsule().strokeBorder(Color.red.opacity(0.32), lineWidth: 0.7))
                                .foregroundStyle(Color.red.opacity(0.9))
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.12)) {
                                showDeleteConfirm = false
                            }
                        }) {
                            Text("取消")
                                .font(AppleTheme.Typography.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.primary.opacity(0.05)))
                                .foregroundStyle(AppleTheme.textSecondary)
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: AppleTheme.radiusCard, style: .continuous)
                        .fill(Color.red.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppleTheme.radiusCard, style: .continuous)
                        .strokeBorder(Color.red.opacity(0.22), lineWidth: 0.8)
                )
            } else {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        showDeleteConfirm = true
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(AppleTheme.Typography.captionMedium)
                        Text("删除此药物")
                            .font(AppleTheme.Typography.subheadlineMedium)
                    }
                    .foregroundStyle(Color.red.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: AppleTheme.radiusCard, style: .continuous)
                            .fill(Color.red.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppleTheme.radiusCard, style: .continuous)
                            .strokeBorder(Color.red.opacity(0.14), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Save Action

    private func save() {
        let freq: Frequency = {
            switch frequencyType {
            case .daily:      return .daily
            case .everyOther: return .everyOtherDay(startDate: everyOtherStart)
            case .weekdays:   return .weekdays(selectedWeekdays)
            }
        }()

        // Two rows can be set to the same time; keep the first of each.
        var seen = Set<TimeOfDay>()
        let timesOfDay = selectedTimes.filter { seen.insert($0).inserted }

        if var med = editing {
            med.name      = name.trimmingCharacters(in: .whitespaces)
            med.dosage    = dosage.trimmingCharacters(in: .whitespaces)
            med.times     = timesOfDay
            med.frequency = freq
            med.notes     = notes.trimmingCharacters(in: .whitespaces)
            store.updateMedication(med)
        } else {
            let med = Medication(
                name:      name.trimmingCharacters(in: .whitespaces),
                dosage:    dosage.trimmingCharacters(in: .whitespaces),
                times:     timesOfDay,
                frequency: freq,
                notes:     notes.trimmingCharacters(in: .whitespaces)
            )
            store.addMedication(med)
        }
        onDone()
    }
}
