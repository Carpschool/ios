import Foundation

enum Fmt {
    static let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    static func schedule(dates: [String], days: [Int]) -> String {
        if !days.isEmpty {
            let d = days.sorted()
            if d == [1, 2, 3, 4, 5] { return "Weekdays" }
            if d.count == 7 { return "Every day" }
            return d.map { dayNames[$0] }.joined(separator: ", ")
        }
        return dates.compactMap { s -> String? in
            guard let date = isoDay.date(from: s) else { return s }
            return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }.joined(separator: ", ")
    }

    static func shortId(_ s: String) -> String {
        String(s.replacingOccurrences(of: "user_", with: "").suffix(5)).uppercased()
    }

    static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let hm: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    static func todayISO() -> String { isoDay.string(from: .now) }

    static func runsToday(dates: [String], days: [Int]) -> Bool {
        let wd = Calendar.current.component(.weekday, from: .now) - 1
        return days.contains(wd) || dates.contains(todayISO())
    }

    /// "07:45" shown in the user's locale (7:45 AM).
    static func clock(_ hhmm: String) -> String {
        guard let d = hm.date(from: hhmm) else { return hhmm }
        return d.formatted(date: .omitted, time: .shortened)
    }

    nonisolated(unsafe) static let isoFull: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func date(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        return isoFull.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    }

    static func ago(_ iso: String?) -> String {
        guard let d = date(iso) else { return "" }
        return d.formatted(.relative(presentation: .named))
    }

    static func distance(_ m: Double) -> String {
        Measurement(value: m, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road))
    }
}

extension Commute {
    var schedule: String { Fmt.schedule(dates: dates, days: days) }
    var window: String { "\(Fmt.clock(startTime))–\(Fmt.clock(endTime))" }
}

extension Drive {
    var schedule: String { Fmt.schedule(dates: dates, days: days) }
    var window: String { "\(Fmt.clock(startTime))–\(Fmt.clock(endTime))" }
    var runsToday: Bool { Fmt.runsToday(dates: dates, days: days) }
    var activeRiders: [Passenger] { passengers.filter { $0.status != "left" }.sorted { $0.time < $1.time } }
    var isUpcoming: Bool { status == "active" && passengers.contains { $0.status == "locked" || $0.status == "boarded" } }
}
