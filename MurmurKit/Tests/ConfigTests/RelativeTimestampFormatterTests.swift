import Foundation
import Testing
@testable import MurmurKit

@Suite("RelativeTimestampFormatter")
struct RelativeTimestampFormatterTests {
    private let formatter = RelativeTimestampFormatter(
        calendar: Calendar(identifier: .gregorian),
        locale: Locale(identifier: "en_US_POSIX")
    )

    /// Helper to construct a Date at a specific local Y-M-D h:m.
    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    @Test("Same day formats as 'Today HH:mm'")
    func sameDay() {
        let now = date(2026, 5, 17, 14, 30)
        let ts = date(2026, 5, 17, 9, 5)
        #expect(formatter.string(from: ts, now: now) == "Today 09:05")
    }

    @Test("Previous day formats as 'Yesterday HH:mm'")
    func yesterday() {
        let now = date(2026, 5, 17, 14, 30)
        let ts = date(2026, 5, 16, 22, 0)
        #expect(formatter.string(from: ts, now: now) == "Yesterday 22:00")
    }

    @Test("2 to 7 days ago formats as 'Nd ago'")
    func daysAgo() {
        let now = date(2026, 5, 17, 14, 30)
        #expect(formatter.string(from: date(2026, 5, 15, 12, 0), now: now) == "2d ago")
        #expect(formatter.string(from: date(2026, 5, 10, 12, 0), now: now) == "7d ago")
    }

    @Test("More than 7 days ago formats as absolute date")
    func absoluteDate() {
        let now = date(2026, 5, 17, 14, 30)
        let ts = date(2026, 4, 1, 9, 0)
        #expect(formatter.string(from: ts, now: now) == "Apr 1, 2026")
    }

    @Test("Future timestamps fall back to absolute formatting")
    func future() {
        let now = date(2026, 5, 17, 14, 30)
        let ts = date(2026, 6, 1, 9, 0)
        #expect(formatter.string(from: ts, now: now) == "Jun 1, 2026")
    }
}
