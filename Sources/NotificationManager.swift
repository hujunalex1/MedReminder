import Foundation
@preconcurrency import UserNotifications

/// Manages system notification scheduling, permissions, and action handling.
///
/// Communication with `MedicationStore` is done via Foundation
/// `NotificationCenter` to avoid cross-actor reference issues.
final class NotificationManager: NSObject, @unchecked Sendable, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    // Foundation notification names for inter-component communication
    static let doseTakenNotification  = Notification.Name("MedReminder.doseTaken")

    // MARK: - Init

    private override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Permission & Category

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            print(granted ? "✅ 通知权限已获取" : "⚠️ 通知权限被拒绝")
        }
        registerCategories()
    }

    private func registerCategories() {
        let takenAction = UNNotificationAction(
            identifier: "TAKEN", title: "标记已服用", options: []
        )
        let snoozeAction = UNNotificationAction(
            identifier: "SNOOZE", title: "10 分钟后提醒", options: []
        )
        let category = UNNotificationCategory(
            identifier: "MED_REMINDER",
            actions: [takenAction, snoozeAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])
    }

    // MARK: - Schedule

    /// Identifier prefixes: dose- marks the reminders we rebuild on every
    /// schedule, snooze- marks user-triggered re-reminders, which are left
    /// alone as long as their medication still exists.
    private static let dosePrefix = "dose-"
    private static let snoozePrefix = "snooze-"

    /// The system caps pending requests at 64 per app; repeating triggers count
    /// as one each. Reserve 8 for snoozes, leave the rest to dose reminders.
    private static let maxPendingDoses = 56

    /// `.everyOtherDay` cannot be a repeating calendar trigger, so it is
    /// pre-scheduled as one-shot triggers for the next 30 days and rolled
    /// forward on every launch / day change. The effective horizon may be
    /// shorter than 30 days once `maxPendingDoses` trims the tail.
    private static let rollingWindowDays = 30

    /// Bumped on every scheduling request; stale async results are discarded.
    /// Main thread only.
    private var scheduleGeneration = 0

    /// Rebuilds every dose reminder.
    ///
    /// - `.daily` / `.weekdays`: one repeating calendar trigger each — a single
    ///   request covers all future occurrences and fires with the app closed.
    /// - `.everyOtherDay`: a rolling window of one-shot triggers.
    /// - Removes every request we own — all dose- reminders are rebuilt — plus
    ///   `snooze-` requests whose medication was deleted or deactivated. Live
    ///   snoozes are preserved.
    func scheduleNotifications(for medications: [Medication]) {
        scheduleGeneration += 1
        let generation = scheduleGeneration
        let planned = plan(for: medications)

        center.getPendingNotificationRequests { [weak self] pending in
            guard let self else { return }
            let liveIDs = Set(medications.filter(\.isActive).map { $0.id.uuidString })

            // NOTE: filter by identifier only. Snooze content is a mutableCopy of
            // the original and therefore also carries "medicationId" — filtering
            // by userInfo would delete live snoozes too.
            //
            // Anything without the snooze- prefix is ours to rebuild: current
            // dose- reminders plus legacy requests from before the prefix
            // existed, which would otherwise linger and fire alongside their
            // replacement.
            let stale = pending.filter { request in
                if !request.identifier.hasPrefix(Self.snoozePrefix) { return true }
                if let id = request.content.userInfo["medicationId"] as? String {
                    return !liveIDs.contains(id)
                }
                return false
            }.map(\.identifier)

            DispatchQueue.main.async {
                // A newer schedule superseded this one (rapid add/edit): drop it.
                // remove + add run in one main-queue block, so blocks never interleave.
                guard generation == self.scheduleGeneration else { return }
                if !stale.isEmpty {
                    self.center.removePendingNotificationRequests(withIdentifiers: stale)
                }
                for request in planned { self.center.add(request) }
                print("🔔 已排程 \(planned.count) 条服药提醒（清理 \(stale.count) 条旧提醒）")
            }
        }
    }

    // MARK: - Planning

    /// A planned reminder plus its sort key.
    private struct PlannedRequest {
        let request: UNNotificationRequest

        var sortDate: Date {
            (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
        }
    }

    /// Translates medications into notification requests, then applies the
    /// system cap.
    ///
    /// Repeating triggers are reserved unconditionally: they cover an unbounded
    /// future and cost one slot each. A flat earliest-first trim would instead
    /// permanently starve a Monday-only reminder that sorts behind a handful of
    /// one-shots. Remaining slots go to the soonest one-shots.
    private func plan(for medications: [Medication]) -> [UNNotificationRequest] {
        var repeating: [PlannedRequest] = []
        var oneShots: [PlannedRequest] = []

        for med in medications where med.isActive {
            switch med.frequency {
            case .daily:
                for time in med.times {
                    let request = makeRequest(
                        med: med, time: time,
                        identifier: "\(Self.dosePrefix)\(med.id.uuidString)-\(DoseSchedule.timeStamp(for: time))-d",
                        components: DoseSchedule.dailyComponents(for: time),
                        repeats: true
                    )
                    repeating.append(PlannedRequest(request: request))
                }

            case .weekdays(let isoDays):
                for time in med.times {
                    for iso in isoDays.sorted() {
                        let request = makeRequest(
                            med: med, time: time,
                            identifier: "\(Self.dosePrefix)\(med.id.uuidString)-\(DoseSchedule.timeStamp(for: time))-w\(iso)",
                            components: DoseSchedule.weeklyComponents(for: time, isoWeekday: iso),
                            repeats: true
                        )
                        repeating.append(PlannedRequest(request: request))
                    }
                }

            case .everyOtherDay:
                let occurrences = DoseSchedule.upcomingOccurrences(
                    frequency: med.frequency, times: med.times,
                    from: Date(), days: Self.rollingWindowDays
                )
                for occ in occurrences {
                    let stamp = DoseSchedule.dayStamp(for: occ.fireDate)
                    let request = makeRequest(
                        med: med, time: occ.time,
                        identifier: "\(Self.dosePrefix)\(med.id.uuidString)-\(stamp)-\(DoseSchedule.timeStamp(for: occ.time))",
                        components: Calendar.current.dateComponents(
                            [.year, .month, .day, .hour, .minute], from: occ.fireDate
                        ),
                        repeats: false,
                        scheduledTime: occ.fireDate
                    )
                    oneShots.append(PlannedRequest(request: request))
                }
            }
        }

        let budget = Self.maxPendingDoses
        guard repeating.count < budget else {
            print("⚠️ 重复提醒 \(repeating.count) 条已达上限 \(budget)，按最近触发时间截断")
            return repeating.sorted { $0.sortDate < $1.sortDate }
                .prefix(budget).map(\.request)
        }

        let room = budget - repeating.count
        let sortedOneShots = oneShots.sorted { $0.sortDate < $1.sortDate }
        if sortedOneShots.count > room {
            print("⚠️ 待排程 \(repeating.count + sortedOneShots.count) 条超出上限 \(budget)，已保留最近 \(budget) 条")
        }
        return repeating.map(\.request) + sortedOneShots.prefix(room).map(\.request)
    }

    /// Builds one dose reminder request.
    ///
    /// `scheduledTime` is attached for one-shot reminders only, so tapping a
    /// notification delivered late (machine asleep, or opened after midnight)
    /// records the dose against its planned day instead of today.
    private func makeRequest(
        med: Medication,
        time: TimeOfDay,
        identifier: String,
        components: DateComponents,
        repeats: Bool,
        scheduledTime: Date? = nil
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title    = "服药提醒"
        content.subtitle = med.name

        let details = [med.dosage, med.notes].filter { !$0.isEmpty }.joined(separator: " · ")
        content.body = details.isEmpty ? "已到预定服药时间" : details

        content.sound = .default
        content.categoryIdentifier = "MED_REMINDER"

        var userInfo: [String: Any] = [
            "medicationId": med.id.uuidString,
            "hour": time.hour,
            "minute": time.minute
        ]
        if let scheduledTime {
            userInfo["scheduledTime"] = scheduledTime.timeIntervalSince1970
        }
        content.userInfo = userInfo

        addAttachment(to: content)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    /// Schedule a snooze (re-notification) after `delay` seconds.
    private func scheduleSnooze(from content: UNNotificationContent, delay: TimeInterval = 600) {
        let mutable = content.mutableCopy() as! UNMutableNotificationContent
        mutable.title    = "服药提醒 (稍后提醒)"
        mutable.subtitle = content.subtitle
        mutable.body     = content.body
        addAttachment(to: mutable)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: "snooze-\(UUID().uuidString)", content: mutable, trigger: trigger
        )
        center.add(request)
    }

    private func addAttachment(to content: UNMutableNotificationContent) {
        guard let bundleURL = Bundle.main.url(forResource: "notification_icon", withExtension: "png") else { return }
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent("notif_\(UUID().uuidString).png")
        do {
            try FileManager.default.copyItem(at: bundleURL, to: tempFileURL)
            let attachment = try UNNotificationAttachment(identifier: "medIcon", url: tempFileURL, options: nil)
            content.attachments = [attachment]
        } catch {
            print("⚠️ Attachment error: \(error)")
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show notifications even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    /// Handle user-tapped notification actions.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        guard let idStr = userInfo["medicationId"] as? String,
              let medId = UUID(uuidString: idStr),
              let hour   = userInfo["hour"]   as? Int,
              let minute = userInfo["minute"] as? Int else {
            completionHandler()
            return
        }

        let time = TimeOfDay(hour: hour, minute: minute)

        // One-shot reminders carry the planned fire date (epoch); repeating
        // reminders and snoozes have no such key and fall back to today.
        let scheduledTime = (userInfo["scheduledTime"] as? TimeInterval)
            .map { Date(timeIntervalSince1970: $0) } ?? time.dateToday()

        switch response.actionIdentifier {
        case "TAKEN", UNNotificationDefaultActionIdentifier:
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Self.doseTakenNotification,
                    object: nil,
                    userInfo: [
                        "medicationId": medId,
                        "scheduledTime": scheduledTime
                    ]
                )
            }
        case "SNOOZE":
            scheduleSnooze(from: response.notification.request.content)
        default:
            break
        }

        completionHandler()
    }
}
