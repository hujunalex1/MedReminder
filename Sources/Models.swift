import Foundation

// MARK: - TimeOfDay

/// Represents a time of day (hour + minute), independent of any specific date.
struct TimeOfDay: Codable, Hashable, Comparable {
    var hour: Int
    var minute: Int

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }

    /// "08:30"
    var formatted: String {
        String(format: "%02d:%02d", hour, minute)
    }

    /// Returns a `Date` for this time on the calendar day containing `day`.
    func date(on day: Date) -> Date {
        Calendar.current.date(
            bySettingHour: hour, minute: minute, second: 0, of: day
        ) ?? day
    }

    /// Returns a `Date` for this time on today's calendar day.
    func dateToday() -> Date { date(on: Date()) }

    /// Creates a `TimeOfDay` from an arbitrary `Date`.
    static func fromDate(_ date: Date) -> TimeOfDay {
        let c = Calendar.current
        return TimeOfDay(hour: c.component(.hour, from: date),
                         minute: c.component(.minute, from: date))
    }
}

// MARK: - Frequency

/// How often a medication should be taken.
enum Frequency: Codable, Hashable {
    case daily
    case everyOtherDay(startDate: Date)
    /// ISO weekdays: 1 = Monday … 7 = Sunday
    case weekdays(Set<Int>)

    var displayText: String {
        switch self {
        case .daily:
            return "每天"
        case .everyOtherDay:
            return "隔一天"
        case .weekdays(let days):
            let names = ["", "周一", "周二", "周三", "周四", "周五", "周六", "周日"]
            return days.sorted().map { names[$0] }.joined(separator: " ")
        }
    }

    func isActiveOn(date: Date, calendar: Calendar = .current) -> Bool {
        let cal = calendar
        switch self {
        case .daily:
            return true
        case .everyOtherDay(let start):
            let days = cal.dateComponents(
                [.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: date)
            ).day ?? 0
            return days % 2 == 0
        case .weekdays(let activeDays):
            // Calendar weekday: 1 = Sunday … 7 = Saturday
            let weekday = cal.component(.weekday, from: date)
            return activeDays.contains(DoseSchedule.isoWeekday(fromCalendar: weekday))
        }
    }
}

// MARK: - DayPeriod

enum DayPeriod: String, CaseIterable, Comparable {
    case morning = "上午"
    case afternoon = "下午"
    case evening = "晚上"

    static func < (lhs: DayPeriod, rhs: DayPeriod) -> Bool {
        let order: [DayPeriod: Int] = [.morning: 0, .afternoon: 1, .evening: 2]
        return (order[lhs] ?? 0) < (order[rhs] ?? 0)
    }
}

// MARK: - DoseStatus

enum DoseStatus: String, Codable {
    case pending
    case taken
    case skipped
    case missed
}

// MARK: - Medication

struct Medication: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var dosage: String
    var times: [TimeOfDay]
    var frequency: Frequency = .daily
    var notes: String = ""
    var isActive: Bool = true
    /// When the medication was added. Optional so a file written before the
    /// field existed still decodes at all: a missing key fails the whole file
    /// (defaults do not apply when decoding), and `expectsDose` reads nil as
    /// "has always existed" — never as "created now", which would hide the
    /// medication's whole schedule until tomorrow.
    var createdAt: Date? = Date()

    /// Whether a dose at `time` should exist. Times that had already passed
    /// when the medication was added are not doses: adding a medication at
    /// 14:00 with an 08:00 time must not list — or record — a missed 08:00
    /// dose for today. The reminder itself only starts tomorrow anyway.
    func expectsDose(at time: TimeOfDay, on day: Date = Date()) -> Bool {
        time.date(on: day) >= (createdAt ?? .distantPast)
    }
}

// MARK: - DoseRecord

struct DoseRecord: Identifiable, Codable {
    var id = UUID()
    var medicationId: UUID
    var scheduledTime: Date
    var status: DoseStatus = .pending
    /// When the user acted on this dose. Recorded for future adherence /
    /// history features; no UI consumes it yet.
    var actionTime: Date?
}

// MARK: - ScheduledDose (view-model)

/// Combines a `Medication`, its scheduled `TimeOfDay`, and an optional
/// `DoseRecord` for display in the today view.
struct ScheduledDose: Identifiable {
    let medication: Medication
    let time: TimeOfDay
    let record: DoseRecord?

    var id: String { "\(medication.id.uuidString)-\(time.hour)-\(time.minute)" }

    var displayStatus: DoseStatus {
        if let record { return record.status }
        // Auto-detect missed: >1 h past scheduled time with no record — but only
        // for doses the medication was already around for. A time that had
        // already passed when it was added was never a dose, and labelling it
        // missed would be inventing a failure; it stays pending (and therefore
        // actionable) so the dose can still be logged.
        if medication.expectsDose(at: time),
           Date() > time.dateToday().addingTimeInterval(3600) {
            return .missed
        }
        return .pending
    }
}
