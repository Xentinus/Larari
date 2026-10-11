import Foundation
import LarariShared
import Testing
@testable import LarariCore

/// The extension cannot link LarariCore, so LarariShared repeats the level rule; this keeps the two identical.
@Suite("SnapshotExpiry parity")
struct SnapshotExpiryParityTests {
    @Test func matchesExpirationStatusForEveryDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Budapest")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: 23, minute: 30))!
        for offset in -5...20 {
            let date = calendar.date(byAdding: .day, value: offset, to: now)!
            let shared = SnapshotExpiry.level(expiresAt: date, now: now, calendar: calendar,
                                              soonDays: ExpirationStatus.soonDays, criticalDays: ExpirationStatus.criticalDays)
            let core = ExpirationStatus.level(expiresAt: date, now: now, calendar: calendar)
            #expect(shared.rawValue == core.rawValue, "day \(offset)")
        }
        #expect(SnapshotExpiry.level(expiresAt: nil, now: now, calendar: calendar, soonDays: 14, criticalDays: 3) == .none)
    }
}
