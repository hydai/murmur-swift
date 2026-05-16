import Foundation

/// Formats history entry timestamps in the style used by the Rust history
/// panel: `"Today HH:mm"`, `"Yesterday HH:mm"`, `"{N}d ago"` for the last
/// week, then absolute dates beyond that.
public struct RelativeTimestampFormatter: Sendable {
    private let calendar: Calendar
    private let timeFormatter: DateFormatter
    private let dateFormatter: DateFormatter

    public init(calendar: Calendar = .current, locale: Locale = .current) {
        self.calendar = calendar
        self.timeFormatter = DateFormatter()
        self.timeFormatter.locale = locale
        self.timeFormatter.dateFormat = "HH:mm"
        self.dateFormatter = DateFormatter()
        self.dateFormatter.locale = locale
        self.dateFormatter.dateFormat = "MMM d, yyyy"
    }

    public func string(from timestamp: Date, now: Date = Date()) -> String {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTimestamp = calendar.startOfDay(for: timestamp)
        let daysAgo = calendar.dateComponents([.day], from: startOfTimestamp, to: startOfToday).day ?? 0

        switch daysAgo {
        case 0:    return "Today \(timeFormatter.string(from: timestamp))"
        case 1:    return "Yesterday \(timeFormatter.string(from: timestamp))"
        case 2...7: return "\(daysAgo)d ago"
        default:   return dateFormatter.string(from: timestamp)
        }
    }
}
