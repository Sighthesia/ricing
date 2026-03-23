import Quickshell
import QtQuick
import qs.config
import qs.services as Services
import qs.modules.bar
import "../../../modules/bar/widgets" as BarWidgets

Item {
    id: root

    required property var barLayoutService

    readonly property string _mode: Quickshell.env("QS_BAR_TRANSIENT_REVEAL_MODE") || "registry"
    property var _activeHost: null
    property var _trayWidget: null
    property var _trayFixture: null
    property var _workspaceWidget: null
    property var _superIslandPreviewWidget: null
    property var _superIslandLiveWidget: null
    property var _superIslandEvent: null
    property var _sharedCollapseTransition: null
    property var _statePath: []
    property string _phase: "idle"
    property string _trayPhase: "idle"
    property string _workspacePhase: "idle"
    property string _superIslandPhase: "idle"
    property int _trayPollCount: 0
    property int _workspacePollCount: 0
    property int _superIslandPollCount: 0
    property bool _superIslandSawConcurrentCloseStart: false
    property int _allModeIndex: -1
    property bool _workspaceSawPulseDuringOpen: false
    property bool _workspaceSawRetriggeredPulse: false
    property bool _workspaceSawRetriggerSettle: false
    property real _workspacePulseBaselineOpacity: 0
    property real _workspacePulseBaselineScale: 1
    property real _workspaceRetriggerPeakWidth: 0
    property int _workspaceBurstSwitchCount: 0
    property int _workspacePulseEpisodeCount: 0
    property bool _workspacePulseWasActive: false
    property int _workspacePulseActivePollCount: 0
    property real _workspaceBurstBaselineOpacity: 0
    property real _workspaceBurstBaselineScale: 1
    property bool _workspaceSawBurstReplay: false

    function _workspaceContentProgress() {
        if (!root._workspaceWidget || root._workspaceWidget._contentColumnShift <= 0)
            return 0

        return (root._workspaceWidget._contentColumnY + root._workspaceWidget._contentColumnShift)
            / root._workspaceWidget._contentColumnShift
    }

    function _workspaceSurfaceProgress() {
        if (!root._workspaceWidget || (root._workspaceWidget._flashGap + root._workspaceWidget._flashRowH) <= 0)
            return 0

        return (root._workspaceWidget._pillBackgroundHeight - root._workspaceWidget._pillH)
            / (root._workspaceWidget._flashGap + root._workspaceWidget._flashRowH)
    }

    function _workspaceExpectedColumnY() {
        if (!root._workspaceWidget)
            return 0

        const collapsedY = root._workspaceWidget._flashActive
            ? (root._workspaceWidget._flashSourceWasOverview ? 0 : -root._workspaceWidget._contentColumnShift)
            : (root._workspaceWidget._showOverview ? 0 : -root._workspaceWidget._contentColumnShift)

        return collapsedY * (1 - root._workspaceWidget._verticalRevealProgress)
    }

    function _workspaceSharedPulseActive() {
        if (!root._workspaceWidget)
            return false

        return root._workspaceWidget._sharedBackgroundPulseOpacity > 0.01
            || root._workspaceWidget._sharedPulseScale > 1.01
    }

    readonly property var _allModeSequence: [
        "registry",
        "host-open-close",
        "host-retarget",
        "tray",
        "workspace",
        "shared-collapse",
        "super-island"
    ]
    Component {
        id: _openCloseHostComponent

        BarTransientRevealHost {
            collapsedHeight: 24
            expandedHeight: 60
            expanded: false
            extensionOwnerKey: "host-open-close"
            animateSurface: false
        }
    }

    Component {
        id: _retargetHostComponent

        BarTransientRevealHost {
            collapsedHeight: 20
            expandedHeight: 56
            expanded: false
            extensionOwnerKey: "host-retarget"
            animateSurface: false
        }
    }

    Component {
        id: _trayWidgetComponent

        BarWidgets.SystemTrayWidget {
            liveInstance: true
        }
    }

    Component {
        id: _trayFixtureComponent

        QtObject {
            property string id: "tray-test-item"
            property string tooltipTitle: "tray-test-title"
            property string tooltipDescription: "tray-test-description"
            property string icon: "tray-test-icon"
        }
    }

    Component {
        id: _workspaceWidgetComponent

        BarWidgets.WorkspaceWidget {
        }
    }

    Component {
        id: _superIslandPreviewWidgetComponent

        BarWidgets.SuperIslandWidget {
            liveInstance: false
        }
    }

    Component {
        id: _superIslandLiveWidgetComponent

        BarWidgets.SuperIslandWidget {
            liveInstance: true
        }
    }

    Component {
        id: _sharedCollapseTransitionComponent

        BarExpandTransition {
            collapsedWidth: 100
            expandedWidth: 160
            collapsedHeight: 32
            expandedHeight: 64
            expanded: true
            animateWidth: true
            animateHeight: true
        }
    }

    function _fail(message) {
        throw new Error(message)
    }

    function _runAllModeNext() {
        root._allModeIndex += 1
        if (root._allModeIndex >= root._allModeSequence.length) {
            Qt.quit()
            return
        }

        let mode = root._allModeSequence[root._allModeIndex]

        if (mode === "registry") {
            _verifyRegistryContract()
            _runAllModeNext()
            return
        }

        if (mode === "host-open-close") {
            _verifyOpenCloseHost()
            return
        }

        if (mode === "host-retarget") {
            _verifyRetargetHost()
            _runAllModeNext()
            return
        }

        if (mode === "tray") {
            _verifyTrayMode()
            return
        }

        if (mode === "workspace") {
            _verifyWorkspaceMode()
            return
        }

        if (mode === "shared-collapse") {
            _verifySharedCollapseMode()
            return
        }

        if (mode === "super-island") {
            _verifySuperIslandMode()
            return
        }

        _fail("unknown all-mode step: " + mode)
    }

    function _verifyRegistryContract() {
        let barLayoutService = root.barLayoutService

        if (barLayoutService.transientExtensions === undefined) {
            _fail("missing transientExtensions registry")
        }

        if (barLayoutService.transientExtensions.mediaControlFlashExtension === undefined) {
            _fail("missing mediaControlFlashExtension registry bridge")
        }

        if (barLayoutService.barTransientExtension !== barLayoutService.mediaControlFlashExtension) {
            _fail("barTransientExtension must mirror mediaControlFlashExtension")
        }

        if (barLayoutService.barTransientExtension !== 0) {
            _fail("expected transient extension bridge to default to zero")
        }
    }

    function _assert(condition, message) {
        if (!condition) {
            _fail(message)
        }
    }

    function _recordState(host) {
        let statePath = _statePath.slice()

        if (!statePath.length || statePath[statePath.length - 1] !== host.state) {
            statePath.push(host.state)
        }

        _statePath = statePath
    }

    function _verifyOpenCloseHost() {
        let host = _openCloseHostComponent.createObject(root)
        _statePath = []
        _phase = "open"

        _assert(host.state === "closed", "first sync should start closed without animation")
        _assert(host.surfaceHeight === 24, "first sync should snap surfaceHeight to collapsed height")
        _assert(host.clipHeight === 24, "first sync should snap clipHeight to collapsed height")
        _assert(host.reservedExtension === 0, "first sync should not reserve extension while closed")
        _assert(host.running === false, "first sync should not be running")
        _recordState(host)

        host.expanded = true
        _assert(host.clipHeight === 60, "opening should snap clipHeight to expanded height")
        _assert(host.reservedExtension === 36, "opening should immediately reserve full transient extension")
        _assert(host.state === "opening" || host.state === "open", "opening should enter an active host state")
        _assert(host.running === true, "opening should mark the host as running")
        _recordState(host)
        _activeHost = host
        _verificationTimer.restart()
    }

    function _verifyRetargetHost() {
        let host = _retargetHostComponent.createObject(root)

        _assert(host.reservedExtension === 0, "retarget test should start without reserved extension")

        host.expanded = true
        _assert(host.reservedExtension === 36, "retarget test should reserve extension on open")

        host.expanded = false
        _assert(host.reservedExtension === 36, "retarget test should keep extension while closing")

        host.expanded = true
        _assert(host.reservedExtension === 36, "retarget test should not leave stale extension behind when re-opening")
        _assert(host.state === "opening" || host.state === "open", "retarget test should end on the newest requested open state")

        Qt.quit()
    }

    function _verifyTrayMode() {
        root.barLayoutService.clearTransientExtension("system-tray")
        root._trayFixture = _trayFixtureComponent.createObject(root)
        Services.SystemTrayService._testItemsOverride = [root._trayFixture]
        Services.SystemTrayService._rebuildState()

        root._trayWidget = _trayWidgetComponent.createObject(root)
        _assert(root._trayWidget !== null, "tray widget should mount")

        root._trayWidget._enterHoverOpen()
        _assert(root.barLayoutService.transientExtensions["system-tray"] > 0,
            "hover reveal should register a positive system-tray extension")
        _assert(root._trayWidget._pillBackgroundHeight === root._trayWidget._verticalRevealSurfaceHeight,
            "tray background height should follow host surfaceHeight")
        _assert(root._trayWidget._verticalRevealClipHeight > 0,
            "tray clip height should follow host clipHeight")
        _assert(root._trayWidget.implicitHeight === root._trayWidget._pillH + Theme.iconPadding,
            "tray outer height should stay locked to the baseline bar height while the reveal grows downward")

        root._trayWidget._startFlashReveal()
        _assert(root._trayWidget._pillBackgroundHeight === root._trayWidget._verticalRevealSurfaceHeight,
            "hover and flash should share the same Y-axis surface contract")
        _assert(root._trayWidget._verticalRevealClipHeight > 0,
            "hover and flash should share the same Y-axis clip contract")

        root._trayPhase = "opening"
        root._trayPollCount = 0
        _verificationTimer.interval = 120
        _verificationTimer.restart()
    }

    function _seedWorkspaceState() {
        Services.NiriService.updateWorkspaces({
            workspaces: [
                { id: 1, idx: 1, is_active: true, name: "1", output: "test-output" },
                { id: 2, idx: 2, is_active: false, name: "2", output: "test-output" }
            ]
        })

        Services.NiriService.updateWindows([
            {
                id: "workspace-window-a",
                title: "Workspace Alpha Window",
                app_id: "workspace-alpha",
                workspace_id: 1,
                is_focused: true,
                layout: { pos_in_scrolling_layout: [0, 0] }
            },
            {
                id: "workspace-window-b",
                title: "Workspace Beta Window",
                app_id: "workspace-beta",
                workspace_id: 1,
                is_focused: false,
                layout: { pos_in_scrolling_layout: [1, 0] }
            }
        ])
    }

    function _switchWorkspaceFocusWindow() {
        Services.NiriService.updateWindows([
            {
                id: "workspace-window-a",
                title: "A",
                app_id: "workspace-alpha",
                workspace_id: 1,
                is_focused: false,
                layout: { pos_in_scrolling_layout: [0, 0] }
            },
            {
                id: "workspace-window-b",
                title: "Workspace Beta Window With A Much Longer Title For Retarget Width Stress",
                app_id: "workspace-beta",
                workspace_id: 1,
                is_focused: true,
                layout: { pos_in_scrolling_layout: [1, 0] }
            }
        ])
    }

    function _switchWorkspaceFocusWindowBack() {
        Services.NiriService.updateWindows([
            {
                id: "workspace-window-a",
                title: "A",
                app_id: "workspace-alpha",
                workspace_id: 1,
                is_focused: true,
                layout: { pos_in_scrolling_layout: [0, 0] }
            },
            {
                id: "workspace-window-b",
                title: "Workspace Beta Window With A Much Longer Title For Retarget Width Stress",
                app_id: "workspace-beta",
                workspace_id: 1,
                is_focused: false,
                layout: { pos_in_scrolling_layout: [1, 0] }
            }
        ])
    }

    function _superIslandWindowEvent() {
        return {
            id: "super-island-test-window",
            type: "window",
            groupKey: "super-island",
            priority: "important",
            relayReplace: false,
            title: "Super Island Window",
            subtitle: "Harness",
            icon: "",
            workspaceLabel: "",
            timeoutMs: 1500,
            timestamp: Date.now()
        }
    }

    function _verifySuperIslandMode() {
        root.barLayoutService.clearTransientExtension("super-island")
        root._superIslandPreviewWidget = _superIslandPreviewWidgetComponent.createObject(root)
        root._superIslandEvent = root._superIslandWindowEvent()
        Services.SuperIslandService.pushEvent(root._superIslandEvent)

        root._assert(root._superIslandPreviewWidget.liveInstance === false,
            "preview super-island instance should stay non-live")
        root._assert(root.barLayoutService.transientExtensions["super-island"] === undefined,
            "non-live super-island instance should not claim registry space")
        root._assert(root._superIslandPreviewWidget._phase === "hint"
            || root._superIslandPreviewWidget._phase === "enter"
            || root._superIslandPreviewWidget._phase === "hold",
            "super-island preview should still enter the local transient phase")
        root._assert(root._superIslandPreviewWidget._mainDisplayEvent.id === "idle",
            "super-island preview should keep main content selection local")
        root._assert(root._superIslandPreviewWidget._flashSourceEvent.type === "window",
            "super-island preview should keep flash content selection local")

        Services.SuperIslandService.clearEvent(root._superIslandEvent.id)
        root._superIslandPreviewWidget.destroy()
        root._superIslandPreviewWidget = null

        root._superIslandLiveWidget = _superIslandLiveWidgetComponent.createObject(root)
        root._superIslandEvent = root._superIslandWindowEvent()
        root._superIslandSawConcurrentCloseStart = false
        Services.SuperIslandService.pushEvent(root._superIslandEvent)

        root._superIslandPhase = "live-open"
        root._superIslandPollCount = 0
        _verificationTimer.interval = 120
        _verificationTimer.restart()
    }

    function _verifyWorkspaceMode() {
        root.barLayoutService.clearTransientExtension("workspace-widget")
        root._seedWorkspaceState()

        root._workspaceWidget = _workspaceWidgetComponent.createObject(root)
        _assert(root._workspaceWidget !== null, "workspace widget should mount")

        if (root._workspaceWidget.liveInstance !== undefined)
            root._workspaceWidget.liveInstance = true

        if (root._workspaceWidget._verticalRevealState === undefined)
            _fail("workspace widget should use the shared Y-reveal host")

        _assert(root._workspaceWidget._normalY === undefined
            && root._workspaceWidget._flashStripY === undefined
            && root._workspaceWidget._departYAnim === undefined
            && root._workspaceWidget._returnYAnim === undefined
            && root._workspaceWidget._overviewEnterAnim === undefined
            && root._workspaceWidget._overviewExitAnim === undefined
            && root._workspaceWidget._focusEnterAnim === undefined
            && root._workspaceWidget._focusExitAnim === undefined,
            "workspace widget should not expose the old row-Y owner seam")
        _assert(root._workspaceWidget._contentColumnY !== undefined
            && root._workspaceWidget._contentColumnTargetY !== undefined
            && root._workspaceWidget._contentColumnOverviewY !== undefined
            && root._workspaceWidget._contentColumnFocusY !== undefined
            && root._workspaceWidget._focusRowY !== undefined
            && root._workspaceWidget._overviewRowY !== undefined,
            "workspace widget should expose the shared column-motion seam")

        root._workspaceWidget._harnessFocusWidthOverride = 228
        root._workspaceWidget._harnessOverviewWidthOverride = 168
        root._workspaceSawPulseDuringOpen = false
        root._workspaceSawRetriggeredPulse = false
        root._workspaceSawRetriggerSettle = false
        root._workspacePulseBaselineOpacity = 0
        root._workspacePulseBaselineScale = 1
        root._workspaceRetriggerPeakWidth = 0
        root._workspaceBurstSwitchCount = 0
        root._workspacePulseEpisodeCount = 0
        root._workspacePulseWasActive = false
        root._workspacePulseActivePollCount = 0
        root._workspaceBurstBaselineOpacity = 0
        root._workspaceBurstBaselineScale = 1
        root._workspaceSawBurstReplay = false
        root._workspaceWidget._enterWorkspaceReveal(true)
        root._assert(Math.abs(root._workspaceWidget._contentColumnOverviewY) <= 0.5,
            "workspace overview row should stay fixed at the top of the shared column")
        root._assert(Math.abs(root._workspaceWidget._contentColumnFocusY
            - (root._workspaceWidget._pillH + root._workspaceWidget._flashGap)) <= 0.5,
            "workspace title row should stay fixed at the bottom of the shared column")
        root._assert(Math.abs(root._workspaceWidget._contentColumnTargetY) <= 0.5,
            "workspace reveal should drive the shared column toward the expanded position")
        root._workspacePhase = "opening"
        root._workspacePollCount = 0
        _verificationTimer.interval = 40
        _verificationTimer.restart()
    }

    function _verifySharedCollapseMode() {
        root._sharedCollapseTransition = _sharedCollapseTransitionComponent.createObject(root)
        _assert(root._sharedCollapseTransition !== null, "shared collapse transition should mount")

        root._sharedCollapseTransition.snapToExpanded()
        root._sharedCollapseTransition.expanded = false
        _assert(root._sharedCollapseTransition._phase1Width < root._sharedCollapseTransition.expandedWidth
            && root._sharedCollapseTransition._phase1Width > root._sharedCollapseTransition.collapsedWidth,
            "shared collapse should begin by moving width inward")

        root._sharedCollapseTransition.destroy()
        root._sharedCollapseTransition = null
        if (root._mode === "all") {
            _runAllModeNext()
            return
        }
        Qt.quit()
    }

    Timer {
        id: _verificationTimer

        interval: Theme.anim.moveDuration * 2 + 40
        repeat: false
        onTriggered: {
            if (root._trayPhase === "closing") {
                root._trayPollCount += 1
                console.log("tray poll", root._trayPollCount,
                    "state", root._trayWidget ? root._trayWidget._state : "missing",
                    "hostState", root._trayWidget ? root._trayWidget._verticalRevealState : "missing",
                    "running", root._trayWidget ? root._trayWidget._verticalRevealRunning : false,
                    "surface", root._trayWidget ? root._trayWidget._verticalRevealSurfaceHeight : -1,
                    "clip", root._trayWidget ? root._trayWidget._verticalRevealClipHeight : -1,
                    "registry", root.barLayoutService.transientExtensions["system-tray"])

                if (root.barLayoutService.transientExtensions["system-tray"] !== undefined) {
                    if (root._trayWidget.implicitWidth >= root._trayWidget._expandedWidth) {
                        if (root._trayPollCount >= 12) {
                            root._fail("tray close did not start collapsing: state=" + root._trayWidget._state +
                                " hostState=" + root._trayWidget._verticalRevealState +
                                " running=" + root._trayWidget._verticalRevealRunning +
                                " surface=" + root._trayWidget._verticalRevealSurfaceHeight +
                                " clip=" + root._trayWidget._verticalRevealClipHeight +
                                " registry=" + root.barLayoutService.transientExtensions["system-tray"])
                        }

                        _verificationTimer.restart()
                        return
                    }

                    root._assert(root._trayWidget.implicitWidth < root._trayWidget._expandedWidth,
                        "tray width should start collapsing before the Y reservation is released")
                    if (root._trayPollCount >= 12) {
                        root._fail("tray close did not finish: state=" + root._trayWidget._state +
                            " hostState=" + root._trayWidget._verticalRevealState +
                            " running=" + root._trayWidget._verticalRevealRunning +
                            " surface=" + root._trayWidget._verticalRevealSurfaceHeight +
                            " clip=" + root._trayWidget._verticalRevealClipHeight +
                            " registry=" + root.barLayoutService.transientExtensions["system-tray"])
                    }

                    _verificationTimer.restart()
                    return
                }

                root._assert(root.barLayoutService.transientExtensions["system-tray"] === undefined,
                    "leaving reveal should clear the system-tray registry entry")
                root._trayWidget.destroy()
                root._trayWidget = null
                Services.SystemTrayService._testItemsOverride = undefined
                Services.SystemTrayService._rebuildState()
                if (root._trayFixture) {
                    root._trayFixture.destroy()
                    root._trayFixture = null
                }
                root._trayPhase = "idle"
                if (root._mode === "all") {
                    _runAllModeNext()
                    return
                }
                Qt.quit()
                return
            }

            if (root._trayPhase === "opening") {
                root._trayPollCount += 1

                if (root._trayWidget._state !== "flash-hold"
                    && root._trayWidget._state !== "hover-open"
                    && !(root._trayWidget._verticalRevealState === "open" && root._trayWidget._verticalRevealRunning === false)) {
                    if (root._trayPollCount >= 24) {
                        root._fail("tray open did not settle before collapse: state=" + root._trayWidget._state +
                            " hostState=" + root._trayWidget._verticalRevealState +
                            " running=" + root._trayWidget._verticalRevealRunning +
                            " surface=" + root._trayWidget._verticalRevealSurfaceHeight +
                            " clip=" + root._trayWidget._verticalRevealClipHeight +
                            " registry=" + root.barLayoutService.transientExtensions["system-tray"])
                    }

                    _verificationTimer.restart()
                    return
                }

                root._trayWidget._beginCollapse()
                root._trayPhase = "closing"
                _verificationTimer.interval = 250
                _verificationTimer.restart()
                return
            }

            if (root._workspacePhase === "closing") {
                root._workspacePollCount += 1

                root._assert(Math.abs(root._workspaceWidget._contentColumnY - root._workspaceExpectedColumnY()) <= 0.75,
                    "workspace collapse should keep the column locked to the background push geometry")

                if (root.barLayoutService.transientExtensions["workspace-widget"] !== undefined) {
                    if (root._workspacePollCount >= 24) {
                        root._fail("workspace close did not finish: state=" + root._workspaceWidget._state +
                            " hostState=" + root._workspaceWidget._verticalRevealState +
                            " running=" + root._workspaceWidget._verticalRevealRunning +
                            " surface=" + root._workspaceWidget._verticalRevealSurfaceHeight +
                            " clip=" + root._workspaceWidget._verticalRevealClipHeight +
                            " registry=" + root.barLayoutService.transientExtensions["workspace-widget"])
                    }

                    _verificationTimer.restart()
                    return
                }

                root._assert(root._workspaceWidget._verticalRevealState !== undefined,
                    "workspace widget should expose shared reveal state")
                root._assert(root._workspaceWidget._verticalRevealClipHeight >= root._workspaceWidget._pillH,
                    "workspace reveal should expose the flash strip through clip geometry")
                root._assert(root._workspaceWidget._verticalRevealClipHeight >= root._workspaceWidget._verticalRevealSurfaceHeight,
                    "workspace reveal clip should be at least as tall as the surface during reveal")
                root._assert(root._workspaceWidget._pillBackgroundHeight === root._workspaceWidget._verticalRevealSurfaceHeight,
                    "workspace background height should follow host surfaceHeight")
                root._assert(Math.abs(root._workspaceWidget._contentColumnY - root._workspaceExpectedColumnY()) <= 0.75,
                    "workspace close should settle the column on the current background push geometry")
                root._assert(root.barLayoutService.transientExtensions["workspace-widget"] === undefined,
                    "leaving reveal should clear the workspace registry entry after collapse finishes")

                root._workspaceWidget.destroy()
                root._workspaceWidget = null
                Services.NiriService.updateWorkspaces({ workspaces: [] })
                Services.NiriService.updateWindows([])
                root._workspacePhase = "idle"
                if (root._mode === "all") {
                    _runAllModeNext()
                    return
                }
                Qt.quit()
                return
            }

            if (root._workspacePhase === "opening") {
                root._workspacePollCount += 1

                if (root._workspaceWidget._sharedBackgroundPulseOpacity > 0.01
                    || Math.abs(root._workspaceWidget._sharedPulseScale - 1) > 0.01) {
                    root._workspaceSawPulseDuringOpen = true
                }

                root._assert(root._workspaceContentProgress() <= root._workspaceSurfaceProgress() + 0.1,
                    "workspace content should not move downward ahead of the reveal background")
                root._assert(root._workspaceWidget._pillBackgroundHeight <= root._workspaceWidget._verticalRevealClipHeight + 0.5,
                    "workspace background should not overshoot past the clip during reveal")
                root._assert(Math.abs(root._workspaceWidget._contentColumnY - root._workspaceExpectedColumnY()) <= 0.75,
                    "workspace reveal should keep the column locked to the background push geometry")

                if (root.barLayoutService.transientExtensions["workspace-widget"] <= 0) {
                    root._fail("workspace switch reveal should register a positive workspace-widget extension")
                }

                if (root._workspaceWidget._verticalRevealState !== "open"
                    || root._workspaceWidget._verticalRevealRunning) {
                    if (root._workspacePollCount >= 16) {
                        root._fail("workspace open did not settle before close: hostState=" + root._workspaceWidget._verticalRevealState +
                            " running=" + root._workspaceWidget._verticalRevealRunning +
                            " surface=" + root._workspaceWidget._verticalRevealSurfaceHeight +
                            " clip=" + root._workspaceWidget._verticalRevealClipHeight +
                            " columnY=" + root._workspaceWidget._contentColumnY)
                    }

                    _verificationTimer.restart()
                    return
                }

                if ((Math.abs(root._workspaceWidget._focusRowScale - root._workspaceWidget._flashScale) > 0.05
                    || root._workspaceWidget._focusRowOpacity > 0.65)
                    && root._workspacePollCount < 16) {
                    _verificationTimer.restart()
                    return
                }

                root._assert(root._workspaceWidget._verticalRevealClipHeight >= root._workspaceWidget._pillH,
                    "workspace reveal should expose the flash strip through clip geometry")
                root._assert(root._workspaceWidget._pillBackgroundHeight === root._workspaceWidget._verticalRevealSurfaceHeight,
                    "workspace background height should follow host surfaceHeight")
                root._assert(root._workspaceWidget._verticalRevealClipHeight >= root._workspaceWidget._verticalRevealSurfaceHeight,
                    "workspace reveal clip should be at least as tall as the surface during reveal")
                root._assert(Math.abs(root._workspaceWidget._contentColumnY) <= 0.5,
                    "workspace reveal should settle the shared column in the expanded position")
                root._assert(Math.abs(root._workspaceWidget._focusRowY
                    - (root._workspaceWidget._pillH + root._workspaceWidget._flashGap)) <= 1,
                    "workspace title row should enter the flash area during reveal")
                root._assert(Math.abs(root._workspaceWidget._overviewRowY) <= 1,
                    "workspace overview row should occupy the main pill while reveal is open")
                root._assert(Math.abs(root._workspaceWidget._focusRowScale - root._workspaceWidget._flashScale) <= 0.05,
                    "workspace title row should shrink in the flash area during reveal")
                root._assert(root._workspaceWidget._focusRowOpacity <= 0.65,
                    "workspace title row should dim in the flash area during reveal")
                root._assert(root._workspaceWidget.implicitWidth > 0,
                    "workspace width should remain independently laid out while reveal is active")
                root._assert(root._workspaceSawPulseDuringOpen,
                    "workspace reveal should emit a shared pulse during open")

                root._workspacePulseBaselineOpacity = root._workspaceWidget._sharedBackgroundPulseOpacity
                root._workspacePulseBaselineScale = root._workspaceWidget._sharedPulseScale
                root._switchWorkspaceFocusWindow()

                root._workspacePhase = "pulse-retrigger"
                root._workspacePollCount = 0
                root._workspaceRetriggerPeakWidth = root._workspaceWidget.implicitWidth
                root._workspaceBurstSwitchCount = 1
                root._workspacePulseEpisodeCount = 0
                root._workspacePulseWasActive = root._workspaceSharedPulseActive()
                root._workspacePulseActivePollCount = 0
                _verificationTimer.interval = 40
                _verificationTimer.restart()
                return


            }

            if (root._workspacePhase === "pulse-retrigger") {
                root._workspacePollCount += 1
                root._workspaceRetriggerPeakWidth = Math.max(root._workspaceRetriggerPeakWidth, root._workspaceWidget.implicitWidth)
                root._assert(root._workspaceWidget._sharedPulseScale <= 1.03,
                    "workspace width retarget should not reuse the large expand-scale pulse")

                const retriggerPulseActive = root._workspaceSharedPulseActive()
                if (retriggerPulseActive && !root._workspacePulseWasActive)
                    root._workspacePulseEpisodeCount += 1
                if (retriggerPulseActive)
                    root._workspacePulseActivePollCount += 1
                root._workspacePulseWasActive = retriggerPulseActive

                if (root._workspaceWidget._sharedBackgroundPulseOpacity > root._workspacePulseBaselineOpacity + 0.01
                    || root._workspaceWidget._sharedPulseScale > root._workspacePulseBaselineScale + 0.01) {
                    root._workspaceSawRetriggeredPulse = true
                }

                if (root._workspaceBurstSwitchCount === 1 && root._workspacePollCount === 2) {
                    root._workspaceBurstBaselineOpacity = root._workspaceWidget._sharedBackgroundPulseOpacity
                    root._workspaceBurstBaselineScale = root._workspaceWidget._sharedPulseScale
                    root._workspaceSawBurstReplay = false
                    root._switchWorkspaceFocusWindowBack()
                    root._workspaceBurstSwitchCount = 2
                } else if (root._workspaceBurstSwitchCount === 2 && root._workspacePollCount === 4) {
                    root._workspaceBurstBaselineOpacity = root._workspaceWidget._sharedBackgroundPulseOpacity
                    root._workspaceBurstBaselineScale = root._workspaceWidget._sharedPulseScale
                    root._workspaceSawBurstReplay = false
                    root._switchWorkspaceFocusWindow()
                    root._workspaceBurstSwitchCount = 3
                }

                if (root._workspaceBurstSwitchCount >= 2
                    && (root._workspaceWidget._sharedBackgroundPulseOpacity > root._workspaceBurstBaselineOpacity + 0.01
                        || root._workspaceWidget._sharedPulseScale > root._workspaceBurstBaselineScale + 0.01)) {
                    root._workspaceSawBurstReplay = true
                }

                if ((!root._workspaceSawRetriggeredPulse || root._workspacePollCount < 8)
                    && root._workspacePollCount < 12) {
                    _verificationTimer.restart()
                    return
                }

                root._assert(root._workspaceRetriggerPeakWidth <= root._workspaceWidget.implicitWidth * 1.03 + 2,
                    "workspace width retarget should not overshoot far beyond the long-title final width")

                root._workspacePhase = "pulse-settle"
                root._workspacePollCount = 0
                _verificationTimer.interval = 40
                _verificationTimer.restart()
                return
            }

            if (root._workspacePhase === "pulse-settle") {
                root._workspacePollCount += 1

                const settlePulseActive = root._workspaceSharedPulseActive()
                if (settlePulseActive && !root._workspacePulseWasActive)
                    root._workspacePulseEpisodeCount += 1
                if (settlePulseActive)
                    root._workspacePulseActivePollCount += 1
                root._workspacePulseWasActive = settlePulseActive

                if (root._workspaceWidget._sharedBackgroundPulseOpacity <= 0.01
                    && Math.abs(root._workspaceWidget._sharedPulseScale - 1) <= 0.01) {
                    root._workspaceSawRetriggerSettle = true
                }

                if (!root._workspaceSawRetriggerSettle && root._workspacePollCount < 20) {
                    _verificationTimer.restart()
                    return
                }

                root._assert(root._workspaceSawBurstReplay,
                    "workspace burst switching should restart the shared pulse before it fully settles")
                root._assert(root._workspaceSawRetriggerSettle,
                    "workspace burst replay should still settle back to baseline after the last switch")

                root._workspacePhase = "closing"
                root._workspaceWidget._settleFlashToOverview()
                _verificationTimer.interval = 120
                _verificationTimer.restart()
                return
            }

            if (root._superIslandPhase === "live-open") {
                root._superIslandPollCount += 1

                root._assert(root.barLayoutService.transientExtensions["super-island"] > 0,
                    "live super-island instance should register a positive super-island extension")
                root._assert(root._superIslandLiveWidget.liveInstance === true,
                    "live super-island instance should opt into registry ownership")
                root._assert(root._superIslandLiveWidget._verticalRevealState !== undefined,
                    "super-island widget should expose the shared Y-reveal host state")
                root._assert(root._superIslandLiveWidget._verticalRevealSurfaceHeight === root._superIslandLiveWidget._pillBackgroundHeight,
                    "super-island background height should come from the shared host surface")
                root._assert(root._superIslandLiveWidget._verticalRevealClipHeight > 0,
                    "super-island clip height should come from the shared host clip")
                root._assert(root._superIslandLiveWidget._pillTransitionHeightDelegated === true,
                    "super-island pill transition should not double-drive height once the host owns Y geometry")
                root._assert(root._superIslandLiveWidget._phase === "hint",
                    "super-island should keep transient phase semantics local")
                root._assert(root._superIslandLiveWidget._mainDisplayEvent.id === "idle",
                    "super-island should keep main content selection local during transient phase")
                root._assert(root._superIslandLiveWidget._flashSourceEvent.type === "window",
                    "super-island should keep flash content selection local during transient phase")

                if (root._superIslandLiveWidget._phase !== "hold"
                    && !(root._superIslandLiveWidget._verticalRevealState === "open" && root._superIslandLiveWidget._verticalRevealRunning === false)) {
                    if (root._superIslandPollCount >= 40) {
                        root._fail("super-island open did not settle before clearEvent: phase=" + root._superIslandLiveWidget._phase +
                            " hostState=" + root._superIslandLiveWidget._verticalRevealState +
                            " running=" + root._superIslandLiveWidget._verticalRevealRunning +
                            " surface=" + root._superIslandLiveWidget._verticalRevealSurfaceHeight +
                            " clip=" + root._superIslandLiveWidget._verticalRevealClipHeight +
                            " registry=" + root.barLayoutService.transientExtensions["super-island"])
                    }

                    _verificationTimer.restart()
                    return
                }

                Services.SuperIslandService.clearEvent(root._superIslandEvent.id)
                root._superIslandPhase = "live-closing"
                _verificationTimer.interval = 120
                _verificationTimer.restart()
                return
            }

            if (root._superIslandPhase === "live-closing") {
                root._superIslandPollCount += 1

                console.log("super-island close poll", root._superIslandPollCount,
                    "phase", root._superIslandLiveWidget ? root._superIslandLiveWidget._phase : "missing",
                    "hostState", root._superIslandLiveWidget ? root._superIslandLiveWidget._verticalRevealState : "missing",
                    "running", root._superIslandLiveWidget ? root._superIslandLiveWidget._verticalRevealRunning : false,
                    "implicitWidth", root._superIslandLiveWidget ? root._superIslandLiveWidget.implicitWidth : -1,
                    "expandedWidth", root._superIslandLiveWidget ? root._superIslandLiveWidget._expandedWidth : -1,
                    "registry", root.barLayoutService.transientExtensions["super-island"])

                if (root.barLayoutService.transientExtensions["super-island"] !== undefined) {
                    if (root._superIslandLiveWidget._verticalRevealState === "closing"
                        && root._superIslandLiveWidget.implicitWidth < root._superIslandLiveWidget._expandedWidth
                        && !root._superIslandSawConcurrentCloseStart) {
                        root._assert(root._superIslandLiveWidget._verticalRevealSurfaceHeight
                            > root._superIslandLiveWidget._collapsedPillHeight + 0.5,
                            "super-island should keep shared height in flight when width collapse begins")
                        root._superIslandSawConcurrentCloseStart = true
                    }

                    if (root._superIslandLiveWidget.implicitWidth >= root._superIslandLiveWidget._expandedWidth) {
                        if (root._superIslandPollCount >= 40) {
                            root._fail("super-island close did not start collapsing: state=" + root._superIslandLiveWidget._verticalRevealState +
                                " running=" + root._superIslandLiveWidget._verticalRevealRunning +
                                " surface=" + root._superIslandLiveWidget._verticalRevealSurfaceHeight +
                                " clip=" + root._superIslandLiveWidget._verticalRevealClipHeight +
                                " registry=" + root.barLayoutService.transientExtensions["super-island"])
                        }

                        _verificationTimer.restart()
                        return
                    }

                    root._assert(root._superIslandLiveWidget.implicitWidth < root._superIslandLiveWidget._expandedWidth,
                        "super-island width should start collapsing before the Y reservation is released")
                    if (root._superIslandPollCount >= 40) {
                        root._fail("super-island close did not finish: state=" + root._superIslandLiveWidget._verticalRevealState +
                            " running=" + root._superIslandLiveWidget._verticalRevealRunning +
                            " surface=" + root._superIslandLiveWidget._verticalRevealSurfaceHeight +
                            " clip=" + root._superIslandLiveWidget._verticalRevealClipHeight +
                            " registry=" + root.barLayoutService.transientExtensions["super-island"])
                    }

                    _verificationTimer.restart()
                    return
                }

                root._assert(root._superIslandLiveWidget._verticalRevealState === "closed",
                    "super-island close should settle the shared host before clearing registry")
                root._assert(root._superIslandSawConcurrentCloseStart,
                    "super-island close should begin width and shared height collapse together")
                root._assert(root._superIslandLiveWidget._verticalRevealSurfaceHeight === root._superIslandLiveWidget._pillH,
                    "super-island close should restore the shared host surface height")
                root._assert(root._superIslandLiveWidget._verticalRevealClipHeight === root._superIslandLiveWidget._pillH,
                    "super-island close should restore the shared host clip height")
                root._assert(root.barLayoutService.transientExtensions["super-island"] === undefined,
                    "closing should clear the super-island registry entry only after the host settles")

                root._superIslandLiveWidget.destroy()
                root._superIslandLiveWidget = null
                Services.SuperIslandService.clearEvent(root._superIslandEvent.id)
                root._superIslandEvent = null
                root._superIslandPhase = "idle"
                if (root._mode === "all") {
                    _runAllModeNext()
                    return
                }
                Qt.quit()
                return
            }

            if (root._mode !== "host-open-close" && root._mode !== "all") {
                if (root._mode === "workspace")
                    return
                return
            }

            let host = root._activeHost

            if (!host) {
                return
            }

            root._recordState(host)

            if (root._phase === "open") {
                if (host.state !== "open") {
                    _verificationTimer.start()
                    return
                }

                root._assert(host.state === "open", "opening should settle into the open state before close begins")
                root._assert(host.surfaceHeight === 60, "open state should hold expanded surface height")
                root._assert(host.clipHeight === 60, "open state should hold expanded clip height")
                root._assert(host.reservedExtension === 36, "open state should keep the reserved extension")
                root._assert(root._statePath.indexOf("opening") !== -1, "state path should include opening")
                root._assert(root._statePath.indexOf("open") !== -1, "state path should include open")

                host.expanded = false
                root._assert(host.state === "closing", "closing should enter the closing state")
                root._assert(host.reservedExtension === 36, "closing should keep reservedExtension until close finishes")
                root._recordState(host)
                root._phase = "close"
                _verificationTimer.start()
                return
            }

            if (host.state !== "closed") {
                _verificationTimer.start()
                return
            }

            if (host.running) {
                _verificationTimer.start()
                return
            }

            root._assert(host.state === "closed", "final closed state should return to closed")
            root._assert(host.surfaceHeight === 24, "final closed state should restore surfaceHeight to collapsed truth")
            root._assert(host.clipHeight === 24, "final closed state should restore clipHeight to collapsed truth")
            root._assert(host.reservedExtension === 0, "final closed state should clear reservedExtension")
            root._assert(host.running === false, "final closed state should stop running")

            let statePath = root._statePath
            root._assert(statePath.indexOf("closed") !== -1, "state path should include closed")
            root._assert(statePath.indexOf("open") !== -1, "state path should include open")
            root._assert(statePath.indexOf("closing") !== -1, "state path should include closing")

            root._activeHost = null
            root._phase = "idle"
            if (root._mode === "all") {
                _runAllModeNext()
                return
            }
            Qt.quit()
        }
    }

    Component.onCompleted: {
        if (_mode === "all") {
            _allModeIndex = -1
            _runAllModeNext()
            return
        }

        if (_mode === "super-island") {
            _verifySuperIslandMode()
            return
        }

        if (_mode === "workspace") {
            _verifyWorkspaceMode()
            return
        }

        if (_mode === "shared-collapse") {
            _verifySharedCollapseMode()
            return
        }

        if (_mode === "registry") {
            _verifyRegistryContract()
            Qt.quit()
            return
        }

        if (_mode === "host-open-close") {
            _verifyOpenCloseHost()
            return
        }

        if (_mode === "host-retarget") {
            _verifyRetargetHost()
            Qt.quit()
            return
        }

        if (_mode === "tray") {
            _verifyTrayMode()
            return
        }

        _fail("unknown harness mode: " + _mode)
    }
}
