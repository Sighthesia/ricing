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
        // Below bar/dockzone background layer
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.exclusiveZone: -1

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Decouple window visibility from hint state to allow exit animation.
        // Window stays visible during exit, then hides after animation completes.
        visible: hintWindow._windowVisible

        property bool _windowVisible: false
        property bool _hintActive: Services.WindowHintService.hintVisible

        // Stagger state: each stage drives one capsule from collapsed to expanded
        property bool _stage1: false
        property bool _stage2: false
        // Exit state: true when playing exit animation (disables clip so content stays visible)
        property bool _exiting: false

        on_HintActiveChanged: {
            if (_hintActive) {
                // Enter: show window, then stagger capsules open
                _hideTimer.stop()
                _exitTimer1.stop()
                _exiting = false
                _windowVisible = true
                _stage1 = false
                _stage2 = false
                _staggerTimer1.restart()
            } else {
                // Exit: reverse stagger — window title first, then workspace
                _staggerTimer1.stop()
                _staggerTimer2.stop()
                _exiting = true
                _stage2 = false
                _exitTimer1.restart()
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

        // Exit stagger: window capsule collapses first, then workspace, then hide
        Timer {
            id: _exitTimer1
            interval: 50
            onTriggered: {
                hintWindow._stage1 = false
                _hideTimer.restart()
            }
        }

        // Hide window after exit animations complete
        Timer {
            id: _hideTimer
            interval: 380
            onTriggered: hintWindow._windowVisible = false
        }

        // Full-screen transparent container
        Item {
            anchors.fill: parent

            // Origin: y=0 (top screen edge), capsules slide down to final positions.
            readonly property real _splitGap: 8
            // Final resting positions: below bar
            readonly property real _wsTargetY: Services.BarLayoutService.barHeight + 16
            readonly property real _winTargetY: _wsTargetY + 44 + _splitGap

            // ─── Workspace capsule ───────────────────────────────────────────
            Rectangle {
                id: workspaceCapsule

                // Horizontal: always centered
                anchors.horizontalCenter: parent.horizontalCenter

                // Vertical: collapsed at y=0 (top edge), expanded at target
                y: hintWindow._stage1 ? parent._wsTargetY : -height / 2

                // Width: collapses to a circle (height), expands to content width
                width: hintWindow._stage1 ? (workspaceContent.implicitWidth + 32) : height
                height: 44
                // Radius: full circle when collapsed, pill when expanded
                radius: hintWindow._stage1 ? 22 : height / 2
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
                Behavior on radius {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutCubic
                    }
                }

                // Content: centered inside, unaffected by width animation
                Row {
                    id: workspaceContent
                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: hintWindow._windowVisible
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

                // Vertical: collapsed at y=0 (top edge), expanded at target
                y: hintWindow._stage2 ? parent._winTargetY : -height / 2

                // Width: collapses to a circle (height), expands to content width
                width: hintWindow._stage2 ? (windowContent.implicitWidth + 32) : height
                height: windowContent.implicitHeight + 20
                // Radius: full circle when collapsed, pill when expanded
                radius: hintWindow._stage2 ? 18 : height / 2
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
                Behavior on radius {
                    NumberAnimation {
                        duration: 360
                        easing.type: Easing.OutCubic
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
                            model: hintWindow._windowVisible
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
                            visible: hintWindow._windowVisible
                                && Services.WindowHintService.activeHint.windows.length === 0
                            text: "空工作区"
                            font.pixelSize: 12
                            color: Services.Color.mOnSurfaceVariant
                            opacity: 0.5
                        }
                    }
                }
            }
        }
    }
}
