import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../services" as Services

// OSD popup showing workspace list and window hints while mod key is held.
// Two capsules split apart from a shared center origin with staggered timing.
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

        // Stagger state machine
        property bool _showActive: Services.WindowHintService.hintVisible
        property bool _stage1: false // workspace capsule
        property bool _stage2: false // window title capsule

        onVisibleChanged: {
            if (visible) {
                _stage1 = false
                _stage2 = false
                _staggerTimer1.restart()
            } else {
                _stage1 = false
                _stage2 = false
            }
        }

        // Stagger delay timers for split-apart entrance
        Timer {
            id: _staggerTimer1
            interval: 30
            onTriggered: {
                hintWindow._stage1 = true
                _staggerTimer2.restart()
            }
        }

        Timer {
            id: _staggerTimer2
            interval: 60
            onTriggered: hintWindow._stage2 = true
        }

        // Full-screen transparent container
        Item {
            anchors.fill: parent

            // Shared origin point: center-top below bar
            readonly property real _originX: width / 2
            readonly property real _originY: Services.BarLayoutService.barHeight + 12

            // Split distance: how far each capsule travels from origin
            readonly property real _splitGap: 6
            readonly property real _workspaceCapsuleHeight: workspaceCapsule.implicitHeight
            readonly property real _windowCapsuleHeight: windowCapsule.implicitHeight

            // Workspace capsule (upper, splits upward from origin)
            Rectangle {
                id: workspaceCapsule
                anchors.horizontalCenter: parent.horizontalCenter
                y: hintWindow._stage1
                    ? parent._originY
                    : parent._originY + parent._splitGap + 4
                width: workspaceContent.implicitWidth + 32
                implicitHeight: 44
                radius: 22
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
                    0.25
                )
                border.width: 1

                // Split-apart animation: y offset + scale + opacity
                opacity: hintWindow._stage1 ? 1.0 : 0.0
                scale: hintWindow._stage1 ? 1.0 : 0.85
                transformOrigin: Item.Bottom

                Behavior on y {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.6
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: Services.Motion.popup.opacityDuration
                        easing.type: Services.Motion.popup.opacityEasing
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.4
                    }
                }

                // Workspace capsule content: horizontal workspace indicators
                Row {
                    id: workspaceContent
                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: Services.WindowHintService.hintVisible
                            ? Services.WindowHintService.activeHint.workspaces
                            : []

                        // Individual workspace pill
                        Rectangle {
                            required property var modelData
                            required property int index

                            width: Math.max(wsPillContent.implicitWidth + 14, 36)
                            height: 28
                            radius: 14
                            color: modelData.isActive
                                ? Services.Color.mPrimary
                                : Qt.rgba(
                                    Services.Color.mSurfaceVariant.r,
                                    Services.Color.mSurfaceVariant.g,
                                    Services.Color.mSurfaceVariant.b,
                                    0.6
                                )

                            Behavior on color {
                                ColorAnimation {
                                    duration: Services.Motion.number.shortDuration
                                    easing.type: Services.Motion.number.shortEasing
                                }
                            }

                            Row {
                                id: wsPillContent
                                anchors.centerIn: parent
                                spacing: 3

                                // Workspace index
                                Text {
                                    text: String(modelData.workspaceIndex)
                                    font.pixelSize: 12
                                    font.bold: modelData.isActive
                                    color: modelData.isActive
                                        ? Services.Color.mOnPrimary
                                        : Services.Color.mOnSurfaceVariant
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                // Window count
                                Text {
                                    visible: modelData.icons.length > 0
                                    text: "·" + modelData.icons.length
                                    font.pixelSize: 10
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
            }

            // Window title capsule (lower, splits downward from origin)
            Rectangle {
                id: windowCapsule
                anchors.horizontalCenter: parent.horizontalCenter
                y: hintWindow._stage2
                    ? (workspaceCapsule.y + workspaceCapsule.implicitHeight + parent._splitGap)
                    : (parent._originY + 4)
                width: windowContent.implicitWidth + 32
                implicitHeight: windowContent.implicitHeight + 20
                radius: 18
                color: Qt.rgba(
                    Services.Color.mSurface.r,
                    Services.Color.mSurface.g,
                    Services.Color.mSurface.b,
                    0.88
                )
                border.color: Qt.rgba(
                    Services.Color.mOutline.r,
                    Services.Color.mOutline.g,
                    Services.Color.mOutline.b,
                    0.2
                )
                border.width: 1

                // Split-apart animation: y offset + scale + opacity
                opacity: hintWindow._stage2 ? 1.0 : 0.0
                scale: hintWindow._stage2 ? 1.0 : 0.8
                transformOrigin: Item.Top

                Behavior on y {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.5
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 140
                        easing.type: Services.Motion.popup.opacityEasing
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.35
                    }
                }

                // Window title capsule content
                Column {
                    id: windowContent
                    anchors.centerIn: parent
                    spacing: 8

                    // Horizontal row of window title cards
                    Row {
                        id: windowTitleRow
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6

                        Repeater {
                            model: Services.WindowHintService.hintVisible
                                ? Services.WindowHintService.activeHint.windows
                                : []

                            // Individual window title card
                            Rectangle {
                                required property var modelData
                                required property int index

                                width: Math.max(winCardRow.implicitWidth + 14, 100)
                                height: 28
                                radius: 8
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
                                        0.35
                                    )

                                Row {
                                    id: winCardRow
                                    anchors.centerIn: parent
                                    spacing: 5

                                    // Focus dot
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
                                        font.pixelSize: 11
                                        font.bold: modelData.isFocused
                                        color: modelData.isFocused
                                            ? Services.Color.mOnSurface
                                            : Services.Color.mOnSurfaceVariant
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                        width: Math.min(implicitWidth, 140)
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
                            font.pixelSize: 12
                            color: Services.Color.mOnSurfaceVariant
                            opacity: 0.5
                        }
                    }

                    // Previous/Next window hints
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 20
                        visible: Services.WindowHintService.hintVisible
                            && (Services.WindowHintService.activeHint.previousWindow.windowId !== ""
                                || Services.WindowHintService.activeHint.nextWindow.windowId !== "")

                        Text {
                            visible: Services.WindowHintService.hintVisible
                                && Services.WindowHintService.activeHint.previousWindow.windowId !== ""
                            text: "← " + Services.WindowHintService.activeHint.previousWindow.title
                            font.pixelSize: 10
                            color: Services.Color.mOnSurfaceVariant
                            opacity: 0.45
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 110)
                        }

                        Text {
                            visible: Services.WindowHintService.hintVisible
                                && Services.WindowHintService.activeHint.nextWindow.windowId !== ""
                            text: Services.WindowHintService.activeHint.nextWindow.title + " →"
                            font.pixelSize: 10
                            color: Services.Color.mOnSurfaceVariant
                            opacity: 0.45
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, 110)
                        }
                    }
                }
            }
        }
    }
}
