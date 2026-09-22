import QtQuick
import QtTest
import "../../modules/bar/widgets/ClockCalendar.js" as Calendar
import "../../modules/bar" as Bar

// Verify the clock hover calendar: pure month-grid math plus the popup
// action section contract (clock kind renders, others stay hidden).
Item {
    id: root
    width: 400
    height: 800

    Component { id: actionsComp; Bar.BarPopupActions {} }

    function findByName(item, name) {
        if (!item)
            return null
        if (item.objectName === name)
            return item
        var kids = item.children
        if (kids) {
            for (var i = 0; i < kids.length; i++) {
                var found = findByName(kids[i], name)
                if (found)
                    return found
            }
        }
        return null
    }

    TestCase {
        name: "ClockCalendar"
        function test_februaryLeapYear() {
            compare(Calendar.daysInMonth(2024, 1), 29)
            compare(Calendar.daysInMonth(2023, 1), 28)
            compare(Calendar.daysInMonth(2026, 0), 31)
            compare(Calendar.daysInMonth(2026, 8), 30)
        }
        function test_firstWeekdayKnownDates() {
            // 2026-09-01 is a Tuesday.
            compare(Calendar.firstWeekday(2026, 8), 2)
            // 2026-02-01 is a Sunday.
            compare(Calendar.firstWeekday(2026, 1), 0)
        }
        function test_september2026Grid() {
            // Sept 2026: 30 days, starts Tuesday -> cell 2 holds the 1st.
            compare(Calendar.cellDayOffset(2, 2026, 8), 1)
            compare(Calendar.cellDayOffset(31, 2026, 8), 30)
            verify(Calendar.cellInMonth(2, 2026, 8))
            verify(Calendar.cellInMonth(31, 2026, 8))
            verify(!Calendar.cellInMonth(0, 2026, 8))
            verify(!Calendar.cellInMonth(1, 2026, 8))
            verify(!Calendar.cellInMonth(32, 2026, 8))
        }
        function test_todayFlag() {
            var today = new Date(2026, 8, 22)
            // Sept 22 2026: offset 22 -> cell index 22 + 2 - 1 = 23.
            verify(Calendar.isTodayCell(23, 2026, 8, today))
            verify(!Calendar.isTodayCell(24, 2026, 8, today))
            // Same cell number in another month is not today.
            verify(!Calendar.isTodayCell(23, 2026, 7, today))
        }
        function test_stepMonthRollover() {
            var next = Calendar.stepMonth(2026, 11, 1)
            compare(next.year, 2027)
            compare(next.month, 0)
            var prev = Calendar.stepMonth(2026, 0, -1)
            compare(prev.year, 2025)
            compare(prev.month, 11)
            compare(Calendar.monthLabel(2026, 8), "2026 年 9 月")
        }
        function test_clockSectionContract() {
            var actions = actionsComp.createObject(root, { actionKind: "clock" })
            verify(actions !== null)
            var clock = findByName(actions, "clockContent")
            verify(clock !== null)
            verify(clock.visible)
            verify(actions.implicitHeight > 100)
            actions.actionKind = "volume"
            verify(!clock.visible)
            actions.destroy()
        }
    }
}
