import QtQuick
import "../bar/MenuVisuals.js" as MenuVisuals
import "../../services" as Services

// Settings quick-toggle grid for the overview control-center collage.
// Shows a 2×2 grid of glanceable shortcut toggles (WiFi, Bluetooth,
// Brightness, DND). The whole card routes to the settings detail page.
// Uses glass layered background with gradient and top-edge sheen.
Rectangle {
    id: root

    signal clicked()

    radius: 16
    color: settingsMouse.containsMouse
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

    // 2×2 grid of quick-toggle cells with icon + label + status line.
    Grid {
        anchors.fill: parent
        anchors.margins: 8
        columns: 2
        columnSpacing: 6
        rowSpacing: 6

        // WiFi toggle cell — active state with colored accent and subtle inner gradient.
        Rectangle {
            width: (parent.width - 6) / 2
            height: (parent.height - 6) / 2
            radius: 12
            color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.08)
            border.color: Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.15)
            border.width: 1

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
                    color: Services.Color.mPrimary
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
                    text: "\u5DF2\u8FDE\u63A5"
                    color: Services.Color.mPrimary
                    basePixelSize: 7
                }
            }
        }

        // Bluetooth toggle cell — inactive state with muted colors and glass highlight.
        Rectangle {
            width: (parent.width - 6) / 2
            height: (parent.height - 6) / 2
            radius: 12
            color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.06)
            border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.2)
            border.width: 1

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
                    text: "BT"
                    color: Services.Color.mOnSurfaceVariant
                    basePixelSize: 14
                    font.bold: true
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
                    text: "\u5DF2\u5173\u95ED"
                    color: Services.Color.mOnSurfaceVariant
                    basePixelSize: 7
                }
            }
        }

        // Brightness toggle cell with glass highlight.
        Rectangle {
            width: (parent.width - 6) / 2
            height: (parent.height - 6) / 2
            radius: 12
            color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.06)
            border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.2)
            border.width: 1

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
                    text: "75%"
                    color: Services.Color.mOnSurfaceVariant
                    basePixelSize: 7
                }
            }
        }

        // Do-not-disturb toggle cell with glass highlight.
        Rectangle {
            width: (parent.width - 6) / 2
            height: (parent.height - 6) / 2
            radius: 12
            color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.06)
            border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.2)
            border.width: 1

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
                    color: Services.Color.mOnSurface
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
                    text: "\u5173\u95ED"
                    color: Services.Color.mOnSurfaceVariant
                    basePixelSize: 7
                }
            }
        }
    }

    // Transparent catcher so the whole card routes to settings center.
    MouseArea {
        id: settingsMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
