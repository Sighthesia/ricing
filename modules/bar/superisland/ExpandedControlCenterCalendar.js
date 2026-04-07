.pragma library

var _monthGridCellCount = 42

function _asDate(value) {
    if (value instanceof Date)
        return new Date(value.getFullYear(), value.getMonth(), value.getDate())

    return new Date()
}

function _sameDay(left, right) {
    return left.getFullYear() === right.getFullYear()
        && left.getMonth() === right.getMonth()
        && left.getDate() === right.getDate()
}

function buildMonthCells(monthAnchor, todayValue) {
    var anchor = _asDate(monthAnchor)
    var today = _asDate(todayValue)
    var firstDay = new Date(anchor.getFullYear(), anchor.getMonth(), 1)
    var firstWeekday = (firstDay.getDay() + 6) % 7
    var firstCellDate = new Date(firstDay.getFullYear(), firstDay.getMonth(), 1 - firstWeekday)
    var cells = []

    for (var index = 0; index < _monthGridCellCount; index++) {
        var cellDate = new Date(firstCellDate.getFullYear(), firstCellDate.getMonth(), firstCellDate.getDate() + index)
        cells.push({
            day: cellDate.getDate(),
            currentMonth: cellDate.getMonth() === anchor.getMonth(),
            isToday: _sameDay(cellDate, today),
            weekend: cellDate.getDay() === 0 || cellDate.getDay() === 6
        })
    }

    return cells
}

function weekdayLabel(dateValue) {
    var labels = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    var date = _asDate(dateValue)
    return labels[date.getDay()] || ""
}
