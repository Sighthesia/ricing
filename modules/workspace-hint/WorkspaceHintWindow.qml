import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../services" as Services

// OSD popup: two capsules emerge from center dockzone at zero width,
// expand outward to full size while sliding to final positions with stagger.
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

        // Stagger state: each stage drives one capsule from collapsed to expanded
        property bool _stage1: false
        property bool _stage2: false

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

        // Stagger timers: workspace capsule first, then window capsule
        Timer {
            id: _staggerTimer1
            interval: 20
            onTriggered: {
                hintWindow._stage1 = true
                _staggerTimer2.restart()
            }
        }

        Timer {
            id: _staggerTimer2
            interval: 70
            onTriggered: hintWindow._stage2 = true
        }

        // Full-screen transparent container
        Item {
            anchors.fill: parent

            // Origin: center of screen horizontally, at bar bottom edge vertically
            // This is where both capsules "emerge from" — the center dockzone midpoint.
            readonly property real _originY: Services.BarLayoutService.barHeight / 2
            readonly property real _splitGap: 8
            // Final resting positions: well below bar to make the travel visible
            readonly property real _wsTargetY: Services.BarLayoutService.barHeight + 16
            readonly property real _winTargetY: _wsTargetY + 44 + _splitGap

            // ─── Workspace capsule ───────────────────────────────────────────
            Rectangle {
                id: workspaceCapsule

                // Horizontal: always centered
                anchors.horizontalCenter: parent.horizontalCenter

                // Vertical: starts at origin, slides to final position
                y: hintWindow._stage1 ? parent._wsTargetY : parent._originY

                // Width: starts at 0, expands to content width
                width: hintWindow._stage1 ? (workspaceContent.implicitWidth + 32) : 0
                height: 44
                radius: 22
                clip: true

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
                opacity: hintWindow._stage1 ? 1.0 : 0.0

                Behavior on width {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 350
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 60
                        easing.type: Easing.Linear
                    }
                }

                // Content: centered inside, unaffected by width animation
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

            // ─── Window title capsule ────────────────────────────────────────
            Rectangle {
                id: windowCapsule

                anchors.horizontalCenter: parent.horizontalCenter

                // Vertical: starts at origin, slides to final position
                y: hintWindow._stage2 ? parent._winTargetY : parent._originY

                // Width: starts at 0, expands to content width
                width: hintWindow._stage2 ? (windowContent.implicitWidth + 32) : 0
                height: windowContent.implicitHeight + 20
                radius: 18
                clip: true

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
                opacity: hintWindow._stage2 ? 1.0 : 0.0

                Behavior on width {
                    NumberAnimation {
                        duration: 360
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 400
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 60
                        easing.type: Easing.Linear
                    }
                }

                // Content: centered, clips during width expansion
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
