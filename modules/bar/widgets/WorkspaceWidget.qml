import QtQuick
import Quickshell
import qs.config
import qs.services

// Two-state workspace indicator ("Dynamic Island" morph style).
//
// Focus Mode (default): single pill — focused app icon + window title.
// Overview Mode: per-workspace pills showing open window app icons.
//
// Mode transitions:
//   - Focus is active whenever a window is focused.
//   - Overview activates when the desktop has no focused window.
//   - Hover flips to the opposite mode temporarily.
//   - Workspace switch triggers a 1.5 s overview flash, then returns to Focus.
Item {
    id: root

    // --- layout ---
    implicitHeight: Theme.barHeight
    implicitWidth: _pill.implicitWidth

    // --- structure constants ---
    readonly property int _padV:         4    // vertical gap (pill ↔ bar top/bottom)
    readonly property int _padH:         10   // horizontal padding inside the pill
    readonly property int _iconSize:     16   // app icon in focus mode
    readonly property int _smallIcon:    13   // app icon inside workspace pills
    readonly property int _iconSpacing:  2    // gap between icons in a workspace pill
    readonly property int _pillGap:      6    // gap between workspace pills
    readonly property int _pillPadH:     8    // horizontal padding inside each workspace pill
    readonly property int _iconTitleGap: 6    // gap between focus icon and title text
    readonly property int _titleMaxW:    240  // max title render width (ElideRight after this)
    readonly property int _pillH:        Theme.barHeight - 2 * _padV

    // --- state machine ---
    // _mode is the base/preferred mode.
    // Hover XOR-flips to the other mode while the mouse is over the widget.
    // workspaceActivated fires _flashTimer to force overview for 1.5 s.
    property string _mode: "focus"    // "focus" | "overview"
    property bool   _hovered: false

    // _showOverview: the fully resolved, render-driving boolean.
    // Truth table:
    //   no focused window → always overview
    //   focused + _mode="focus"    + not hovered → false (focus)
    //   focused + _mode="focus"    + hovered     → true  (overview via hover flip)
    //   focused + _mode="overview" + not hovered → true  (overview)
    //   focused + _mode="overview" + hovered     → false (focus via hover flip)
    readonly property bool _showOverview: {
        if (_focusedTitle.length === 0) return true
        return (_mode === "overview") !== _hovered   // XOR
    }

    // --- focused window data ---
    property string _focusedAppId: ""
    property string _focusedTitle:  ""

    function _refreshFocus() {
        for (let i = 0; i < NiriService.windows.count; i++) {
            const w = NiriService.windows.get(i)
            if (w.isFocused) {
                root._focusedAppId = w.appId
                root._focusedTitle = (w.title === "Unknown") ? w.appId : w.title
                return
            }
        }
        root._focusedAppId = ""
        root._focusedTitle = ""
    }

    // --- icon resolution ---
    function _iconPath(appId) {
        if (!appId) return Quickshell.iconPath("application-x-executable")
        const entry = DesktopEntries.heuristicLookup(appId)
        if (entry && entry.icon)
            return Quickshell.iconPath(entry.icon, "application-x-executable")
        return Quickshell.iconPath("application-x-executable")
    }

    // --- flash timer: workspace switch → show overview for 1.5 s then return ---
    Timer {
        id: _flashTimer
        interval: 1500
        repeat: false
        onTriggered: root._mode = "focus"
    }

    Component.onCompleted: _refreshFocus()

    Connections {
        target: NiriService
        function onWindowsUpdated()      { root._refreshFocus() }
        function onWorkspaceActivated()  {
            // Temporarily show overview so the user sees the new workspace.
            root._mode = "overview"
            _flashTimer.restart()
        }
    }

    // Hover detection drives the _hovered XOR flip.
    MouseArea {
        id: _hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root._hovered = true
        onExited:  root._hovered = false
    }

    // ─── Visual pill ──────────────────────────────────────────────────────
    // Single rounded rectangle; width animates between overview and focus sizes.
    Rectangle {
        id: _pill

        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        height: root._pillH
        // Width is driven by _showOverview; animated by Behavior below.
        // Both content items report their implicitWidth; pill tracks the active one.
        implicitWidth: root._showOverview
            ? (_overviewRow.implicitWidth + root._padH * 2)
            : (_focusRow.implicitWidth   + root._padH * 2)

        Behavior on implicitWidth {
            NumberAnimation {
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        radius: height / 2
        color: Colors.surface

        // ── Overview content — workspace pills row ───────────────────────
        Row {
            id: _overviewRow
            anchors.centerIn: parent
            spacing: root._pillGap
            opacity: root._showOverview ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.highlightDuration
                    easing.type: Theme.anim.highlightType
                }
            }

            Repeater {
                model: NiriService.workspaces

                delegate: Item {
                    id: _wsDelegate

                    required property string wsId
                    required property int    idx
                    required property bool   isActive

                    // Per-workspace app icon list (one entry per open window).
                    property var _appIds: []

                    function _refreshIcons() {
                        let arr = []
                        for (let i = 0; i < NiriService.windows.count; i++) {
                            const w = NiriService.windows.get(i)
                            if (w.workspaceId === _wsDelegate.wsId) arr.push(w.appId)
                        }
                        _wsDelegate._appIds = arr
                    }

                    Component.onCompleted: _refreshIcons()

                    Connections {
                        target: NiriService
                        function onWindowsUpdated() { _wsDelegate._refreshIcons() }
                    }

                    // Hide empty non-active workspaces; collapse layout space.
                    visible: isActive || _appIds.length > 0
                    width:  visible ? _wsPill.implicitWidth  : 0
                    height: visible ? _wsPill.implicitHeight : 0

                    // Inner workspace pill
                    Rectangle {
                        id: _wsPill

                        implicitHeight: root._pillH
                        implicitWidth: Math.max(
                            _iconsRow.implicitWidth + root._pillPadH * 2,
                            root._pillH   // square-ish minimum
                        )
                        radius: implicitHeight / 2
                        color: _wsDelegate.isActive ? Colors.highlight : Colors.surface

                        Behavior on implicitWidth {
                            NumberAnimation {
                                duration: Theme.anim.moveDuration
                                easing.type: Theme.anim.moveType
                            }
                        }
                        Behavior on color {
                            ColorAnimation { duration: Theme.anim.highlightDuration }
                        }

                        // App icons (or workspace number when empty)
                        Row {
                            id: _iconsRow
                            anchors.centerIn: parent
                            spacing: root._iconSpacing

                            Repeater {
                                model: _wsDelegate._appIds

                                delegate: Image {
                                    required property string modelData

                                    readonly property bool _ok: status === Image.Ready
                                    width:  _ok ? root._smallIcon : 0
                                    height: _ok ? root._smallIcon : 0
                                    source: root._iconPath(modelData)
                                    smooth: true
                                    fillMode: Image.PreserveAspectFit
                                }
                            }

                            Text {
                                visible: _wsDelegate._appIds.length === 0
                                text: _wsDelegate.idx
                                font.family: Theme.fontMono
                                font.bold: true
                                font.pixelSize: Theme.fontSizeBody
                                color: _wsDelegate.isActive ? Colors.background : Colors.textMuted

                                Behavior on color {
                                    ColorAnimation { duration: Theme.anim.highlightDuration }
                                }
                            }
                        }

                        // Hover highlight overlay
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: Colors.highlight
                            opacity: _wsArea.containsMouse ? 0.15 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.anim.highlightDuration
                                    easing.type: Theme.anim.highlightType
                                }
                            }
                        }

                        MouseArea {
                            id: _wsArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Quickshell.execDetached([
                                "niri", "msg", "action",
                                "focus-workspace", _wsDelegate.idx.toString()
                            ])
                        }
                    }
                }
            }
        }

        // ── Focus content — app icon + window title ──────────────────────
        Row {
            id: _focusRow
            anchors.centerIn: parent
            spacing: root._iconTitleGap
            opacity: root._showOverview ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.highlightDuration
                    easing.type: Theme.anim.highlightType
                }
            }

            Image {
                id: _focusIcon
                width:  root._iconSize
                height: root._iconSize
                anchors.verticalCenter: parent.verticalCenter
                source: root._iconPath(root._focusedAppId)
                smooth: true
                fillMode: Image.PreserveAspectFit
            }

            Text {
                id: _titleText
                anchors.verticalCenter: parent.verticalCenter
                // Natural width capped at _titleMaxW; ElideRight truncates beyond that.
                width: Math.min(implicitWidth, root._titleMaxW)
                text: root._focusedTitle
                elide: Text.ElideRight
                maximumLineCount: 1
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                color: Colors.text
            }
        }
    }
}
