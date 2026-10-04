import QtQuick
// Month-grid math is owned by the bar clock hover calendar. This component
// renders it; it never recomputes a date itself.
// Reference: modules/bar/widgets/ClockPopupContent.qml + ClockCalendar.js
import "../bar/widgets/ClockCalendar.js" as Calendar

// Local month view for the control center: a fixed six-row grid on the bar
// module's own date math.
//
// Paging is component-local state, so the owning page never tracks which month
// is open and resetView() is a single call. The weekday strip is Sunday-first,
// matching ClockPopupContent's strip exactly, which is what makes
// firstWeekday()/cellDayOffset() land a date in the right column.
//
// Geometry is a fixed footprint: six rows whatever the month, so the panel that
// hosts it cannot change height as the user pages through.
Item {
    id: root

    // The month on screen. Defaults to today; assign viewYear/viewMonth to open
    // somewhere else, and resetView() to come back.
    property int viewYear: root.today.getFullYear()
    property int viewMonth: root.today.getMonth()
    // Injectable so the today highlight is deterministic under test. Production
    // reads the wall clock once at construction.
    property date today: new Date()

    // Fixed grid shape. A month is five or six rows, so six rows always cover it.
    readonly property int rowCount: 6
    readonly property int columnCount: 7
    readonly property int cellCount: root.rowCount * root.columnCount
    // Sunday-first, identical to the bar clock hover calendar's strip.
    readonly property var weekdayLabels: ["\u65E5", "\u4E00", "\u4E8C", "\u4E09",
        "\u56DB", "\u4E94", "\u516D"]
    // The bar module's own wording, not a second formatter.
    readonly property string monthLabelText: Calendar.monthLabel(root.viewYear, root.viewMonth)
    readonly property bool viewingCurrentMonth: root.viewYear === root.today.getFullYear()
                                                && root.viewMonth === root.today.getMonth()

    readonly property real headerHeight: 26
    readonly property real weekdayHeight: 18
    readonly property real cellHeight: 26
    readonly property real cellSpacing: 2
    readonly property real sectionGap: 8
    readonly property int stepButtonSize: 26
    // Day cells are component details, not a major surface, so they carry the
    // small radius the sharp language allows at this level.
    readonly property real cellRadius: 4
    readonly property real cellWidth: Math.max(0, (root.width - root.cellSpacing
                                                  * (root.columnCount - 1)) / root.columnCount)

    // Paging delegates to the bar module's month arithmetic; nothing here
    // recomputes a year or month boundary.
    function stepMonth(delta) {
        var stepped = Calendar.stepMonth(root.viewYear, root.viewMonth, Number(delta) || 0)
        root.viewYear = stepped.year
        root.viewMonth = stepped.month
    }

    function resetView() {
        root.viewYear = root.today.getFullYear()
        root.viewMonth = root.today.getMonth()
    }

    // A fixed six-row grid: the header, the weekday strip and six rows of cells
    // plus the two inter-section gaps. width/height follow these implicitly, so
    // the calendar keeps one footprint whatever the month.
    implicitWidth: 260
    implicitHeight: root.headerHeight + root.weekdayHeight
            + root.rowCount * root.cellHeight + root.cellSpacing * (root.rowCount - 1)
            + root.sectionGap * 2

    Column {
        id: calendarColumn
        width: root.width
        spacing: root.sectionGap

        // Month label between two square step buttons.
        Item {
            id: headerRow
            width: parent.width
            height: root.headerHeight

            // The label takes the accent while the view is off the current
            // month, so a paged-away grid says so.
            Text {
                id: monthLabel
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: root.stepButtonSize * 2 + 8
                anchors.verticalCenter: parent.verticalCenter
                text: root.monthLabelText
                color: root.viewingCurrentMonth ? LazerTheme.textPrimary : LazerTheme.settingsAccent
                font.pixelSize: 13
                elide: Text.ElideRight

                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }

            // Previous month. Square button, geometric chevron glyph, and the
            // same hover/click treatment as the settings controls.
            Rectangle {
                id: previousButton
                anchors.right: nextButton.left
                anchors.verticalCenter: parent.verticalCenter
                width: root.stepButtonSize
                height: root.stepButtonSize
                radius: 0
                color: previousHover.hovered ? LazerTheme.settingsResetSurfaceHover
                                             : LazerTheme.settingsResetSurface
                border.width: activeFocus ? 1 : 0
                border.color: LazerTheme.focusRing
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "上个月"
                readonly property Item glyphItem: previousGlyph

                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                Image {
                    id: previousGlyph
                    anchors.fill: parent
                    anchors.margins: 6
                    source: "icons/chevron-left.svg"
                    fillMode: Image.PreserveAspectFit
                }

                HoverHandler { id: previousHover }

                TapHandler { onTapped: root.stepMonth(-1) }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                            || event.key === Qt.Key_Space) {
                        root.stepMonth(-1)
                        event.accepted = true
                    }
                }
            }

            // Next month. Mirrors the previous button exactly.
            Rectangle {
                id: nextButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: root.stepButtonSize
                height: root.stepButtonSize
                radius: 0
                color: nextHover.hovered ? LazerTheme.settingsResetSurfaceHover
                                         : LazerTheme.settingsResetSurface
                border.width: activeFocus ? 1 : 0
                border.color: LazerTheme.focusRing
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "下个月"
                readonly property Item glyphItem: nextGlyph

                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                Image {
                    id: nextGlyph
                    anchors.fill: parent
                    anchors.margins: 6
                    source: "icons/chevron-right.svg"
                    fillMode: Image.PreserveAspectFit
                }

                HoverHandler { id: nextHover }

                TapHandler { onTapped: root.stepMonth(1) }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                            || event.key === Qt.Key_Space) {
                        root.stepMonth(1)
                        event.accepted = true
                    }
                }
            }
        }

        // Weekday strip, Sunday first.
        Item {
            id: weekdayRow
            width: parent.width
            height: root.weekdayHeight

            Repeater {
                model: root.weekdayLabels

                Text {
                    required property var modelData

                    width: root.columnCount > 0 ? weekdayRow.width / root.columnCount : 0
                    height: weekdayRow.height
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData
                    color: LazerTheme.textMuted
                    font.pixelSize: 11
                }
            }
        }

        // Day grid: six rows, so every month keeps the same footprint. Cell
        // geometry comes from the bar module; this only decides how a date is
        // painted.
        Grid {
            id: dayGrid
            width: parent.width
            columns: root.columnCount
            spacing: root.cellSpacing

            Repeater {
                model: root.cellCount

                delegate: Rectangle {
                    id: dayCell
                    required property int index

                    // Exposed so the grid's own contract is assertable from
                    // outside the component instead of being re-derived.
                    readonly property int cellIndex: index
                    readonly property int dayOffset: Calendar.cellDayOffset(
                        index, root.viewYear, root.viewMonth)
                    readonly property bool inMonth: Calendar.cellInMonth(
                        index, root.viewYear, root.viewMonth)
                    readonly property bool isToday: Calendar.isTodayCell(
                        index, root.viewYear, root.viewMonth, root.today)

                    width: root.cellWidth
                    height: root.cellHeight
                    radius: root.cellRadius
                    color: isToday ? LazerTheme.activeFill : "transparent"
                    border.width: isToday ? 1 : 0
                    border.color: LazerTheme.osuGreen

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    // A leading/trailing cell is left empty rather than filled
                    // with the neighbouring month's numbers, so the in-month set
                    // is exactly what the grid says it is.
                    Text {
                        id: dayNumber
                        anchors.centerIn: parent
                        width: parent.width
                        text: dayCell.inMonth ? String(dayCell.dayOffset) : ""
                        color: dayCell.isToday ? LazerTheme.osuGreen : LazerTheme.textPrimary
                        opacity: dayCell.inMonth ? (dayCell.isToday ? 1 : 0.85) : 0
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 12

                        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
                    }
                }
            }
        }
    }

    // --- Test and host seams ---

    readonly property Item gridItem: dayGrid
    readonly property Item previousButtonItem: previousButton
    readonly property Item nextButtonItem: nextButton
    readonly property Item monthLabelItem: monthLabel
}