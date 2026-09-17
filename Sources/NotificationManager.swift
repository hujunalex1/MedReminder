import Foundation
import UserNotifications

/// Manages system notification scheduling, permissions, and action handling.
///
/// Communication with `MedicationStore` is done via Foundation
/// `NotificationCenter` to avoid cross-actor reference issues.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    // Foundation notification names for inter-component communication
    static let doseTakenNotification  = Notification.Name("MedReminder.doseTaken")
    static let doseSnoozeNotification = Notification.Name("MedReminder.doseSnooze")

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

    /// Re-schedules all pending notifications for today based on current medications.
    func scheduleNotifications(for medications: [Medication]) {
        center.removeAllPendingNotificationRequests()

        let today = Date()
        for med in medications where med.isActive && med.frequency.isActiveOn(date: today) {
            for time in med.times {
                guard time.dateToday() > Date() else { continue } // only future
                scheduleOne(medication: med, time: time)
            }
        }
    }

    private func scheduleOne(medication med: Medication, time: TimeOfDay) {
        let content = UNMutableNotificationContent()
        content.title    = "服药提醒"
        content.subtitle = med.name
        
        let details = [med.dosage, med.notes].filter { !$0.isEmpty }.joined(separator: " · ")
        content.body = details.isEmpty ? "已到预定服药时间" : details
        
        content.sound = .default
        content.categoryIdentifier = "MED_REMINDER"
        content.userInfo = [
            "medicationId": med.id.uuidString,
            "hour": time.hour,
            "minute": time.minute
        ]

        var dc = DateComponents()
        dc.hour   = time.hour
        dc.minute = time.minute

        addAttachment(to: content)

        let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
        let requestId = "\(med.id.uuidString)-\(time.formatted)"
        let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)
        center.add(request)
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

    /// Triggers an immediate test notification (after 0.5 seconds) with standard Apple Health formatting.
    func sendTestNotification() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            guard granted else {
                print("⚠️ Notification permission not granted: \(String(describing: error))")
                return
            }
            let content = UNMutableNotificationContent()
            content.title    = "服药提醒"
            content.subtitle = "阿莫西林胶囊"
            content.body     = "500mg · 饭后温水送服"
            content.sound    = .default
            content.categoryIdentifier = "MED_REMINDER"
            content.userInfo = [
                "medicationId": UUID().uuidString,
                "hour": Calendar.current.component(.hour, from: Date()),
                "minute": Calendar.current.component(.minute, from: Date())
            ]
            self.addAttachment(to: content)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
            let request = UNNotificationRequest(identifier: "test-\(UUID().uuidString)", content: content, trigger: trigger)
            self.center.add(request) { err in
                if let err = err {
                    print("⚠️ Failed to add notification request: \(err)")
                } else {
                    print("✅ Test notification request added successfully")
                }
            }
        }
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

        switch response.actionIdentifier {
        case "TAKEN", UNNotificationDefaultActionIdentifier:
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: Self.doseTakenNotification,
                    object: nil,
                    userInfo: [
                        "medicationId": medId,
                        "scheduledTime": time.dateToday()
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
