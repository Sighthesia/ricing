import QtQuick
import "../../lazerbar"
import "ClockCalendar.js" as Calendar
import "../../../services" as Services

// Clock hover card body: live rolling HH:MM:SS above the ported month
// calendar. Self-sufficient (own 1s clock); the host only toggles section
// visibility, so no intent churn is needed for ticking seconds.
Item {
    id: root

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    property date now: new Date()

    function resetView() {
        var today = new Date()
        root.viewYear = today.getFullYear()
        root.viewMonth = today.getMonth()
    }

    implicitWidth: calendarColumn.implicitWidth
    // Explicit measure: positioners (Row/Grid/Column) expose read-only
    // implicit sizes driven only by unanchored children, so the fixed rows
    // and the delegate-measured grid are summed here directly.
    implicitHeight: timePart.implicitHeight + headerRow.height + weekdayRow.height
            + dayGrid.implicitHeight + calendarColumn.spacing * 3
    height: implicitHeight

    // Tick every second so the rolling seconds track wall time.
    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Column {
        id: calendarColumn
        width: parent.width
        spacing: 10

        // Live time with rolling seconds, larger than the bar readout.
        RollingClockTime {
            id: timePart
            anchors.horizontalCenter: parent.horizontalCenter
            currentTime: root.now
            showSeconds: true
            digitPixelSize: 20
            digitFontFamily: "monospace"
            digitWeight: Font.Bold
            digitColor: LazerTheme.textPrimary
            mutedDigitColor: LazerTheme.textMuted
            separatorColor: LazerTheme.textPrimary
            hourTransitionDuration: MotionTokens.clockHourFlip
            minuteTransitionDuration: MotionTokens.clockMinuteFlip
            secondTransitionDuration: MotionTokens.clockSecondFlip
            transitionEasing: MotionTokens.clockFlipEasing
        }

        // Header: month label between two square step buttons.
        Row {
            id: headerRow
            width: parent.width
            height: 26

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 60
                // Month and weekday names come from the SAME locale the rest of
                // the interface is in, not from the process locale: a user who
                // picked English in settings should not get Chinese weekday
                // glyphs because their ambient locale is zh_CN.
                text: Services.Tr.q("calendar.month", {
                    year: root.viewYear,
                    month: root.viewMonth + 1,
                    monthName: new Date(root.viewYear, root.viewMonth, 1)
                        .toLocaleString(Qt.locale(Services.Tr.qtLocaleName), "MMMM")
                })
                color: LazerTheme.textPrimary
                font.pixelSize: 13
            }

            // Prev / next month squares; direction triangles stay sharp.
            Repeater {
                model: [
                    { delta: -1, glyph: "\u2039" },
                    { delta: 1, glyph: "\u203A" },
                ]

                delegate: Rectangle {
                    id: stepButton

                    required property var modelData

                    anchors.verticalCenter: parent.verticalCenter
                    x: stepButton.modelData.delta < 0 ? parent.width - 56 : parent.width - 26
                    width: 26
                    height: 26
                    radius: 5
                    color: stepHover.hovered ? LazerTheme.settingsResetSurfaceHover
                                             : LazerTheme.settingsResetSurface

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: stepButton.modelData.glyph
                        color: LazerTheme.textPrimary
                        font.pixelSize: 16
                    }

                    HoverHandler {
                        id: stepHover
                    }

                    TapHandler {
                        onTapped: {
                            var stepped = Calendar.stepMonth(root.viewYear, root.viewMonth,
                                                             stepButton.modelData.delta)
                            root.viewYear = stepped.year
                            root.viewMonth = stepped.month
                        }
                    }
                }
            }
        }

        // Weekday strip.
        Row {
            id: weekdayRow
            width: parent.width
            height: 18
            spacing: 0

            Repeater {
                // Sunday-first strip, named by the interface language rather than
                // by one language's characters.
                model: {
                    var strip = []
                    for (var day = 0; day < 7; day++)
                        strip.push(new Date(2024, 0, 7 + day)
                            .toLocaleString(Qt.locale(Services.Tr.qtLocaleName), "ddd"))
                    return strip
                }

                Text {
                    required property var modelData

                    width: parent.width / 7
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: LazerTheme.textMuted
                    font.pixelSize: 11
                }
            }
        }

        // Day grid, six rows so every month keeps the same footprint.
        // Delegates carry implicitHeight so the grid measures itself even
        // before layout runs; the total stays 6 rows x 28 plus spacing.
        Grid {
            id: dayGrid
            width: parent.width
            columns: 7
            spacing: 2

            Repeater {
                model: 42

                delegate: Rectangle {
                    required property int index

                    readonly property int dayOffset: Calendar.cellDayOffset(
                        index, root.viewYear, root.viewMonth)
                    readonly property bool inMonth: Calendar.cellInMonth(
                        index, root.viewYear, root.viewMonth)
                    readonly property bool isToday: Calendar.isTodayCell(
                        index, root.viewYear, root.viewMonth)

                    width: (parent.width - 12) / 7
                    height: 28
                    implicitHeight: 28
                    radius: 4
                    color: isToday ? LazerTheme.activeFill : "transparent"
                    border.width: isToday ? 1 : 0
                    border.color: LazerTheme.osuGreen

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

                    Text {
                        anchors.centerIn: parent
                        text: parent.inMonth ? String(parent.dayOffset) : ""
                        color: parent.isToday ? LazerTheme.osuGreen : LazerTheme.textPrimary
                        opacity: parent.isToday ? 1 : 0.85
                        font.pixelSize: 12
                    }
                }
            }
        }
    }
}
