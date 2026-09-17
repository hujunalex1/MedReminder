import Foundation

/// Pure date math behind notification scheduling.
///
/// Depends on Foundation only — no UserNotifications — so it can be verified
/// with a standalone swiftc driver script, outside the app build.
///
/// Scheduling strategy: `.daily` / `.weekdays` use repeating calendar triggers;
/// `.everyOtherDay` cannot be expressed as one, so it is rolled forward as a
/// window of one-shot triggers.
enum DoseSchedule {

    // MARK: - Weekday conversion

    /// ISO weekday (1 = Monday … 7 = Sunday) → Calendar weekday (1 = Sunday … 7 = Saturday)
    static func calendarWeekday(fromISO iso: Int) -> Int {
        iso == 7 ? 1 : iso + 1
    }

    /// Calendar weekday (1 = Sunday … 7 = Saturday) → ISO weekday (1 = Monday … 7 = Sunday)
    static func isoWeekday(fromCalendar weekday: Int) -> Int {
        weekday == 1 ? 7 : weekday - 1
    }

    // MARK: - Repeating trigger components (daily / weekdays)

    /// Components for "every day at HH:mm", for `UNCalendarNotificationTrigger(repeats: true)`.
    static func dailyComponents(for time: TimeOfDay) -> DateComponents {
        DateComponents(hour: time.hour, minute: time.minute)
    }

    /// Components for "every <isoWeekday> at HH:mm" (`weekday` uses Calendar numbering).
    static func weeklyComponents(for time: TimeOfDay, isoWeekday: Int) -> DateComponents {
        DateComponents(
            hour: time.hour,
            minute: time.minute,
            weekday: calendarWeekday(fromISO: isoWeekday)
        )
    }

    // MARK: - Rolling window (every other day)

    /// A concrete moment a dose is scheduled to happen.
    struct Occurrence {
        let fireDate: Date
        let time: TimeOfDay
    }

    /// Walks `days` calendar days forward from `start` and returns every
    /// occurrence matching `frequency` that is still in the future, ascending.
    ///
    /// Days advance via `Calendar.date(byAdding: .day)` rather than 86400 s
    /// arithmetic: DST transition days are 23 / 25 h long, and adding seconds
    /// drifts by an hour or lands on the wrong calendar day.
    static func upcomingOccurrences(
        frequency: Frequency,
        times: [TimeOfDay],
        from start: Date,
        days: Int,
        calendar: Calendar = .current
    ) -> [Occurrence] {
        guard days > 0 else { return [] }
        let today = calendar.startOfDay(for: start)

        var result: [Occurrence] = []
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  frequency.isActiveOn(date: day, calendar: calendar) else { continue }

            for time in times {
                // A wall-clock time skipped by DST resolves forward instead of returning nil
                guard let fire = calendar.date(
                    bySettingHour: time.hour, minute: time.minute, second: 0, of: day
                ) else { continue }
                guard fire > start else { continue }
                result.append(Occurrence(fireDate: fire, time: time))
            }
        }
        return result.sorted { $0.fireDate < $1.fireDate }
    }

    // MARK: - Identifier fragments

    /// "0800" — identifiers stay colon-free
    static func timeStamp(for time: TimeOfDay) -> String {
        String(format: "%02d%02d", time.hour, time.minute)
    }

    /// "20260918" — built from Calendar components, immune to locale digits
    static func dayStamp(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
