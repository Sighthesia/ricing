import Quickshell
import QtQuick
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
    // implicitHeight tracks the pill height (including flash expansion) so the
    // bar item expands downward into the non-exclusive zone during switch flashes.
    implicitHeight: _pill.implicitHeight + Theme.iconPadding
    implicitWidth: _pill.implicitWidth

    // --- structure constants ---
    // FIXME: _padH, _iconSize, _smallIcon, _iconSpacing, _pillGap, _pillPadH, _iconTitleGap
    //        are widget-specific layout values with no current Theme.* equivalent.
    //        Promote to Theme tokens when a design token pass is done for widget internals.
    readonly property int _revertDelay:  SettingsService.data.workspaceWidget.revertDelay
    readonly property int _revertCooldown:  50    // ms — post-revert hover-entry dead zone
    readonly property int _padH:         10   // horizontal padding inside the pill
    readonly property int _iconSize:     16   // app icon in focus mode
    readonly property int _smallIcon:    13   // app icon inside workspace pills
    readonly property int _iconSpacing:  3    // gap between icons in a workspace pill
    readonly property int _pillGap:      8    // gap between workspace pills
    readonly property int _pillPadH:     8    // horizontal padding inside each workspace pill
    readonly property int _iconTitleGap: 6    // gap between focus icon and title text
    readonly property int _titleMaxW:    SettingsService.data.workspaceWidget.titleMaxWidth
    readonly property bool _hoverActive: SettingsService.data.workspaceWidget.hoverEnabled
    readonly property int _pillH:        Theme.barHeight - 2 * Theme.iconPadding

    // --- state machine ---
    // _showOverview: render-driving boolean (step 6 — derived readonly before mutable state).
    // Explicit _modeOverride takes priority; natural state uses defaultMode setting.
    readonly property bool _showOverview: {
        if (_modeOverride === "overview") return true
        if (_modeOverride === "focus")    return false
        // Natural (unforced) state: use defaultMode setting
        if (SettingsService.data.workspaceWidget.defaultMode === "overview") return true
        return _focusedTitle.length === 0
    }

    // Suppresses all layout Behaviors during the first render cycle so the widget
    // doesn't animate from the default empty state to the real initial state.
    property bool _initialized: false

    // ""         = natural (overview when no focused window, focus otherwise)
    // "overview" = temporarily forced overview (hover from focus, workspace switch)
    // "focus"    = temporarily forced focus (hover from overview)
    property string _modeOverride: ""
    // --- flash animation constants ---
    readonly property int _flashRowH:   16   // height of the shrunken "previous state" strip
    readonly property int _flashGap:    4    // gap between main pill area and flash strip
    readonly property real _flashScale: 0.72 // scale factor applied to content in flash strip

    // --- flash state ---
    // true while the pill is expanded downward showing the switch transition.
    // Cleared by _revertTimer together with _modeOverride.
    property bool _flashActive: false

    // Snapshot of the state that was active *before* the switch occurred.
    // Rendered in the flash strip while _flashActive is true.
    property string _flashPrevTitle:  ""
    property string _flashPrevAppId:  ""
    property bool   _flashPrevWasOverview: false

    // Brief cooldown after auto-revert: ignores onEntered for _revertCooldown ms so the
    // pill growing back to focus size doesn't immediately re-trigger hover.
    property bool   _justReverted: false

    // --- focused window data ---
    property string _focusedWindowId: ""
    property string _focusedAppId: ""
    property string _focusedTitle:  ""

    function _refreshFocus() {
        let newWinId = ""
        let newAppId = ""
        let newTitle = ""
        for (let i = 0; i < NiriService.windows.count; i++) {
            const w = NiriService.windows.get(i)
            if (w.isFocused) {
                newWinId = w.winId
                newAppId = w.appId
                newTitle = (w.title === "Unknown") ? w.appId : w.title
                break
            }
        }
        // On window focus change: snapshot current state → trigger flash → flip mode.
        // winId-based comparison handles same-app multi-window switches.
        if (newWinId !== root._focusedWindowId && newWinId !== "") {
            // Capture what was showing before this switch.
            root._flashPrevTitle        = root._focusedTitle
            root._flashPrevAppId        = root._focusedAppId
            root._flashPrevWasOverview  = root._showOverview
            root._flashActive           = true

            if (root._modeOverride === "") {
                root._modeOverride = SettingsService.data.workspaceWidget.defaultMode === "overview"
                    ? "focus" : "overview"
            }
            _revertTimer.restart()
        }
        root._focusedWindowId = newWinId
        root._focusedAppId = newAppId
        root._focusedTitle = newTitle
    }

    // --- icon resolution ---
    function _iconPath(appId) {
        if (!appId) return Quickshell.iconPath("application-x-executable")
        const entry = DesktopEntries.heuristicLookup(appId)
        if (entry && entry.icon)
            return Quickshell.iconPath(entry.icon, "application-x-executable")
        return Quickshell.iconPath("application-x-executable")
    }

    // --- revert timer: 1.5 s after overview trigger, return to focus ---
    // Workspace switch: always starts the timer.
    // Hover: timer starts on EXIT, not on entry — overview holds while cursor is present.
    Timer {
        id: _revertTimer
        interval: root._revertDelay
        repeat: false
        onTriggered: {
            root._modeOverride = ""
            root._flashActive  = false
            // Start cooldown so the pill expanding back to focus size doesn't
            // immediately retrigger hover overview.
            root._justReverted = true
            _revertCooldownTimer.restart()
        }
    }

    Timer {
        id: _revertCooldownTimer
        interval: root._revertCooldown
        repeat: false
        onTriggered: root._justReverted = false
    }

    Component.onCompleted: {
        _refreshFocus()
        // Defer enabling Behaviors to the next event loop iteration so the initial
        // state renders without any startup animation flash.
        Qt.callLater(() => { root._initialized = true })
    }

    // Keep BarLayoutService.barFlashExtension in sync so BarWindow can expand its
    // drawing surface to accommodate the flash strip below the bar.
    Binding {
        target: BarLayoutService
        property: "barFlashExtension"
        value: root._flashActive ? (root._flashGap + root._flashRowH) : 0
        restoreMode: Binding.RestoreBindingOrValue
    }

    Connections {
        target: NiriService
        function onWindowsUpdated()      { root._refreshFocus() }
        function onWorkspaceActivated()  {
            // Snapshot current state before the mode flip so flash strip shows "before".
            root._flashPrevTitle       = root._focusedTitle
            root._flashPrevAppId       = root._focusedAppId
            root._flashPrevWasOverview = root._showOverview
            root._flashActive          = true

            // Flash to the *opposite* of the default mode so the user always sees
            // a state change after a workspace switch.
            root._modeOverride = SettingsService.data.workspaceWidget.defaultMode === "overview"
                ? "focus" : "overview"
            // If hovering, don't start revert — the hover exit will start it instead.
            if (!_hoverArea.containsMouse) _revertTimer.restart()
        }
    }

    // ─── Visual pill ──────────────────────────────────────────────────────
    // Single rounded rectangle; width animates between overview and focus sizes.
    // Height expands downward during switch flash to reveal the previous-state strip.
    Rectangle {
        id: _pill

        anchors.top: parent.top
        anchors.topMargin: Theme.iconPadding
        anchors.horizontalCenter: parent.horizontalCenter

        // Flash expansion: grow downward by _flashGap + _flashRowH when active.
        implicitHeight: root._flashActive
            ? (root._pillH + root._flashGap + root._flashRowH)
            : root._pillH
        height: implicitHeight

        Behavior on implicitHeight {
            enabled: root._initialized
            NumberAnimation {
                duration: Theme.anim.enterDuration
                easing.type: Theme.anim.enterType
                easing.amplitude: Theme.anim.enterAmplitude
                easing.period: Theme.anim.enterPeriod
            }
        }

        // Width is driven by _showOverview; animated by Behavior below.
        // Both content items report their implicitWidth; pill tracks the active one.
        implicitWidth: root._showOverview
            ? (_overviewRow.implicitWidth + root._padH * 2)
            : (_focusRow.implicitWidth   + root._padH * 2)

        Behavior on implicitWidth {
            enabled: root._initialized
            NumberAnimation {
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        radius: root._pillH / 2
        color: Colors.surface
        // Subtle hover tint for the entire pill
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Colors.highlight
            opacity: _hoverArea.containsMouse ? 0.08 : 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.anim.highlightDuration; easing.type: Theme.anim.highlightType }
            }
        }
        // ── Overview content — workspace pills row ───────────────────────
        Row {
            id: _overviewRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: undefined
            y: (root._pillH - implicitHeight) / 2   // centred within the main pill zone
            spacing: root._pillGap
            opacity: root._showOverview ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
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
                            if (w.workspaceId === _wsDelegate.wsId)
                                arr.push({ appId: w.appId, winId: w.winId, col: w.colIdx, row: w.rowIdx })
                        }
                        // Sort by visual position: left-to-right (col), then top-to-bottom (row).
                        arr.sort((a, b) => a.col !== b.col ? a.col - b.col : a.row - b.row)
                        _wsDelegate._appIds = arr.map(x => ({ appId: x.appId, winId: x.winId }))
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
                            enabled: root._initialized
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
                                    required property var modelData

                                    readonly property bool _isLoaded:  status === Image.Ready
                                    // Highlight only the exact focused window (winId), not all same-app icons.
                                    readonly property bool _isFocused: _wsDelegate.isActive && modelData.winId === root._focusedWindowId
                                    // Always reserve fixed space so layout stays stable during image load;
                                    // fade in via opacity instead of width jump.
                                    width:   root._smallIcon
                                    height:  root._smallIcon
                                    // Focused icon: full opacity + slight scale-up; others: dimmed.
                                    // Icons fade in from 0 while loading to prevent layout jumps.
                                    opacity: _isLoaded
                                        ? (_wsDelegate.isActive ? (_isFocused ? 1.0 : 0.5) : 0.75)
                                        : 0
                                    scale:   _isFocused ? 1.2 : 1.0
                                    source: root._iconPath(modelData.appId)
                                    smooth: true
                                    fillMode: Image.PreserveAspectFit

                                    Behavior on opacity { NumberAnimation { duration: Theme.anim.highlightDuration } }
                                    Behavior on scale   { NumberAnimation { duration: Theme.anim.highlightDuration; easing.type: Theme.anim.highlightType } }
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
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: undefined
            y: (root._pillH - implicitHeight) / 2   // centred within the main pill zone
            spacing: root._iconTitleGap
            opacity: root._showOverview ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
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

        // ── Flash strip — shrunken "before" snapshot shown during switch ─
        // Positioned at the bottom of the expanded pill; fades out when flash ends.
        Item {
            id: _flashStrip
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.leftMargin:  root._padH
            anchors.rightMargin: root._padH
            y: root._pillH + root._flashGap
            height: root._flashRowH

            opacity: root._flashActive ? 0.55 : 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.anim.exitDuration; easing.type: Theme.anim.exitType }
            }

            // Shrunken Focus strip — shows when previous state was Focus mode
            Row {
                id: _flashFocusRow
                anchors.centerIn: parent
                spacing: Math.round(root._iconTitleGap * root._flashScale)
                visible: !root._flashPrevWasOverview

                Image {
                    width:  Math.round(root._iconSize * root._flashScale)
                    height: Math.round(root._iconSize * root._flashScale)
                    anchors.verticalCenter: parent.verticalCenter
                    source: root._iconPath(root._flashPrevAppId)
                    smooth: true
                    fillMode: Image.PreserveAspectFit
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, Math.round(root._titleMaxW * root._flashScale))
                    text: root._flashPrevTitle
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    font.family: Theme.fontFamily
                    font.pixelSize: Math.round(Theme.fontSizeSmall * root._flashScale)
                    color: Colors.textMuted
                }
            }

            // Shrunken Overview strip — shows when previous state was Overview mode
            Row {
                id: _flashOverviewRow
                anchors.centerIn: parent
                spacing: Math.round(root._pillGap * root._flashScale)
                visible: root._flashPrevWasOverview

                Repeater {
                    model: NiriService.workspaces
                    delegate: Item {
                        required property string wsId
                        required property int    idx
                        required property bool   isActive

                        // Reuse the same per-workspace icon data from the live model.
                        readonly property var _wsIcons: {
                            let arr = []
                            for (let i = 0; i < NiriService.windows.count; i++) {
                                const w = NiriService.windows.get(i)
                                if (w.workspaceId === wsId) arr.push(w.appId)
                            }
                            return arr
                        }

                        visible: isActive || _wsIcons.length > 0
                        width:  visible ? _miniPill.width  : 0
                        height: visible ? _miniPill.height : 0

                        Rectangle {
                            id: _miniPill
                            height: root._flashRowH
                            width: Math.max(
                                _miniIcons.implicitWidth + Math.round(root._pillPadH * root._flashScale) * 2,
                                root._flashRowH
                            )
                            radius: height / 2
                            color: isActive ? Colors.highlight : Colors.surface
                            opacity: 0.8

                            Row {
                                id: _miniIcons
                                anchors.centerIn: parent
                                spacing: Math.round(root._iconSpacing * root._flashScale)

                                Repeater {
                                    model: _wsIcons
                                    delegate: Image {
                                        required property string modelData
                                        readonly property bool _ok: status === Image.Ready
                                        width:  _ok ? Math.round(root._smallIcon * root._flashScale) : 0
                                        height: _ok ? Math.round(root._smallIcon * root._flashScale) : 0
                                        source: root._iconPath(modelData)
                                        smooth: true
                                        fillMode: Image.PreserveAspectFit
                                    }
                                }

                                Text {
                                    visible: _wsIcons.length === 0
                                    text: idx
                                    font.family: Theme.fontMono
                                    font.bold: true
                                    font.pixelSize: Math.round(Theme.fontSizeSmall * root._flashScale)
                                    color: isActive ? Colors.background : Colors.textMuted
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Hover area covers only the main pill zone (not the flash strip below),
    // so the expansion area doesn't accidentally trigger hover revert.
    MouseArea {
        id: _hoverArea
        anchors.left:  parent.left
        anchors.right: parent.right
        anchors.top:   parent.top
        height: Theme.barHeight
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            if (!root._hoverActive || root._justReverted) return
            _revertTimer.stop()
            // If already overridden (e.g. re-entry after moving out briefly), just
            // hold the current state rather than flipping back immediately.
            if (root._modeOverride !== "") return
            // Flip to opposite of current visual state.
            root._modeOverride = root._showOverview ? "focus" : "overview"
        }
        onExited: _revertTimer.restart()
    }
}
