import Quickshell
import QtQuick
import qs.config
import qs.services
import ".." as BarComponents

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
    // implicitHeight is constant (only pill height + padding) so the bar row never
    // shifts upward when the flash strip expands below — the pill overflows downward
    // visually without disturbing the parent Row's vertical-centre anchor.
    implicitHeight: _pillH + Theme.iconPadding
    implicitWidth: _pill.implicitWidth

    // --- structure constants ---
    readonly property int _revertDelay:  SettingsService.data.workspaceWidget.revertDelay
    readonly property int _revertCooldown:  50    // ms — post-revert hover-entry dead zone
    readonly property int _padH:         Theme.barWidget.contentPaddingH
    readonly property int _iconSize:     Theme.barWidget.primaryIconSize
    readonly property int _smallIcon:    Theme.barWidget.compactIconSize
    readonly property int _iconSpacing:  Theme.barWidget.iconSpacing
    readonly property int _pillGap:      Theme.barWidget.pillSpacing
    readonly property int _pillPadH:     Theme.barWidget.pillPaddingH
    readonly property int _iconTitleGap: Theme.barWidget.iconLabelSpacing
    readonly property int _focusPulsePad: Theme.barWidget.focusPulsePadding
    readonly property int _titleMaxW:    SettingsService.data.workspaceWidget.titleMaxWidth
    readonly property bool _hoverActive: SettingsService.data.workspaceWidget.hoverEnabled
    readonly property int _pillH:        Theme.barHeight - 2 * Theme.iconPadding
    readonly property real _focusPillWidth: root._harnessFocusWidthOverride >= 0
        ? root._harnessFocusWidthOverride
        : (_focusRow.implicitWidth + root._padH * 2)
    readonly property real _overviewPillWidth: root._harnessOverviewWidthOverride >= 0
        ? root._harnessOverviewWidthOverride
        : (_overviewRow.implicitWidth + root._padH * 2)
    readonly property real _collapsedPillWidth: Math.min(root._focusPillWidth, root._overviewPillWidth)
    readonly property real _expandedPillWidth: Math.max(root._focusPillWidth, root._overviewPillWidth)
    readonly property real _flashPillWidth:
        Math.max(_overviewRow.implicitWidth, _focusRow.implicitWidth) + root._padH * 2
    readonly property real _transitionExpandedWidth:
        root._flashActive ? root._flashPillWidth : root._expandedPillWidth
    readonly property real _transitionExpandedHeight:
        root._flashActive
            ? (root._pillH + root._flashGap + root._flashRowH)
            : root._pillH
    readonly property int _returnSyncDuration:
        Theme.anim.moveDuration
    readonly property bool _showExpandedPillWidth: root._showOverview
        ? root._overviewPillWidth >= root._focusPillWidth
        : root._focusPillWidth >= root._overviewPillWidth
    readonly property real _sharedBackgroundPulseOpacity: _pillTransition.pulseOpacity
    readonly property real _sharedPulseScale: _pillTransition.pulseScale

    // --- state machine ---
    // _showOverview: render-driving boolean (step 6 — derived readonly before mutable state).
    // Explicit _modeOverride takes priority; natural state uses defaultMode setting.
    readonly property bool _showOverview: {
        if (_emptyWorkspaceSettling) return true
        if (_modeOverride === "overview") return true
        if (_modeOverride === "focus")    return false
        // Natural (unforced) state: use defaultMode setting
        if (SettingsService.data.workspaceWidget.defaultMode === "overview") return true
        return _focusedTitle.length === 0
    }

    // Suppresses all layout Behaviors during the first render cycle so the widget
    // doesn't animate from the default empty state to the real initial state.
    property bool _initialized: false
    property real _harnessFocusWidthOverride: -1
    property real _harnessOverviewWidthOverride: -1

    // ""         = natural (overview when no focused window, focus otherwise)
    // "overview" = temporarily forced overview (hover from focus, workspace switch)
    // "focus"    = temporarily forced focus (hover from overview)
    property string _modeOverride: ""

    // --- flash animation constants ---
    // _flashRowH = _pillH: expansion strip is one full component height,
    // making total expanded pill = 2 component heights for better readability.
    readonly property int  _flashRowH:   _pillH
    readonly property int  _flashGap:    4    // gap between main pill and flash strip
    readonly property real _flashScale:  0.85 // departing content scale in flash area

    // --- flash state ---
    // true while the pill is expanded downward showing the switch transition.
    // The default-mode row travels to the flash strip; the alt-mode row fills the pill.
    // Cleared by _revertTimer together with _modeOverride.
    property bool _flashActive: false
    // Snapshot of which mode was already visible in the pill when the flash started.
    property bool _flashSourceWasOverview: false
    // True while an active flash is gently settling into an overview state
    // caused by an empty workspace or temporary loss of focused window.
    property bool _emptyWorkspaceSettling: false
    // Keep the bar surface expanded while the collapse animation is running;
    // releasing it only after collapse avoids per-frame window resize jank.
    property bool _holdFlashExtension: false

    // Which mode was active as the "default" when the flash triggered — the row
    // for this mode will travel to the flash strip; always derived from settings.
    // We don't need a snapshot because content stays live throughout the animation.
    readonly property bool _flashDefaultIsOverview:
        SettingsService.data.workspaceWidget.defaultMode === "overview"

    // Brief cooldown after auto-revert: ignores onEntered for _revertCooldown ms so the
    // pill growing back to focus size doesn't immediately re-trigger hover.
    property bool   _justReverted: false
    // Set by onWorkspaceActivated to suppress the side-effect onWindowsUpdated call
    // (which fires right after the switch with the live model already cleared, and
    // would otherwise re-trigger a second flash on the new workspace).
    // Cleared on the first non-skip _refreshFocus() call, or on flash revert.
    property bool   _justSwitchedWorkspace: false

    // --- focused window data ---
    property string _focusedWindowId: ""
    property string _focusedAppId: ""
    property string _focusedTitle:  ""

    function _triggerFlash() {
        _flashCollapseReleaseTimer.stop()
        root._flashSourceWasOverview = root._showOverview
        root._holdFlashExtension = true
        root._flashActive = true
    }

    function _releaseFlashExtensionIfReady() {
        if (!root._flashActive)
            root._holdFlashExtension = false
    }

    function _activeWorkspaceHasWindows() {
        let activeWsId = ""
        for (let i = 0; i < NiriService.workspaces.count; i++) {
            const ws = NiriService.workspaces.get(i)
            if (ws.isActive) {
                activeWsId = ws.wsId
                break
            }
        }
        if (activeWsId === "") return false
        for (let j = 0; j < NiriService.windows.count; j++) {
            if (NiriService.windows.get(j).workspaceId === activeWsId)
                return true
        }
        return false
    }

    function _settleFlashToOverview() {
        _revertTimer.stop()
        _emptyWorkspaceSyncTimer.stop()
        root._emptyWorkspaceSettling = true
        root._modeOverride = ""
        root._flashActive = false
        _flashCollapseReleaseTimer.restart()
        _emptyWorkspaceSyncTimer.restart()
    }

    // skipFlash: pass true when called from onWorkspaceActivated so the workspace-
    // switch snapshot is not overwritten by a secondary window-focus-change flash.
    function _refreshFocus(skipFlash) {
        const prevWinId = root._focusedWindowId
        let newWinId = ""
        let newAppId = ""
        let newTitle = ""
        let suppress = false
        for (let i = 0; i < NiriService.windows.count; i++) {
            const w = NiriService.windows.get(i)
            if (w.isFocused) {
                newWinId = w.winId
                newAppId = w.appId
                newTitle = (w.title === "Unknown") ? w.appId : w.title
                break
            }
        }
        if (!skipFlash) {
            // Consume the workspace-switch suppression flag on the first non-skip call.
            // This prevents the onWindowsUpdated that fires right after onWorkspaceActivated
            // (with _focusedTitle already cleared) from overwriting the snapshot.
            suppress = root._justSwitchedWorkspace
            root._justSwitchedWorkspace = false
            // On window focus change: snapshot current state → trigger flash → flip mode.
            // winId-based comparison handles same-app multi-window switches.
            if (!suppress && newWinId !== root._focusedWindowId && newWinId !== "") {
                _triggerFlash()

                if (root._modeOverride === "") {
                    root._modeOverride = SettingsService.data.workspaceWidget.defaultMode === "overview"
                        ? "focus" : "overview"
                }
                _revertTimer.restart()
            }
        }

        // During the immediate workspace-switch gap, Niri can briefly report no
        // focused window before the new workspace focus arrives. Preserve the
        // current snapshot only for that suppressed update. Otherwise, if focus
        // genuinely disappears while flash is active, settle quickly into overview.
        if (root._flashActive && newWinId === "") {
            if (suppress)
                return
            root._settleFlashToOverview()
            return
        }

        root._focusedWindowId = newWinId
        root._focusedAppId = newAppId
        root._focusedTitle = newTitle

        const shouldPulseFocusRow = !skipFlash
            && root._initialized
            && !root._flashActive
            && prevWinId !== ""
            && newWinId !== ""
            && newWinId !== prevWinId
        if (shouldPulseFocusRow)
            _focusRow.triggerFocusChangePulse()
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
            root._emptyWorkspaceSettling = false
            root._modeOverride = ""
            root._flashActive  = false
            root._justSwitchedWorkspace = false  // safety clear in case no onWindowsUpdated fired
            _flashCollapseReleaseTimer.restart()
            _refreshFocus(true)
            // Start cooldown so the pill expanding back to focus size doesn't
            // immediately retrigger hover overview.
            root._justReverted = true
            _revertCooldownTimer.restart()
        }
    }

    Timer {
        id: _flashCollapseReleaseTimer
        interval: Theme.anim.moveDuration
        repeat: false
        onTriggered: root._releaseFlashExtensionIfReady()
    }

    Timer {
        id: _emptyWorkspaceSyncTimer
        interval: Theme.anim.moveDuration
        repeat: false
        onTriggered: {
            root._justSwitchedWorkspace = false
            _refreshFocus(true)
            root._emptyWorkspaceSettling = false
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

    // Keep barFlashExtension locked while flash is active (and briefly during collapse)
    // so BarWindow doesn't resize every animation frame. This removes compositor churn
    // while preserving enough surface area to avoid clipping during collapse.
    Binding {
        target: BarLayoutService
        property: "workspaceFlashExtension"
        value: (root._flashActive || root._holdFlashExtension)
            ? (root._flashGap + root._flashRowH)
            : 0
        restoreMode: Binding.RestoreBindingOrValue
    }

    BarComponents.BarExpandTransition {
        id: _pillTransition
        objectName: "workspaceSharedTransition"

        collapsedWidth: root._collapsedPillWidth
        expandedWidth: root._transitionExpandedWidth
        collapsedHeight: root._pillH
        expandedHeight: root._transitionExpandedHeight
        expanded: root._flashActive ? true : root._showExpandedPillWidth
        animateWidth: true
        animateHeight: true
    }

    Connections {
        target: NiriService
        function onWindowsUpdated()      { root._refreshFocus() }
        function onWorkspaceActivated()  {
            // Suppress the onWindowsUpdated that fires as a side-effect of this switch
            // to prevent a second flash from triggering on the already-cleared window state.
            root._justSwitchedWorkspace = true

            // Determine the target workspace state first so we can avoid blanking the
            // currently displayed focus row while an active flash is still visible.
            const hasWindows = root._activeWorkspaceHasWindows()

            if (!hasWindows) {
                if (root._flashActive) {
                    root._settleFlashToOverview()
                    return
                }

                // No active flash: sync to the empty workspace immediately.
                root._emptyWorkspaceSettling = false
                root._justSwitchedWorkspace = false
                _refreshFocus(true)
                return
            }

            // Eagerly wipe stale focus state before re-querying the windows model.
            root._focusedWindowId = ""
            root._focusedAppId    = ""
            root._focusedTitle    = ""
            _refreshFocus(true)

            _triggerFlash()
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
    //
    // Clip wrapper: height jumps to full flash size immediately
    // so travelling rows are never clipped by the elastic pill-surface animation.
    // The visual pill background lives inside and follows the elastic Behavior.
    Item {
        id: _pill
        objectName: "workspacePillClip"

        anchors.top: parent.top
        anchors.topMargin: Theme.iconPadding
        anchors.horizontalCenter: parent.horizontalCenter

        clip: true
        width: _pillTransition.animatedWidth
        scale: root._sharedPulseScale
        transformOrigin: Item.Center

        // Clip height: immediate during flash so rows are never clipped mid-travel.
        implicitHeight: root._flashActive || root._holdFlashExtension
            ? (root._pillH + root._flashGap + root._flashRowH)
            : root._pillH
        height: Math.max(implicitHeight, _pillTransition.animatedHeight)

        // During flash, hold the max of both rows' widths so the row in the flash
        // strip (which may be wider than the pill row) doesn't cause overflow.
        // After flash, collapses smoothly to the active row's width.
        implicitWidth: _pillTransition.animatedWidth

        // Visual pill background: height follows explicit animation for bounce/collapse.
        // Separated from the clip wrapper so clipping doesn't cut travelling rows.
        Rectangle {
            id: _pillBg
            objectName: "workspacePillBackground"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top

            width: _pillTransition.animatedWidth
            height: _pillTransition.animatedHeight

            radius: root._pillH / 2
            color: Colors.surface
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: root._pillH + Math.max(0, (root._flashGap - height) / 2)
            width: Math.max(0, _pillBg.width - root._padH * 2)
            height: 1
            radius: height / 2
            color: Colors.border
            opacity: (root._flashActive || root._holdFlashExtension) ? 0.35 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
                }
            }
        }

        Rectangle {
            anchors.fill: _pillBg
            radius: _pillBg.radius
            color: Colors.highlight
            opacity: root._sharedBackgroundPulseOpacity
        }

        // Subtle hover tint for the entire pill
        Rectangle {
            anchors.fill: _pillBg
            radius: _pillBg.radius
            color: Colors.highlight
            opacity: _hoverArea.containsMouse ? 0.12 : 0
            Behavior on opacity {
                NumberAnimation { duration: Theme.anim.highlightDuration; easing.type: Theme.anim.highlightType }
            }
        }
        // ── Overview content — workspace pills row ───────────────────────
        Row {
            id: _overviewRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: undefined

            // When flash is active and overview is the default mode, this row travels
            // to the flash strip below; the pill simultaneously shows focus content.
            // When flash is active and focus is the default mode, this row fills the pill
            // as the temporary alt-mode display (no position change needed).
            readonly property bool _isInFlashStrip: root._flashActive && root._flashDefaultIsOverview

            readonly property real _normalY: (root._pillH - implicitHeight) / 2 - (root._showOverview ? 0 : root._pillH)
            // Flash strip center Y — used by both depart animation and late-content recentering.
            readonly property real _flashStripY: root._pillH + root._flashGap + (root._flashRowH - implicitHeight) / 2

            // y is managed imperatively. Qt.callLater defers any normalY snap by one
            // event loop tick, surviving transient _showOverview flips that occur when
            // the window model briefly reports no focused window mid-refresh.
            on_NormalYChanged: {
                if (_isInFlashStrip || _departYAnim.running || _overviewReturnAnim.running
                    || _overviewEnterAnim.running || _overviewExitAnim.running) return
                Qt.callLater(() => {
                    if (!_overviewRow._isInFlashStrip && !_departYAnim.running && !_overviewReturnAnim.running
                        && !_overviewEnterAnim.running && !_overviewExitAnim.running)
                        _overviewRow.y = _overviewRow._normalY
                })
            }
            // Recenter in flash strip when content height changes after depart started
            // (e.g. workspace icons appearing asynchronously).
            onImplicitHeightChanged: {
                if (_isInFlashStrip) {
                    let newY = root._pillH + root._flashGap + (root._flashRowH - implicitHeight) / 2
                    if (_departYAnim.running) {
                        _departYAnim.stop()
                        _departYAnim.from = _overviewRow.y
                        _departYAnim.to   = newY
                        _departYAnim.start()
                    } else {
                        _overviewRow.y = newY
                    }
                } else if (_overviewEnterAnim.running) {
                    _overviewEnterAnim.stop()
                    _overviewRow.scale = 1.0
                    _overviewRow.y = _overviewRow._normalY
                }
            }
            scale: 1.0
            spacing: root._pillGap
            opacity: _isInFlashStrip ? 0.55 : (root._showOverview ? 1 : 0)

            on_IsInFlashStripChanged: {
                if (_isInFlashStrip) {
                    _overviewReturnAnim.stop()
                    _departYAnim.from  = _overviewRow.y
                    _departYAnim.to    = _overviewRow._flashStripY
                    _departScaleAnim.from = _overviewRow.scale
                    _departScaleAnim.to   = root._flashScale
                    _departYAnim.start()
                    _departScaleAnim.start()
                    if (root._flashSourceWasOverview) {
                        // The other row (focus) was not previously visible, so it
                        // needs the enter animation into the pill.
                        _focusEnterAnim.stop()
                        _focusRow.scale = 0.9
                        _focusRow.y = -Math.max(_focusRow.implicitHeight, root._pillH)
                        _focusEnterAnim.start()
                    } else {
                        _focusEnterAnim.stop()
                        _focusRow.scale = 1.0
                        _focusRow.y = _focusRow._normalY
                    }
                } else if (root._initialized) {
                    _departYAnim.stop()
                    _departScaleAnim.stop()
                    _overviewReturnAnim.stop()
                    _overviewReturnAnim.fromY = _overviewRow.y
                    _overviewReturnAnim.toY = _normalY
                    _overviewReturnAnim.fromScale = _overviewRow.scale
                    _overviewReturnAnim.toScale = 1.0
                    _overviewReturnAnim.start()
                    // The other row (focus) exits the pill — slide up + scale down
                    _focusEnterAnim.stop()
                    _focusExitAnim.stop()
                    _focusExitAnim.start()
                } else {
                    _overviewRow.y = _normalY
                    _overviewRow.scale = 1.0
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
                }
            }

            // Entrance animation for hover/flash reveal (scale 0.9→1.0 + Y slide to center)
            ParallelAnimation {
                id: _overviewEnterAnim
                NumberAnimation {
                    target: _overviewRow; property: "scale"
                    from: 0.9; to: 1.0
                    duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType
                }
                NumberAnimation {
                    target: _overviewRow; property: "y"
                    to: _overviewRow._normalY
                    duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType
                }
            }

            // Exit animation for hover/flash revert (scale 1.0→0.9 + Y slide up)
            ParallelAnimation {
                id: _overviewExitAnim
                NumberAnimation {
                    target: _overviewRow; property: "scale"
                    to: 0.9
                    duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType
                }
                NumberAnimation {
                    target: _overviewRow; property: "y"
                    to: -_overviewRow.implicitHeight
                    duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType
                }
                onFinished: {
                    _overviewRow.y = _overviewRow._normalY
                    _overviewRow.scale = 1.0
                }
            }

            NumberAnimation {
                id: _departYAnim
                target: _overviewRow; property: "y"
                duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType
            }
            NumberAnimation {
                id: _departScaleAnim
                target: _overviewRow; property: "scale"
                duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType
            }
            ParallelAnimation {
                id: _overviewReturnAnim
                property real fromY: _overviewRow.y
                property real toY: _overviewRow._normalY
                property real fromScale: _overviewRow.scale
                property real toScale: 1.0

                NumberAnimation {
                    target: _overviewRow; property: "y"
                    from: _overviewReturnAnim.fromY
                    to: _overviewReturnAnim.toY
                    duration: root._returnSyncDuration; easing.type: Theme.anim.moveType
                }
                NumberAnimation {
                    target: _overviewRow; property: "scale"
                    from: _overviewReturnAnim.fromScale
                    to: _overviewReturnAnim.toScale
                    duration: root._returnSyncDuration; easing.type: Theme.anim.moveType
                }

                onFinished: root._releaseFlashExtensionIfReady()
            }

            Component.onCompleted: {
                _overviewRow.y = _overviewRow._normalY
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
        Item {
            id: _focusRow
            objectName: "workspaceFocusRow"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: undefined
            implicitWidth: _focusContent.implicitWidth
            implicitHeight: _focusContent.implicitHeight
            width: implicitWidth
            height: implicitHeight
            clip: false

            // When flash is active and focus is the default mode, this row travels
            // to the flash strip below; the pill simultaneously shows overview content.
            // When flash is active and overview is the default mode, this row fills the
            // pill as the temporary alt-mode display (no position change needed).
            readonly property bool _isInFlashStrip: root._flashActive && !root._flashDefaultIsOverview

            readonly property real _normalY: (root._pillH - implicitHeight) / 2
            // Flash strip center Y — used by both depart animation and late-content recentering.
            readonly property real _flashStripY: root._pillH + root._flashGap + (root._flashRowH - implicitHeight) / 2
            property real _pulseOpacity: 0

            function triggerFocusChangePulse() {
                if (root._focusedWindowId.length === 0 || root._focusedTitle.length === 0) return
                if (opacity <= 0) return
                _focusPulseAnim.stop()
                _pulseOpacity = 0
                _focusPulseAnim.start()
            }

            // y is managed imperatively. Qt.callLater defers any normalY snap by one
            // event loop tick, surviving transient focusedAppId="" states that occur
            // when the window model briefly clears between workspace-switch events.
            on_NormalYChanged: {
                if (_isInFlashStrip || _focusDepartYAnim.running || _focusReturnAnim.running
                    || _focusEnterAnim.running || _focusExitAnim.running) return
                Qt.callLater(() => {
                    if (!_focusRow._isInFlashStrip && !_focusDepartYAnim.running && !_focusReturnAnim.running
                        && !_focusEnterAnim.running && !_focusExitAnim.running)
                        _focusRow.y = _focusRow._normalY
                })
            }
            // Recenter in flash strip when content height changes after depart started
            // (e.g. title text appearing after late window-focus event from Niri).
            // Compute target inline — _flashStripY binding may not yet be refreshed
            // inside the onImplicitHeightChanged handler.
            onImplicitHeightChanged: {
                if (_isInFlashStrip) {
                    let newY = root._pillH + root._flashGap + (root._flashRowH - implicitHeight) / 2
                    if (_focusDepartYAnim.running) {
                        _focusDepartYAnim.stop()
                        _focusDepartYAnim.from = _focusRow.y
                        _focusDepartYAnim.to   = newY
                        _focusDepartYAnim.start()
                    } else {
                        _focusRow.y = newY
                    }
                } else if (_focusEnterAnim.running) {
                    _focusEnterAnim.stop()
                    _focusRow.scale = 1.0
                    _focusRow.y = _focusRow._normalY
                }
            }
            scale: 1.0
            opacity: _isInFlashStrip ? 0.55 : (root._showOverview ? 0 : 1)

            Rectangle {
                x: -root._focusPulsePad
                y: -root._focusPulsePad
                width: parent.width + root._focusPulsePad * 2
                height: parent.height + root._focusPulsePad * 2
                radius: height / 2
                color: Colors.highlight
                opacity: _focusRow._pulseOpacity
            }

            on_IsInFlashStripChanged: {
                if (_isInFlashStrip) {
                    _focusReturnAnim.stop()
                    _focusEnterAnim.stop()
                    _focusDepartYAnim.from  = _focusRow.y
                    _focusDepartYAnim.to    = _focusRow._flashStripY
                    _focusDepartScaleAnim.from = _focusRow.scale
                    _focusDepartScaleAnim.to   = root._flashScale
                    _focusDepartYAnim.start()
                    _focusDepartScaleAnim.start()
                    if (!root._flashSourceWasOverview) {
                        // The other row (overview) was not previously visible, so it
                        // needs the enter animation into the pill.
                        _overviewEnterAnim.stop()
                        _overviewRow.scale = 0.9
                        _overviewRow.y = -Math.max(_overviewRow.implicitHeight, root._pillH)
                        _overviewEnterAnim.start()
                    } else {
                        _overviewEnterAnim.stop()
                        _overviewRow.scale = 1.0
                        _overviewRow.y = _overviewRow._normalY
                    }
                } else if (root._initialized) {
                    _focusDepartYAnim.stop()
                    _focusDepartScaleAnim.stop()
                    _focusReturnAnim.stop()
                    _focusReturnAnim.fromY = _focusRow.y
                    _focusReturnAnim.toY = _normalY
                    _focusReturnAnim.fromScale = _focusRow.scale
                    _focusReturnAnim.toScale = 1.0
                    _focusReturnAnim.start()
                    if (root._emptyWorkspaceSettling) {
                        _overviewExitAnim.stop()
                        _overviewEnterAnim.stop()
                        _overviewRow.y = _overviewRow._normalY
                        _overviewRow.scale = 1.0
                    } else {
                        // The other row (overview) exits the pill — slide up + scale down
                        _overviewEnterAnim.stop()
                        _overviewExitAnim.stop()
                        _overviewExitAnim.start()
                    }
                } else {
                    _focusRow.y = _normalY
                    _focusRow.scale = 1.0
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
                }
            }

            SequentialAnimation {
                id: _focusPulseAnim
                NumberAnimation {
                    target: _focusRow
                    property: "_pulseOpacity"
                    from: 0
                    to: 0.16
                    duration: Theme.anim.highlightDuration
                    easing.type: Theme.anim.highlightType
                }
                NumberAnimation {
                    target: _focusRow
                    property: "_pulseOpacity"
                    to: 0
                    duration: Theme.anim.moveDuration
                    easing.type: Theme.anim.moveType
                }
            }

            // Entrance animation for hover/flash reveal (scale 0.9→1.0 + Y slide to center)
            ParallelAnimation {
                id: _focusEnterAnim
                NumberAnimation {
                    target: _focusRow; property: "scale"
                    from: 0.9; to: 1.0
                    duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType
                }
                NumberAnimation {
                    target: _focusRow; property: "y"
                    to: _focusRow._normalY
                    duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType
                }
            }

            // Exit animation for hover/flash revert (scale 1.0→0.9 + Y slide up)
            ParallelAnimation {
                id: _focusExitAnim
                NumberAnimation {
                    target: _focusRow; property: "scale"
                    to: 0.9
                    duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType
                }
                NumberAnimation {
                    target: _focusRow; property: "y"
                    to: -_focusRow.implicitHeight
                    duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType
                }
                onFinished: {
                    _focusRow.y = _focusRow._normalY
                    _focusRow.scale = 1.0
                }
            }

            NumberAnimation {
                id: _focusDepartYAnim
                target: _focusRow; property: "y"
                duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType
            }
            NumberAnimation {
                id: _focusDepartScaleAnim
                target: _focusRow; property: "scale"
                duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType
            }
            ParallelAnimation {
                id: _focusReturnAnim
                property real fromY: _focusRow.y
                property real toY: _focusRow._normalY
                property real fromScale: _focusRow.scale
                property real toScale: 1.0

                NumberAnimation {
                    target: _focusRow; property: "y"
                    from: _focusReturnAnim.fromY
                    to: _focusReturnAnim.toY
                    duration: root._returnSyncDuration; easing.type: Theme.anim.moveType
                }
                NumberAnimation {
                    target: _focusRow; property: "scale"
                    from: _focusReturnAnim.fromScale
                    to: _focusReturnAnim.toScale
                    duration: root._returnSyncDuration; easing.type: Theme.anim.moveType
                }

                onFinished: root._releaseFlashExtensionIfReady()
            }

            Component.onCompleted: {
                _focusRow.y = _focusRow._normalY
            }

            Row {
                id: _focusContent
                anchors.centerIn: parent
                spacing: root._iconTitleGap

                Image {
                    id: _focusIcon
                    visible: root._focusedAppId.length > 0
                    width:  visible ? root._iconSize : 0
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
                    // Do NOT reference _focusRow.parent.width here — that would create a
                    // circular binding (pill width → focus row → text → pill width).
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
            // Don't flip to focus mode when there is no focused window.
            if (root._showOverview && root._focusedTitle.length === 0) return
            // produce the same flash transition that workspace switches use so the
            // user perceives a full state change, not just a silent color swap.
            _triggerFlash()
            // Flip to opposite of current visual state.
            root._modeOverride = root._showOverview ? "focus" : "overview"
        }
        onExited: _revertTimer.restart()
    }
}
