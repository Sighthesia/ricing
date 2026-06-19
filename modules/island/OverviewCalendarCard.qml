import QtQuick
import "../bar/MenuVisuals.js" as MenuVisuals
import "../../services" as Services

// Full-width calendar preview card for the overview control-center collage.
// Shows a prominent date column on the left and placeholder event rows on
// the right. Click navigates to calendar detail page. Uses glass layered
// background with gradient and top-edge sheen.
Rectangle {
    id: root

    signal clicked()

    // Fake event placeholders; real calendar integration is out of scope.
    readonly property string dayOfWeek: Qt.formatDate(new Date(), "ddd")
    readonly property string monthDay: Qt.formatDate(new Date(), "MMM d")
    readonly property string dayNumber: Qt.formatDate(new Date(), "d")

    radius: 16
    color: calMouse.containsMouse
        ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.listHoverOpacity)
        : Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)
    border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.4)
    border.width: 1

    Behavior on color {
        ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
    }

    Behavior on border.color {
        ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
    }

    // Subtle gradient overlay for glass depth.
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.03) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // Top-edge glass highlight strip.
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
    }

    // Horizontal split: date column on the left, event list on the right.
    Row {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 20

        // Date column: large day number, month + weekday below.
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Services.FluidText {
                text: root.dayNumber
                color: Services.Color.mOnSurface
                basePixelSize: 34
                font.bold: true
                lineHeight: 0.9
            }

            Services.FluidText {
                text: root.monthDay
                color: Services.Color.mOnSurfaceVariant
                basePixelSize: 11
            }

            Services.FluidText {
                text: root.dayOfWeek
                color: Services.Color.mOnSurfaceVariant
                basePixelSize: 10
                opacity: 0.7
            }
        }

        // Event list with colored indicator bars.
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // Fake event 1: work start — glass chip with subtle highlight.
            Rectangle {
                width: parent.parent.width - parent.parent.width * 0.22
                height: 28
                radius: 8
                color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.10)

                // Event-row glass highlight.
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.06)
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Rectangle {
                        width: 3
                        height: 16
                        radius: 1.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: Services.Color.mPrimary
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Services.FluidText {
                            text: "\u4E0A\u73ED"
                            color: Services.Color.mOnSurface
                            basePixelSize: 10
                            font.bold: true
                        }

                        Services.FluidText {
                            text: "9:00 - 18:00"
                            color: Services.Color.mOnSurfaceVariant
                            basePixelSize: 9
                        }
                    }
                }
            }

            // Fake event 2: team meeting — glass chip with subtle highlight.
            Rectangle {
                width: parent.parent.width - parent.parent.width * 0.22
                height: 28
                radius: 8
                color: Qt.rgba(Services.Color.mTertiary.r, Services.Color.mTertiary.g, Services.Color.mTertiary.b, 0.10)

                // Event-row glass highlight.
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Qt.rgba(1, 1, 1, 0.06)
                }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Rectangle {
                        width: 3
                        height: 16
                        radius: 1.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: Services.Color.mTertiary
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Services.FluidText {
                            text: "\u56E2\u961F\u4F1A\u8BAE"
                            color: Services.Color.mOnSurface
                            basePixelSize: 10
                            font.bold: true
                        }

                        Services.FluidText {
                            text: "14:00 - 15:30"
                            color: Services.Color.mOnSurfaceVariant
                            basePixelSize: 9
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: calMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
