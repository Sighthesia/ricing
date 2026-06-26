import QtQuick
import "../bar/MenuVisuals.js" as MenuVisuals
import "../../services" as Services

// Time + todo summary card for the overview control-center collage.
// Bold time dominates the top half; a todo summary fills the bottom.
// Click navigates to calendar detail page. Uses a glass layered
// background with subtle gradient and top-edge sheen.
Rectangle {
    id: root

    signal clicked()
    property var todoItems: []
    property int todoCount: 0

    radius: 16
    color: clockMouse.containsMouse
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

    // ── Time + date block ─────────────────────────────────────────
    Column {
        id: timeBlock
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 14
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 2

        Services.FluidText {
            text: Qt.formatTime(new Date(), "hh:mm")
            color: Services.Color.mOnSurface
            basePixelSize: 32
            font.bold: true
        }

        Services.FluidText {
            text: Qt.formatDate(new Date(), "ddd") + " \u00B7 " + Qt.formatDate(new Date(), "MMM d")
            color: Services.Color.mOnSurfaceVariant
            basePixelSize: 11
        }
    }

    // ── Todo summary section ─────────────────────────────────────
    Column {
        anchors.top: timeBlock.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.bottomMargin: 10
        spacing: 3
        clip: true

        // Separator line
        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.1)
        }

        // Todo header row with count badge
        Row {
            spacing: 6
            topPadding: 4

            Services.FluidText {
                text: "\uD83D\uDCCB \u5F85\u529E"
                color: Services.Color.mOnSurface
                basePixelSize: 10
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }

            // Count badge — visible only when todo items exist
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: countLabel.implicitWidth + 8
                height: 14
                radius: 7
                color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.2)
                visible: root.todoItems.length > 0

                Services.FluidText {
                    id: countLabel
                    anchors.centerIn: parent
                    text: root.todoItems.length.toString()
                    color: Services.Color.mPrimary
                    basePixelSize: 8
                    font.bold: true
                }
            }
        }

        // Todo items or empty-state hint
        Item {
            width: parent.width
            height: parent.height - 20

            // When items exist, show top items
            Column {
                id: todoList
                width: parent.width
                spacing: 2
                visible: root.todoItems.length > 0

                Repeater {
                    model: Math.min(root.todoItems.length, 4)

                    Row {
                        width: parent.width
                        spacing: 4

                        Services.FluidText {
                            text: "\u2022"
                            color: Services.Color.mPrimary
                            basePixelSize: 9
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Services.FluidText {
                            text: root.todoItems[index].substring(0, Math.min(root.todoItems[index].length, 28))
                            color: Services.Color.mOnSurfaceVariant
                            basePixelSize: 9
                            elide: Text.ElideRight
                            width: parent.width - 12
                            opacity: 0.8
                        }
                    }
                }
            }

            // Empty-state prompt when no todo items
            Services.FluidText {
                visible: root.todoItems.length === 0
                text: "\u6682\u65E0\u5F85\u529E\uFF0C\u70B9\u51FB\u67E5\u770B\u65E5\u5386"
                color: Services.Color.mOnSurfaceVariant
                basePixelSize: 9
                opacity: 0.45
                width: parent.width
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: clockMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
