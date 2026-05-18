import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../services" as Services

// OSD popup showing workspace list and window hints while mod key is held.
Variants {
    id: root

    model: Quickshell.screens

    // Per-screen workspace hint overlay
    PanelWindow {
        id: hintWindow

        required property var modelData

        screen: modelData
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusiveZone: -1

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        visible: Services.WindowHintService.hintVisible

        // Full-screen transparent container
        Item {
            anchors.fill: parent

            // Main OSD container positioned below center dockzone
            Rectangle {
                id: osdContainer
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Services.BarLayoutService.barHeight + 12
                width: contentColumn.implicitWidth + 48
                height: contentColumn.implicitHeight + 40
                radius: 20
                color: Qt.rgba(
                    Services.Color.mSurface.r,
                    Services.Color.mSurface.g,
                    Services.Color.mSurface.b,
                    0.92
                )
                border.color: Qt.rgba(
                    Services.Color.mOutline.r,
                    Services.Color.mOutline.g,
                    Services.Color.mOutline.b,
                    0.3
                )
                border.width: 1

                // Entry animation
                scale: Services.WindowHintService.hintVisible ? 1.0 : 0.92
                opacity: Services.WindowHintService.hintVisible ? 1.0 : 0.0

                Behavior on scale {
                    NumberAnimation {
                        duration: Services.Motion.popup.scaleDuration
                        easing.type: Services.Motion.popup.scaleEasing
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Services.Motion.popup.opacityDuration
                        easing.type: Services.Motion.popup.opacityEasing
                    }
                }

                Column {
                    id: contentColumn
                    anchors.centerIn: parent
                    spacing: 16

                    // Workspace row: horizontal list of workspace capsules
                    Row {
                        id: workspaceRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        Repeater {
                            model: Services.WindowHintService.hintVisible
                                ? Services.WindowHintService.activeHint.workspaces
                                : []

                            // Individual workspace capsule
                            Rectangle {
                                required property var modelData
                                required property int index

                                width: Math.max(capsuleContent.implicitWidth + 16, 40)
                                height: 32
                                radius: 16
                                color: modelData.isActive
                                    ? Services.Color.mPrimary
                                    : Qt.rgba(
                                        Services.Color.mSurfaceVariant.r,
                                        Services.Color.mSurfaceVariant.g,
                                        Services.Color.mSurfaceVariant.b,
                                        0.7
                                    )

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Services.Motion.number.shortDuration
                                        easing.type: Services.Motion.number.shortEasing
                                    }
                                }

                                Row {
                                    id: capsuleContent
                                    anchors.centerIn: parent
                                    spacing: 4

                                    // Workspace index label
                                    Text {
                                        text: String(modelData.workspaceIndex)
                                        font.pixelSize: 13
                                        font.bold: modelData.isActive
                                        color: modelData.isActive
                                            ? Services.Color.mOnPrimary
                                            : Services.Color.mOnSurfaceVariant
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    // Window count indicator
                                    Text {
                                        visible: modelData.icons.length > 0
                                        text: "·" + modelData.icons.length
                                        font.pixelSize: 11
                                        color: modelData.isActive
                                            ? Services.Color.mOnPrimary
                                            : Services.Color.mOnSurfaceVariant
                                        opacity: 0.7
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }

                    // Separator line
                    Rectangle {
                        width: Math.max(workspaceRow.implicitWidth, windowRow.implicitWidth, 200)
                        height: 1
                        color: Services.Color.mOutline
                        opacity: 0.2
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    // Current workspace windows: horizontal row of title cards
                    Row {
                        id: windowRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8

                        Repeater {
                            model: Services.WindowHintService.hintVisible
                                ? Services.WindowHintService.activeHint.windows
                                : []

                            // Individual window title card
                            Rectangle {
                                required property var modelData
                                required property int index

                                width: Math.max(windowCardContent.implicitWidth + 16, 100)
                                height: 32
                                radius: 10
                                color: modelData.isFocused
                                    ? Qt.rgba(
                                        Services.Color.mPrimary.r,
                                        Services.Color.mPrimary.g,
                                        Services.Color.mPrimary.b,
                                        0.18
                                    )
                                    : Qt.rgba(
                                        Services.Color.mSurfaceVariant.r,
                                        Services.Color.mSurfaceVariant.g,
                                        Services.Color.mSurfaceVariant.b,
                                        0.4
                                    )

                                Row {
                                    id: windowCardContent
                                    anchors.centerIn: parent
                                    spacing: 6

                                    // Focus indicator dot
                                    Rectangle {
                                        width: 5
                                        height: 5
                                        radius: 2.5
                                        color: Services.Color.mPrimary
                                        visible: modelData.isFocused
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    // Window title
                                    Text {
                                        text: modelData.title
                                        font.pixelSize: 12
                                        font.bold: modelData.isFocused
                                        color: modelData.isFocused
                                            ? Services.Color.mOnSurface
                                            : Services.Color.mOnSurfaceVariant
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        width: Math.min(implicitWidth, 160)
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        // Empty state
                        Text {
                            visible: Services.WindowHintService.hintVisible
                                && Services.WindowHintService.activeHint.windows.length === 0
                            text: "空工作区"
                            font.pixelSize: 13
                            color: Services.Color.mOnSurfaceVariant
                            opacity: 0.5
                        }
                    }

                    // Previous/Next window preview (subtle)
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 24
                        visible: Services.WindowHintService.hintVisible
                            && (Services.WindowHintService.activeHint.previousWindow.windowId !== ""
                                || Services.WindowHintService.activeHint.nextWindow.windowId !== "")

                        // Previous window
                        Text {
                            visible: Services.WindowHintService.hintVisible
                                && Services.WindowHintService.activeHint.previousWindow.windowId !== ""
                            text: "← " + Services.WindowHintService.activeHint.previousWindow.title
                            font.pixelSize: 11
                            color: Services.Color.mOnSurfaceVariant
                            opacity: 0.5
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 120)
                        }

                        // Next window
                        Text {
                            visible: Services.WindowHintService.hintVisible
                                && Services.WindowHintService.activeHint.nextWindow.windowId !== ""
                            text: Services.WindowHintService.activeHint.nextWindow.title + " →"
                            font.pixelSize: 11
                            color: Services.Color.mOnSurfaceVariant
                            opacity: 0.5
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 120)
                        }
                    }
                }
            }
        }
    }
}
