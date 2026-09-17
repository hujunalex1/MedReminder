import SwiftUI

/// Central, observable state for all medications and dose records.
@Observable
@MainActor
final class MedicationStore {

    var medications: [Medication] = []
    var records: [DoseRecord] = []

    private var timer: Timer?

    // MARK: - Init

    init() {
        medications = DataStore.loadMedications()
        records     = DataStore.loadRecords()
        cleanupOldRecords()
        startPeriodicCheck()
        observeNotificationActions()
    }

    // MARK: - Today helpers

    /// All scheduled doses for today, sorted by time.
    var todayDoses: [ScheduledDose] {
        let today = Date()
        let cal = Calendar.current
        var doses: [ScheduledDose] = []

        for med in medications where med.isActive && med.frequency.isActiveOn(date: today) {
            for time in med.times {
                let scheduled = time.dateToday()
                let record = records.first {
                    $0.medicationId == med.id
                    && cal.isDate($0.scheduledTime, equalTo: scheduled, toGranularity: .minute)
                }
                doses.append(ScheduledDose(medication: med, time: time, record: record))
            }
        }
        return doses.sorted { $0.time < $1.time }
    }

    /// Today's doses grouped by period: 上午 / 下午 / 晚上.
    var todayDosesByTime: [(period: DayPeriod, doses: [ScheduledDose])] {
        let grouped = Dictionary(grouping: todayDoses) { dose -> DayPeriod in
            let h = dose.time.hour
            if h < 12 { return .morning }
            if h < 18 { return .afternoon }
            return .evening
        }
        return grouped
            .sorted { $0.key < $1.key }
            .map { (period: $0.key, doses: $0.value.sorted { $0.time < $1.time }) }
    }

    var todayProgress: (completed: Int, total: Int) {
        let all = todayDoses
        let done = all.filter { $0.displayStatus == .taken || $0.displayStatus == .skipped }.count
        return (done, all.count)
    }

    var hasUnfinishedDoses: Bool {
        todayDoses.contains { $0.displayStatus == .pending }
    }

    // MARK: - CRUD

    func addMedication(_ med: Medication) {
        medications.append(med)
        persist()
        reschedule()
    }

    func updateMedication(_ med: Medication) {
        guard let i = medications.firstIndex(where: { $0.id == med.id }) else { return }
        medications[i] = med
        persist()
        reschedule()
    }

    func deleteMedication(_ med: Medication) {
        medications.removeAll  { $0.id == med.id }
        records.removeAll      { $0.medicationId == med.id }
        persist()
        reschedule()
    }

    func toggleMedication(_ med: Medication) {
        guard let i = medications.firstIndex(where: { $0.id == med.id }) else { return }
        medications[i].isActive.toggle()
        persist()
        reschedule()
    }

    // MARK: - Dose actions

    func markDose(medicationId: UUID, scheduledTime: Date, status: DoseStatus) {
        let cal = Calendar.current
        if let i = records.firstIndex(where: {
            $0.medicationId == medicationId
            && cal.isDate($0.scheduledTime, equalTo: scheduledTime, toGranularity: .minute)
        }) {
            records[i].status     = status
            records[i].actionTime = Date()
        } else {
            var rec = DoseRecord(medicationId: medicationId, scheduledTime: scheduledTime)
            rec.status     = status
            rec.actionTime = Date()
            records.append(rec)
        }
        persist()
    }

    func revokeDose(medicationId: UUID, scheduledTime: Date) {
        let cal = Calendar.current
        records.removeAll {
            $0.medicationId == medicationId
            && cal.isDate($0.scheduledTime, equalTo: scheduledTime, toGranularity: .minute)
        }
        persist()
    }

    // MARK: - Private helpers

    private func persist() {
        DataStore.saveMedications(medications)
        DataStore.saveRecords(records)
    }

    private func reschedule() {
        NotificationManager.shared.scheduleNotifications(for: medications)
    }

    /// Remove records older than 30 days.
    private func cleanupOldRecords() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let before = records.count
        records.removeAll { $0.scheduledTime < cutoff }
        if records.count != before { DataStore.saveRecords(records) }
    }

    /// Every 60 s, auto-mark overdue pending doses as missed.
    private func startPeriodicCheck() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkMissedDoses() }
        }
    }

    private func checkMissedDoses() {
        let now = Date()
        let cal = Calendar.current

        for med in medications where med.isActive && med.frequency.isActiveOn(date: now) {
            for time in med.times {
                let scheduled = time.dateToday()
                guard now > scheduled.addingTimeInterval(3600) else { continue }

                let alreadyHandled = records.contains {
                    $0.medicationId == med.id
                    && cal.isDate($0.scheduledTime, equalTo: scheduled, toGranularity: .minute)
                    && $0.status != .pending
                }
                if !alreadyHandled {
                    markDose(medicationId: med.id, scheduledTime: scheduled, status: .missed)
                }
            }
        }
    }

    /// Listen for "dose taken" from the notification delegate.
    private func observeNotificationActions() {
        NotificationCenter.default.addObserver(
            forName: NotificationManager.doseTakenNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let medId = note.userInfo?["medicationId"] as? UUID,
                  let time  = note.userInfo?["scheduledTime"] as? Date else { return }
            Task { @MainActor in
                self.markDose(medicationId: medId, scheduledTime: time, status: .taken)
            }
        }
    }
}
