import QtQuick
import "../bar/MenuVisuals.js" as MenuVisuals
import "../../services" as Services

// Quick-toggle panel for the overview control-center collage.
// Shows a 2×2 grid of glanceable shortcut toggles (WiFi, Bluetooth,
// Brightness, DND). Each cell has whole-area click:
//   - WiFi / Bluetooth: click anywhere to toggle on/off
//   - Brightness: click anywhere to open brightness adjustment
//   - DND: click anywhere to toggle do-not-disturb
// A small round gear button in the top-right corner opens Settings Center.
// Fine-tune detail (status text / percentage) remains as secondary info.
// Uses glass layered background with gradient and top-edge sheen.
Rectangle {
    id: root

    signal brightnessClicked()
    signal openSettings()

    // Simulated toggle states (no real WiFi/BT service wired yet)
    property bool wifiEnabled: true
    property bool bluetoothEnabled: false
    property real brightnessValue: Services.BrightnessService.brightness

    radius: 16
    color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)
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

    // Small round settings button in the top-right corner.
    Rectangle {
        id: settingsButton
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.rightMargin: 8
        width: 28
        height: 28
        radius: 14
        color: settingsBtnMouse.containsMouse
            ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.listHoverOpacity)
            : Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.08)
        border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.3)
        border.width: 1
        z: 2

        Behavior on color {
            ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
        }

        Services.FluidText {
            anchors.centerIn: parent
            text: "\u2699"
            color: Services.Color.mOnSurfaceVariant
            basePixelSize: 14
        }

        MouseArea {
            id: settingsBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.openSettings()
        }
    }

    // 2×2 grid of quick-toggle cells with icon + label + status line.
    Grid {
        anchors.fill: parent
        anchors.margins: 8
        anchors.rightMargin: 8
        anchors.topMargin: 8
        columns: 2
        columnSpacing: 6
        rowSpacing: 6

        // WiFi toggle cell — whole-cell click toggles state.
        Rectangle {
            id: wifiCell
            width: (parent.width - 6) / 2
            height: (parent.height - 6) / 2
            radius: 12
            color: root.wifiEnabled
                ? Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.08)
                : Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.06)
            border.color: root.wifiEnabled
                ? Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.15)
                : Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.2)
            border.width: 1

            Behavior on color {
                ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
            }
            Behavior on border.color {
                ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
            }

            // Cell-top glass highlight for individual toggle depth.
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            Column {
                anchors.centerIn: parent
                spacing: 1

                Services.FluidText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\u25C9"
                    color: root.wifiEnabled ? Services.Color.mPrimary : Services.Color.mOnSurfaceVariant
                    basePixelSize: 18
                }

                Services.FluidText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "WiFi"
                    color: Services.Color.mOnSurface
                    basePixelSize: 9
                    font.bold: true
                }

                Services.FluidText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.wifiEnabled ? "\u5DF2\u8FDE\u63A5" : "\u5DF2\u5173\u95ED"
                    color: root.wifiEnabled ? Services.Color.mPrimary : Services.Color.mOnSurfaceVariant
                    basePixelSize: 7
                }
            }

            // Whole-cell click toggle
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.wifiEnabled = !root.wifiEnabled
            }
        }

        // Bluetooth toggle cell — whole-cell click toggles state.
        Rectangle {
            id: btCell
            width: (parent.width - 6) / 2
            height: (parent.height - 6) / 2
            radius: 12
            color: root.bluetoothEnabled
                ? Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.08)
                : Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.06)
            border.color: root.bluetoothEnabled
                ? Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.15)
                : Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.2)
            border.width: 1

            Behavior on color {
                ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
            }
            Behavior on border.color {
                ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
            }

            // Cell-top glass highlight.
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            Column {
                anchors.centerIn: parent
                spacing: 1

                Services.FluidText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\uD83D\uDC1D"
                    color: root.bluetoothEnabled ? Services.Color.mPrimary : Services.Color.mOnSurfaceVariant
                    basePixelSize: 14
                }

                Services.FluidText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\u84DD\u7259"
                    color: Services.Color.mOnSurface
                    basePixelSize: 9
                    font.bold: true
                }

                Services.FluidText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.bluetoothEnabled ? "\u5DF2\u5F00\u542F" : "\u5DF2\u5173\u95ED"
                    color: root.bluetoothEnabled ? Services.Color.mPrimary : Services.Color.mOnSurfaceVariant
                    basePixelSize: 7
                }
            }

            // Whole-cell click toggle
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.bluetoothEnabled = !root.bluetoothEnabled
            }
        }

        // Brightness cell — whole-cell click focuses adjustment.
        Rectangle {
            id: brCell
            width: (parent.width - 6) / 2
            height: (parent.height - 6) / 2
            radius: 12
            color: brCellMouse.containsMouse
                ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.1)
                : Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.06)
            border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.2)
            border.width: 1

            Behavior on color {
                ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
            }

            // Cell-top glass highlight.
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            Column {
                anchors.centerIn: parent
                spacing: 1

                Services.FluidText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\u2600"
                    color: Services.Color.mOnSurface
                    basePixelSize: 18
                }

                Services.FluidText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\u4EAE\u5EA6"
                    color: Services.Color.mOnSurface
                    basePixelSize: 9
                    font.bold: true
                }

                Services.FluidText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Math.round(root.brightnessValue * 100) + "%"
                    color: Services.Color.mOnSurfaceVariant
                    basePixelSize: 7
                }
            }

            // Whole-cell click opens brightness adjustment
            MouseArea {
                id: brCellMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.brightnessClicked()
            }
        }

        // Do-not-disturb toggle cell — whole-cell click toggles DND.
        Rectangle {
            id: dndCell
            width: (parent.width - 6) / 2
            height: (parent.height - 6) / 2
            radius: 12
            color: Services.NotificationService.dndEnabled
                ? Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.08)
                : Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.06)
            border.color: Services.NotificationService.dndEnabled
                ? Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.15)
                : Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.2)
            border.width: 1

            Behavior on color {
                ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
            }
            Behavior on border.color {
                ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
            }

            // Cell-top glass highlight.
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Qt.rgba(1, 1, 1, 0.06)
            }

            Column {
                anchors.centerIn: parent
                spacing: 1

                Services.FluidText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\u263E"
                    color: Services.NotificationService.dndEnabled ? Services.Color.mPrimary : Services.Color.mOnSurface
                    basePixelSize: 18
                }

                Services.FluidText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "\u52FF\u6270"
                    color: Services.Color.mOnSurface
                    basePixelSize: 9
                    font.bold: true
                }

                Services.FluidText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Services.NotificationService.dndEnabled ? "\u5DF2\u5F00\u542F" : "\u5173\u95ED"
                    color: Services.NotificationService.dndEnabled ? Services.Color.mPrimary : Services.Color.mOnSurfaceVariant
                    basePixelSize: 7
                }
            }

            // Whole-cell click toggles DND
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Services.SettingsService.notifications.dnd = !Services.SettingsService.notifications.dnd
            }
        }
    }
}
