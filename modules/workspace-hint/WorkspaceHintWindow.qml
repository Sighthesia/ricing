import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../services" as Services
import "."

// OSD popup: a compact stack of workspace capsules drops from the top edge.
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

        // Restrict input to visible capsule area so clicks pass through to windows behind.
        mask: Region { item: hintHitRegion }

        // Decouple window visibility from hint state to allow exit animation.
        // Window stays visible during exit, then hides after animation completes.
        visible: hintWindow._windowVisible

        property bool _windowVisible: false
        property bool _hintActive: Services.WindowHintService.hintVisible
        readonly property var _activeHint: Services.WindowHintService.activeHint
        readonly property int _activeWorkspacePosition: _activeHint.activeWorkspacePosition
        readonly property var _visibleWorkspaces: {
            const items = []
            const allWorkspaces = _activeHint.workspaces || []
            const positions = [
                _activeWorkspacePosition - 1,
                _activeWorkspacePosition,
                _activeWorkspacePosition + 1
            ]

            for (let index = 0; index < positions.length; index++) {
                const position = positions[index]
                if (position < 0 || position >= allWorkspaces.length)
                    continue

                const workspace = allWorkspaces[position]
                items.push({
                    position: position,
                    workspaceIndex: workspace.workspaceIndex,
                    icons: workspace.icons || [],
                    windows: position === _activeWorkspacePosition ? (_activeHint.windows || []) : [],
                    isActive: position === _activeWorkspacePosition
                })
            }

            return items
        }
        readonly property var _topWorkspace: _visibleWorkspaces.length > 0 ? _visibleWorkspaces[0] : null
        readonly property var _middleWorkspace: _visibleWorkspaces.length > 1 ? _visibleWorkspaces[1] : null
        readonly property var _bottomWorkspace: _visibleWorkspaces.length > 2 ? _visibleWorkspaces[2] : null

        // Drive top-to-bottom entry and reverse exit for the three capsules.
        property bool _stageTop: false
        property bool _stageMiddle: false
        property bool _stageBottom: false

        on_HintActiveChanged: {
            if (_hintActive) {
                // Enter: show window, then open the stacked workspace capsules.
                _hideTimer.stop()
                _exitBottomTimer.stop()
                _exitMiddleTimer.stop()
                _exitTopTimer.stop()
                _windowVisible = true
                _stageTop = false
                _stageMiddle = false
                _stageBottom = false
                _enterTopTimer.restart()
                _enterMiddleTimer.restart()
                _enterBottomTimer.restart()
            } else {
                // Exit: collapse the full stack, then hide the window.
                _enterTopTimer.stop()
                _enterMiddleTimer.stop()
                _enterBottomTimer.stop()
                _exitBottomTimer.restart()
                _exitMiddleTimer.restart()
                _exitTopTimer.restart()
                _hideTimer.restart()
            }
        }

        // Drive the top capsule entry.
        Timer {
            id: _enterTopTimer
            interval: 20
            onTriggered: hintWindow._stageTop = true
        }

        // Drive the middle capsule entry.
        Timer {
            id: _enterMiddleTimer
            interval: 70
            onTriggered: hintWindow._stageMiddle = true
        }

        // Drive the bottom capsule entry.
        Timer {
            id: _enterBottomTimer
            interval: 100
            onTriggered: hintWindow._stageBottom = true
        }

        // Collapse the bottom capsule first on exit.
        Timer {
            id: _exitBottomTimer
            interval: 0
            onTriggered: hintWindow._stageBottom = false
        }

        // Collapse the middle capsule second on exit.
        Timer {
            id: _exitMiddleTimer
            interval: 55
            onTriggered: hintWindow._stageMiddle = false
        }

        // Collapse the top capsule last on exit.
        Timer {
            id: _exitTopTimer
            interval: 110
            onTriggered: hintWindow._stageTop = false
        }

        // Hide window after exit animations complete.
        Timer {
            id: _hideTimer
            interval: 380
            onTriggered: hintWindow._windowVisible = false
        }

        // Full-screen transparent container
        Item {
            id: hintContainer
            anchors.fill: parent

            // Keep the stacked hint below the bar while it drops from the top edge.
            readonly property real _wsTargetY: Services.BarLayoutService.barHeight + 16

            // Bound input to the stacked workspace hint surface.
            Item {
                id: hintHitRegion
                readonly property real _left: Math.min(
                    topCapsule.visible ? topCapsule.x : hintContainer.width,
                    middleCapsule.visible ? middleCapsule.x : hintContainer.width,
                    bottomCapsule.visible ? bottomCapsule.x : hintContainer.width
                )
                readonly property real _top: Math.min(
                    topCapsule.visible ? topCapsule.visibleY : hintContainer.height,
                    middleCapsule.visible ? middleCapsule.visibleY : hintContainer.height,
                    bottomCapsule.visible ? bottomCapsule.visibleY : hintContainer.height
                )
                readonly property real _right: Math.max(
                    topCapsule.visible ? topCapsule.x + topCapsule.width : 0,
                    middleCapsule.visible ? middleCapsule.x + middleCapsule.width : 0,
                    bottomCapsule.visible ? bottomCapsule.x + bottomCapsule.width : 0
                )
                readonly property real _bottom: Math.max(
                    topCapsule.visible ? topCapsule.visibleY + topCapsule.height : 0,
                    middleCapsule.visible ? middleCapsule.visibleY + middleCapsule.height : 0,
                    bottomCapsule.visible ? bottomCapsule.visibleY + bottomCapsule.height : 0
                )

                x: _left < hintContainer.width ? _left : 0
                y: _top < hintContainer.height ? _top : 0
                width: Math.max(0, _right - x)
                height: Math.max(0, _bottom - y)
            }

            // Render the top capsule as the first staggered item.
            WorkspaceHintCapsule {
                id: topCapsule

                visible: hintWindow._windowVisible && hintWindow._topWorkspace !== null
                workspaceIndex: hintWindow._topWorkspace ? hintWindow._topWorkspace.workspaceIndex : -1
                active: hintWindow._topWorkspace ? !!hintWindow._topWorkspace.isActive : false
                icons: hintWindow._topWorkspace && hintWindow._topWorkspace.icons ? hintWindow._topWorkspace.icons : []
                windows: hintWindow._topWorkspace && hintWindow._topWorkspace.windows ? hintWindow._topWorkspace.windows : []
                anchors.horizontalCenter: parent.horizontalCenter
                expanded: hintWindow._stageTop
                baseY: parent._wsTargetY
                currentWindowTitle: hintWindow._activeHint.currentWindowTitle
                currentWindowIcon: hintWindow._activeHint.currentWindowIcon
            }

            // Render the middle capsule as the second staggered item.
            WorkspaceHintCapsule {
                id: middleCapsule

                visible: hintWindow._windowVisible && hintWindow._middleWorkspace !== null
                workspaceIndex: hintWindow._middleWorkspace ? hintWindow._middleWorkspace.workspaceIndex : -1
                active: hintWindow._middleWorkspace ? !!hintWindow._middleWorkspace.isActive : false
                icons: hintWindow._middleWorkspace && hintWindow._middleWorkspace.icons ? hintWindow._middleWorkspace.icons : []
                windows: hintWindow._middleWorkspace && hintWindow._middleWorkspace.windows ? hintWindow._middleWorkspace.windows : []
                anchors.horizontalCenter: parent.horizontalCenter
                expanded: hintWindow._stageMiddle
                baseY: parent._wsTargetY + topCapsule.expandedHeightHint + 8
                currentWindowTitle: hintWindow._activeHint.currentWindowTitle
                currentWindowIcon: hintWindow._activeHint.currentWindowIcon
            }

            // Render the bottom capsule as the final staggered item.
            WorkspaceHintCapsule {
                id: bottomCapsule

                visible: hintWindow._windowVisible && hintWindow._bottomWorkspace !== null
                workspaceIndex: hintWindow._bottomWorkspace ? hintWindow._bottomWorkspace.workspaceIndex : -1
                active: hintWindow._bottomWorkspace ? !!hintWindow._bottomWorkspace.isActive : false
                icons: hintWindow._bottomWorkspace && hintWindow._bottomWorkspace.icons ? hintWindow._bottomWorkspace.icons : []
                windows: hintWindow._bottomWorkspace && hintWindow._bottomWorkspace.windows ? hintWindow._bottomWorkspace.windows : []
                anchors.horizontalCenter: parent.horizontalCenter
                expanded: hintWindow._stageBottom
                baseY: parent._wsTargetY + topCapsule.expandedHeightHint + middleCapsule.expandedHeightHint + 16
                currentWindowTitle: hintWindow._activeHint.currentWindowTitle
                currentWindowIcon: hintWindow._activeHint.currentWindowIcon
            }
        }
    }
}
