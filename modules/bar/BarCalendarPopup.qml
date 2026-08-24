import QtQuick
import "../lazerbar"

// Compact month calendar for the clock hover popup: sharp grid, accent
// block on today, geometric month stepping.
Rectangle {
    id: root

    implicitWidth: 264
    implicitHeight: 288
    // Explicit dims keep the hosting Loader from stretching the surface.
    width: implicitWidth
    height: implicitHeight
    radius: 10
    color: LazerTheme.popupBackground
    border.width: 1
    border.color: LazerTheme.popupBorder

    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    function stepMonth(delta) {
        var date = new Date(viewYear, viewMonth + delta, 1)
        viewYear = date.getFullYear()
        viewMonth = date.getMonth()
    }

    Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // Header: month label between two square step buttons.
        Row {
            width: parent.width
            height: 26

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 60
                text: root.viewYear + " \u5E74 " + (root.viewMonth + 1) + " \u6708"
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
                        onTapped: root.stepMonth(stepButton.modelData.delta)
                    }
                }
            }
        }

        // Weekday strip.
        Row {
            width: parent.width
            height: 18
            spacing: 0

            Repeater {
                model: ["\u65E5", "\u4E00", "\u4E8C", "\u4E09", "\u56DB", "\u4E94", "\u516D"]

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
        Grid {
            width: parent.width
            columns: 7
            spacing: 2

            Repeater {
                model: 42

                delegate: Rectangle {
                    required property int index

                    readonly property int firstWeekday: new Date(root.viewYear, root.viewMonth, 1).getDay()
                    readonly property int dayOffset: index - firstWeekday + 1
                    readonly property bool inMonth: dayOffset >= 1 && dayOffset <=
                            new Date(root.viewYear, root.viewMonth + 1, 0).getDate()
                    readonly property bool isToday: inMonth && dayOffset === new Date().getDate()
                            && root.viewMonth === new Date().getMonth()
                            && root.viewYear === new Date().getFullYear()

                    width: (parent.width - 12) / 7
                    height: 28
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
