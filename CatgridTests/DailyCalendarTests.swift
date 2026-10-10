import NonogramKit
import XCTest
@testable import Catgrid

@MainActor
final class DailyCalendarTests: XCTestCase {
    func testWeekStartsOnMonday() {
        // 10 Ekim 2026 cumartesi
        let saturday = DayKey(year: 2026, month: 10, day: 10)
        XCTAssertEqual(AppModel.weekdayIndex(of: saturday), 5)
        XCTAssertEqual(AppModel.weekdayIndex(of: DayKey(year: 2026, month: 10, day: 5)), 0)
        XCTAssertEqual(AppModel.dayKey(dayNumber: saturday.dayNumber), saturday)
    }

    func testFullWeekNeedsAllSevenDays() {
        let monday = DayKey(year: 2026, month: 10, day: 5)
        let week = (0..<7).map { AppModel.dayKey(dayNumber: monday.dayNumber + $0) }
        XCTAssertEqual(week.last, DayKey(year: 2026, month: 10, day: 11))
        XCTAssertEqual(AppModel.fullWeeks(in: Set(week)), 1)
        XCTAssertEqual(AppModel.fullWeeks(in: Set(week.dropLast())), 0)
        // Haftaya yayılan 7 gün (çarşambadan çarşambaya) sayılmaz
        let shifted = (2..<9).map { AppModel.dayKey(dayNumber: monday.dayNumber + $0) }
        XCTAssertEqual(AppModel.fullWeeks(in: Set(shifted)), 0)
    }

    func testMonthCellsStartOnMonday() {
        // Ekim 2026 perşembe başlar: önünde 3 boş hücre
        let cells = DailyHubView.cells(forMonth: 2026 * 12 + 9)
        XCTAssertEqual(cells.prefix(3).filter { $0 == nil }.count, 3)
        XCTAssertEqual(cells[3], DayKey(year: 2026, month: 10, day: 1))
        XCTAssertEqual(cells.compactMap { $0 }.count, 31)
    }
}
