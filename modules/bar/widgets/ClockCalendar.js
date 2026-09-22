.pragma library

// Month-grid math for the clock hover calendar, ported from the pre-lazer
// BarCalendarPopup.qml cell formulas. Pure functions so the grid stays
// testable without instantiating QML.
function daysInMonth(year, month) {
    return new Date(year, month + 1, 0).getDate()
}

function firstWeekday(year, month) {
    return new Date(year, month, 1).getDay()
}

function cellDayOffset(cellIndex, year, month) {
    return cellIndex - firstWeekday(year, month) + 1
}

function cellInMonth(cellIndex, year, month) {
    var offset = cellDayOffset(cellIndex, year, month)
    return offset >= 1 && offset <= daysInMonth(year, month)
}

function isTodayCell(cellIndex, year, month, today) {
    var now = today || new Date()
    if (year !== now.getFullYear() || month !== now.getMonth())
        return false
    if (!cellInMonth(cellIndex, year, month))
        return false
    return cellDayOffset(cellIndex, year, month) === now.getDate()
}

function stepMonth(year, month, delta) {
    var stepped = new Date(year, month + delta, 1)
    return { year: stepped.getFullYear(), month: stepped.getMonth() }
}

function monthLabel(year, month) {
    return year + " 年 " + (month + 1) + " 月"
}
