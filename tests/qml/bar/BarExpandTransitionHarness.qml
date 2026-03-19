import Quickshell
import QtQuick
import qs.config
import qs.services
import "../../../modules/bar"
import "../../../modules/bar/widgets" as BarWidgets

// Harness for validating shared bar motion tokens and persisted settings.
Item {
    id: root

    readonly property var _knownModes: ["settings", "timeline", "super-island", "workspace"]
    readonly property var _implementedModes: ["settings", "timeline", "super-island", "workspace"]
    readonly property var _args:
        typeof Quickshell.args !== "undefined" && Quickshell.args ? Quickshell.args : []
    readonly property string _mode: {
        if (_args.length > 0)
            return _args[0]

        const envMode = Quickshell.env("DYMICSHELL_BAR_MOTION_MODE")
        return envMode && envMode !== "null" ? envMode : "all"
    }
    readonly property bool _timelineModeActive: _mode === "timeline"
    readonly property int _timelinePhaseDuration:
        Theme.anim.barExpandPreloadDuration
        + Theme.anim.barExpandOvershootDuration
        + Theme.anim.barExpandSettleDuration
    readonly property int _timelineCollapseDelay:
        Math.max(1, _timelinePhaseDuration + Math.max(24, Theme.anim.highlightDuration))
    readonly property int _timelineVerificationDelay:
        Math.max(1, _timelineCollapseDelay + _timelinePhaseDuration + Math.max(48, Theme.anim.highlightDuration))
    readonly property int _timelineExpandRetargetDelay:
        Math.max(1, Theme.anim.barExpandPreloadDuration + Math.max(12, Theme.anim.highlightDuration / 2))
    readonly property int _timelineCollapseRetargetDelay:
        Math.max(1, _timelineCollapseDelay + Theme.anim.barExpandPreloadDuration)
    readonly property int _timelineRetargetProbeDelay:
        Math.max(16, Math.min(40, Math.round(Theme.anim.barExpandOvershootDuration / 3)))
    readonly property bool _superIslandModeActive: _mode === "super-island"
    readonly property int _superIslandPhaseDuration:
        Theme.anim.barExpandPreloadDuration
        + Theme.anim.barExpandOvershootDuration
        + Theme.anim.barExpandSettleDuration
    readonly property int _superIslandCollapseDelay:
        Math.max(1, _superIslandPhaseDuration + Math.max(32, Theme.anim.highlightDuration))
    readonly property int _superIslandVerificationDelay:
        Math.max(1,
            _superIslandCollapseDelay + _superIslandPhaseDuration + Math.max(96, Theme.anim.highlightDuration))
    property real _timelineExpandMinWidth: 100
    property real _timelineExpandMaxWidth: 100
    property real _timelineCollapseMinWidth: 160
    property real _timelineCollapseMinHeight: 64
    property real _timelineCollapseMaxHeight: 64
    property real _timelineExpandedSettleWidth: 0
    property real _timelineExpandedSettleHeight: 0
    property real _timelinePulseOpacityMax: 0
    property real _timelinePulseScaleMax: 1
    property real _timelinePulseOpacityMaxWhileDisabled: 0
    property real _timelinePulseScaleDeviationWhileDisabled: 0
    property bool _timelinePulseDisabled: false
    property bool _timelineCollapseStarted: false
    property bool _timelineObservedExpandUndershoot: false
    property bool _timelineObservedExpandOvershoot: false
    property bool _timelineObservedCollapseHeightOvershoot: false
    property bool _timelineObservedCollapseWidthUndershoot: false
    property bool _timelineObservedCollapseHeightUndershoot: false
    property real _timelineExpandRetargetWidthBefore: 0
    property real _timelineExpandRetargetWidthAfter: 0
    property real _timelineExpandRetargetHeightBefore: 0
    property real _timelineExpandRetargetHeightAfter: 0
    property real _timelineCollapseRetargetWidthBefore: 0
    property real _timelineCollapseRetargetWidthAfter: 0
    property real _timelineCollapseRetargetHeightBefore: 0
    property real _timelineCollapseRetargetHeightAfter: 0
    property bool _timelineObservedImmediateExpandRetargetWidthMotion: false
    property bool _timelineObservedImmediateCollapseRetargetWidthMotion: false
    property bool _timelineSnapExpandedPreservedTruth: false
    property bool _timelineSnapCollapsedPreservedTruth: false
    property bool _timelineOriginalPulseEnabled: true
    property bool _superIslandOriginalPulseEnabled: true
    property bool _superIslandOriginalSuppressExternalSources: false
    property string _superIslandActiveEventId: "bar-motion-super-island"
    property var _superIslandTransition: null
    property var _superIslandPillClip: null
    property var _superIslandPillBackground: null
    property real _superIslandCollapsedWidth: 0
    property real _superIslandCollapsedHeight: 0
    property real _superIslandRestoreTruthWidth: 0
    property real _superIslandRestoreTruthHeight: 0
    property real _superIslandExpandedWidth: 0
    property real _superIslandExpandedHeight: 0
    property real _superIslandCollapseMaxWidth: 0
    property real _superIslandCollapseMinWidth: 0
    property real _superIslandCollapseMaxHeight: 0
    property real _superIslandCollapseMinHeight: 0
    property real _superIslandFinalWidthMin: 0
    property real _superIslandFinalWidthMax: 0
    property real _superIslandFinalHeightMin: 0
    property real _superIslandFinalHeightMax: 0
    property int _superIslandSampleTick: 0
    property int _superIslandWidthCollapseStartTick: -1
    property int _superIslandHeightCollapseStartTick: -1
    property bool _superIslandCollapseStarted: false
    property bool _superIslandObservedFlashTrackWhileGeometryActive: false
    property bool _superIslandObservedFlashTrackMotionWhileGeometryActive: false
    property bool _superIslandObservedRestoreSettled: false
    property real _superIslandFlashTrackYAtCollapseStart: 0
    readonly property bool _workspaceModeActive: _mode === "workspace"
    readonly property int _workspacePhaseDuration:
        Theme.anim.barExpandPreloadDuration
        + Theme.anim.barExpandOvershootDuration
        + Theme.anim.barExpandSettleDuration
    readonly property int _workspaceReturnDelay:
        Math.max(1, _workspacePhaseDuration + Math.max(32, Theme.anim.highlightDuration))
    readonly property int _workspaceFlashTriggerDelay:
        Math.max(1, _workspaceReturnDelay + _workspacePhaseDuration + Math.max(32, Theme.anim.highlightDuration))
    readonly property int _workspaceVerificationDelay:
        Math.max(1, _workspaceFlashTriggerDelay + Theme.anim.enterDuration + Math.max(96, Theme.anim.highlightDuration))
    property string _workspaceOriginalDefaultMode: "focus"
    property bool _workspaceOriginalHoverEnabled: true
    property bool _workspaceOriginalPulseEnabled: true
    property var _workspaceTransition: null
    property var _workspacePillClip: null
    property var _workspacePillBackground: null
    property var _workspaceFocusRow: null
    property real _workspaceCollapsedWidth: 0
    property real _workspaceExpandedWidth: 0
    property real _workspaceFocusWidth: 0
    property real _workspaceOverviewWidth: 0
    property real _workspaceHeightTruth: 0
    property real _workspaceExpandMinWidth: 0
    property real _workspaceExpandMaxWidth: 0
    property real _workspaceCollapseMinWidth: 0
    property real _workspaceCollapseMaxWidth: 0
    property real _workspaceExpandMinHeight: 0
    property real _workspaceExpandMaxHeight: 0
    property real _workspaceCollapseMinHeight: 0
    property real _workspaceCollapseMaxHeight: 0
    property real _workspaceTransitionExpandMaxWidth: 0
    property real _workspaceTransitionCollapseMinWidth: 0
    property real _workspacePulseOpacityMax: 0
    property real _workspacePulseScaleMax: 1
    property real _workspaceLocalFocusPulseMax: 0
    property real _workspaceSharedWidthOwnershipMaxDelta: 0
    property real _workspaceFlashHeightMax: 0
    property real _workspaceFlashSharedHeightMin: 0
    property real _workspaceFlashSharedHeightMax: 0
    property bool _workspaceCollapseStarted: false
    property bool _workspaceFlashActive: false

    WidgetSettingsPanel {
        id: _settingsPanel

        anchorTarget: root
    }

    BarExpandTransition {
        id: transition

        collapsedWidth: 100
        expandedWidth: 160
        collapsedHeight: 32
        expandedHeight: 64
        expanded: false
        animateWidth: true
        animateHeight: true
    }

    BarWidgets.SuperIslandWidget {
        id: _superIslandWidget

        visible: root._superIslandModeActive
        liveInstance: false
    }

    BarWidgets.WorkspaceWidget {
        id: _workspaceWidget

        visible: root._workspaceModeActive
    }

    Timer {
        id: _timelineExpandRetargetTimer

        interval: root._timelineExpandRetargetDelay
        repeat: false
        running: root._timelineModeActive
        onTriggered: {
            root._timelineExpandRetargetWidthBefore = transition.animatedWidth
            root._timelineExpandRetargetHeightBefore = transition.animatedHeight
            transition.expandedWidth = 180
            transition.expandedHeight = 72
            root._sampleTimelineState()
            _timelineExpandRetargetProbe.restart()
        }
    }

    Timer {
        id: _timelineExpandRetargetProbe

        interval: root._timelineRetargetProbeDelay
        repeat: false
        running: false
        onTriggered: {
            root._timelineExpandRetargetWidthAfter = transition.animatedWidth
            root._timelineExpandRetargetHeightAfter = transition.animatedHeight
            root._timelineObservedImmediateExpandRetargetWidthMotion =
                root._timelineObservedImmediateExpandRetargetWidthMotion
                || (root._timelineExpandRetargetWidthAfter > root._timelineExpandRetargetWidthBefore + 0.5)
        }
    }

    Timer {
        id: _timelineSampler

        interval: 8
        repeat: true
        running: root._timelineModeActive
        onTriggered: root._sampleTimelineState()
    }

    Timer {
        id: _timelineCollapseTrigger

        interval: root._timelineCollapseDelay
        repeat: false
        running: root._timelineModeActive
        onTriggered: {
            root._timelineExpandedSettleWidth = transition.animatedWidth
            root._timelineExpandedSettleHeight = transition.animatedHeight
            SettingsService.data.barMotion.pulseEnabled = false
            root._timelinePulseDisabled = true
            root._timelineCollapseStarted = true
            transition.expanded = false
            root._sampleTimelineState()
        }
    }

    Timer {
        id: _timelineCollapseRetargetTimer

        interval: root._timelineCollapseRetargetDelay
        repeat: false
        running: root._timelineModeActive
        onTriggered: {
            root._timelineCollapseRetargetWidthBefore = transition.animatedWidth
            root._timelineCollapseRetargetHeightBefore = transition.animatedHeight
            transition.collapsedWidth = 96
            transition.collapsedHeight = 28
            root._sampleTimelineState()
            _timelineCollapseRetargetProbe.restart()
        }
    }

    Timer {
        id: _timelineCollapseRetargetProbe

        interval: root._timelineRetargetProbeDelay
        repeat: false
        running: false
        onTriggered: {
            root._timelineCollapseRetargetWidthAfter = transition.animatedWidth
            root._timelineCollapseRetargetHeightAfter = transition.animatedHeight
            root._timelineObservedImmediateCollapseRetargetWidthMotion =
                root._timelineObservedImmediateCollapseRetargetWidthMotion
                || (root._timelineCollapseRetargetWidthAfter < root._timelineCollapseRetargetWidthBefore - 0.5)
        }
    }

    Timer {
        id: _timelineVerificationTimer

        interval: root._timelineVerificationDelay
        repeat: false
        running: root._timelineModeActive
        onTriggered: {
            root._sampleTimelineState()

            try {
                root._assertTimelinePhases()
                transition.snapToExpanded()
                root._timelineSnapExpandedPreservedTruth = transition.expanded
                    && Math.abs(transition.animatedWidth - transition.expandedWidth) < 0.5
                    && Math.abs(transition.animatedHeight - transition.expandedHeight) < 0.5
                transition.snapToCollapsed()
                root._timelineSnapCollapsedPreservedTruth = !transition.expanded
                    && Math.abs(transition.animatedWidth - transition.collapsedWidth) < 0.5
                    && Math.abs(transition.animatedHeight - transition.collapsedHeight) < 0.5
                root._assert(_timelineSnapExpandedPreservedTruth,
                    "expected snapToExpanded to preserve expanded as the truth source")
                root._assert(_timelineSnapCollapsedPreservedTruth,
                    "expected snapToCollapsed to preserve expanded as the truth source")
                root._reportStatus("PASS", "timeline")
            } catch (error) {
                root._reportStatus("FAIL", error.message)
            }

            root._restoreTimelineSettings()

            Qt.callLater(Qt.quit)
        }
    }

    Timer {
        id: _superIslandSampler

        interval: 8
        repeat: true
        running: root._superIslandModeActive
        onTriggered: root._sampleSuperIslandState()
    }

    Timer {
        id: _superIslandCollapseTrigger

        interval: root._superIslandCollapseDelay
        repeat: false
        running: false
        onTriggered: {
            root._sampleSuperIslandState()
            root._superIslandCollapsedWidth = root._superIslandTransition.collapsedWidth
            root._superIslandCollapsedHeight = root._superIslandTransition.collapsedHeight
            root._superIslandRestoreTruthWidth = root._superIslandTransition.collapsedWidth
            root._superIslandRestoreTruthHeight = root._superIslandTransition.collapsedHeight
            root._superIslandExpandedWidth = root._superIslandCurrentWidth()
            root._superIslandExpandedHeight = root._superIslandCurrentHeight()
            root._superIslandCollapseMaxWidth = root._superIslandExpandedWidth
            root._superIslandCollapseMinWidth = root._superIslandExpandedWidth
            root._superIslandCollapseMaxHeight = root._superIslandExpandedHeight
            root._superIslandCollapseMinHeight = root._superIslandExpandedHeight
            root._superIslandCollapseStarted = true
            root._superIslandFlashTrackYAtCollapseStart = _superIslandWidget._flashTrackY
            _superIslandWidget._startExitTransition()
            root._sampleSuperIslandState()
        }
    }

    Timer {
        id: _superIslandVerificationTimer

        interval: root._superIslandVerificationDelay
        repeat: false
        running: false
        onTriggered: {
            root._sampleSuperIslandState()

            try {
                root._assertSuperIslandContract()
                root._reportStatus("PASS", "super-island")
            } catch (error) {
                root._reportStatus("FAIL", error.message)
            }

            root._restoreSuperIslandSettings()
            Qt.callLater(Qt.quit)
        }
    }

    Timer {
        id: _workspaceSampler

        interval: 8
        repeat: true
        running: root._workspaceModeActive
        onTriggered: root._sampleWorkspaceState()
    }

    Timer {
        id: _workspacePrimeTimer

        interval: Math.max(24, Theme.anim.highlightDuration)
        repeat: false
        running: false
        onTriggered: {
            NiriService.workspaces.clear()
            NiriService.workspaces.append({ wsId: "1", idx: 1, isActive: true, name: "1", output: "HDMI-A-1" })
            NiriService.workspaces.append({ wsId: "2", idx: 2, isActive: false, name: "2", output: "HDMI-A-1" })
            NiriService.workspaces.append({ wsId: "3", idx: 3, isActive: false, name: "3", output: "HDMI-A-1" })

        NiriService.windows.clear()
        NiriService.windows.append({ winId: "101", title: "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW", appId: "firefox", workspaceId: "1", isFocused: true, colIdx: 0, rowIdx: 0 })
        NiriService.windows.append({ winId: "201", title: "Editor", appId: "code", workspaceId: "2", isFocused: false, colIdx: 0, rowIdx: 0 })
        NiriService.windows.append({ winId: "301", title: "Terminal", appId: "foot", workspaceId: "3", isFocused: false, colIdx: 0, rowIdx: 0 })
        NiriService.windowsUpdated()
        _workspaceWidget._focusedWindowId = "101"
        _workspaceWidget._focusedAppId = "firefox"
        _workspaceWidget._focusedTitle = "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"
        _workspaceWidget._harnessFocusWidthOverride = 244
        _workspaceWidget._harnessOverviewWidthOverride = 132
        _workspaceWidget._flashActive = false
        _workspaceWidget._holdFlashExtension = false
        _workspaceWidget._emptyWorkspaceSettling = false

            root._workspaceFocusWidth = _workspaceWidget._focusPillWidth
            root._workspaceOverviewWidth = _workspaceWidget._overviewPillWidth
            root._workspaceCollapsedWidth = root._workspaceTransition.collapsedWidth
            root._workspaceExpandedWidth = root._workspaceTransition.expandedWidth
            root._workspaceHeightTruth = root._workspaceTransition.collapsedHeight
            root._workspaceExpandMinWidth = root._workspaceCollapsedWidth
            root._workspaceExpandMaxWidth = root._workspaceCollapsedWidth
            root._workspaceCollapseMinWidth = root._workspaceExpandedWidth
            root._workspaceCollapseMaxWidth = root._workspaceExpandedWidth
            root._workspaceExpandMinHeight = root._workspaceHeightTruth
            root._workspaceExpandMaxHeight = root._workspaceHeightTruth
            root._workspaceCollapseMinHeight = root._workspaceHeightTruth
            root._workspaceCollapseMaxHeight = root._workspaceHeightTruth
            root._workspaceTransitionExpandMaxWidth = root._workspaceCollapsedWidth
            root._workspaceTransitionCollapseMinWidth = root._workspaceExpandedWidth
            root._workspacePulseOpacityMax = 0
            root._workspacePulseScaleMax = 1
            root._workspaceLocalFocusPulseMax = 0
            root._workspaceSharedWidthOwnershipMaxDelta = 0
            root._workspaceFlashHeightMax = root._workspaceHeightTruth
            root._workspaceFlashSharedHeightMin = root._workspaceHeightTruth
            root._workspaceFlashSharedHeightMax = root._workspaceHeightTruth
            root._workspaceCollapseStarted = false
            root._workspaceFlashActive = false

            root._assert(_workspaceFocusWidth > _workspaceOverviewWidth + 0.5,
                "expected harness scenario to make focus wider than overview"
                    + " (focus=" + _workspaceFocusWidth
                    + ", overview=" + _workspaceOverviewWidth + ")")
            root._assert(_workspaceCollapsedWidth <= _workspaceExpandedWidth + 0.5,
                "expected workspace transition widths to be ordered geometrically"
                    + " (collapsed=" + _workspaceCollapsedWidth
                    + ", expanded=" + _workspaceExpandedWidth
                    + ", workspaces=" + NiriService.workspaces.count
                    + ", windows=" + NiriService.windows.count
                    + ", focusedTitle='" + _workspaceWidget._focusedTitle + "')")
            root._assert(_workspaceTransition.expanded,
                "expected focus mode to map to expanded shared-width state when focus is wider")
            root._assert(Math.abs(_workspaceCollapsedWidth - Math.min(_workspaceFocusWidth, _workspaceOverviewWidth)) < 0.5,
                "expected collapsed width truth to match the smaller workspace width")
            root._assert(Math.abs(_workspaceExpandedWidth - Math.max(_workspaceFocusWidth, _workspaceOverviewWidth)) < 0.5,
                "expected expanded width truth to match the larger workspace width")

            _workspaceWidget._modeOverride = "overview"
            root._sampleWorkspaceState()
            _workspaceReturnTrigger.restart()
            _workspaceFlashTrigger.restart()
            _workspaceVerificationTimer.restart()
        }
    }

    Timer {
        id: _workspaceReturnTrigger

        interval: root._workspaceReturnDelay
        repeat: false
        running: false
        onTriggered: {
            root._sampleWorkspaceState()
            root._assert(!_workspaceTransition.expanded,
                "expected overview mode to map to collapsed shared-width state when focus is wider")
            root._workspaceCollapseStarted = true
            _workspaceWidget._modeOverride = "focus"
            root._sampleWorkspaceState()
        }
    }

    Timer {
        id: _workspaceFlashTrigger

        interval: root._workspaceFlashTriggerDelay
        repeat: false
        running: false
        onTriggered: {
            root._sampleWorkspaceState()
            root._workspaceFlashActive = true
            _workspaceWidget._triggerFlash()
            root._sampleWorkspaceState()
        }
    }

    Timer {
        id: _workspaceVerificationTimer

        interval: root._workspaceVerificationDelay
        repeat: false
        running: false
        onTriggered: {
            root._sampleWorkspaceState()

            try {
                root._assertWorkspaceContract()
                root._reportStatus("PASS", "workspace")
            } catch (error) {
                root._reportStatus("FAIL", error.message)
            }

            root._restoreWorkspaceSettings()
            Qt.callLater(Qt.quit)
        }
    }

    function _reportStatus(status, message) {
        console.log("BAR_MOTION_HARNESS_STATUS:" + status + ":" + message)
    }

    function _assert(condition, message) {
        if (!condition)
            throw new Error(message)
    }

    function _assertModeImplemented(mode) {
        _assert(_implementedModes.indexOf(mode) !== -1,
            "unsupported harness mode: " + mode)
    }

    function _sampleTimelineState() {
        const currentWidth = transition.animatedWidth
        const currentHeight = transition.animatedHeight

        if (!_timelinePulseDisabled) {
            _timelinePulseOpacityMax = Math.max(_timelinePulseOpacityMax, transition.pulseOpacity)
            _timelinePulseScaleMax = Math.max(_timelinePulseScaleMax, transition.pulseScale)
        } else {
            _timelinePulseOpacityMaxWhileDisabled = Math.max(_timelinePulseOpacityMaxWhileDisabled,
                transition.pulseOpacity)
            _timelinePulseScaleDeviationWhileDisabled = Math.max(_timelinePulseScaleDeviationWhileDisabled,
                Math.abs(transition.pulseScale - 1))
        }

        if (!_timelineCollapseStarted) {
            _timelineExpandMinWidth = Math.min(_timelineExpandMinWidth, currentWidth)
            _timelineExpandMaxWidth = Math.max(_timelineExpandMaxWidth, currentWidth)
            _timelineObservedExpandUndershoot = _timelineObservedExpandUndershoot
                || currentWidth < transition.collapsedWidth
            _timelineObservedExpandOvershoot = _timelineObservedExpandOvershoot
                || currentWidth > transition.expandedWidth
            return
        }

        _timelineCollapseMinWidth = Math.min(_timelineCollapseMinWidth, currentWidth)
        _timelineCollapseMinHeight = Math.min(_timelineCollapseMinHeight, currentHeight)
        _timelineCollapseMaxHeight = Math.max(_timelineCollapseMaxHeight, currentHeight)
        _timelineObservedCollapseHeightOvershoot = _timelineObservedCollapseHeightOvershoot
            || currentHeight > transition.expandedHeight
        _timelineObservedCollapseWidthUndershoot = _timelineObservedCollapseWidthUndershoot
            || currentWidth < transition.collapsedWidth
        _timelineObservedCollapseHeightUndershoot = _timelineObservedCollapseHeightUndershoot
            || currentHeight < transition.collapsedHeight
    }

    function _restoreTimelineSettings() {
        SettingsService.data.barMotion.pulseEnabled = _timelineOriginalPulseEnabled
    }

    function _restoreSuperIslandSettings() {
        SettingsService.data.barMotion.pulseEnabled = _superIslandOriginalPulseEnabled
        SuperIslandService._suppressExternalSources = _superIslandOriginalSuppressExternalSources
    }

    function _restoreWorkspaceSettings() {
        SettingsService.data.workspaceWidget.defaultMode = _workspaceOriginalDefaultMode
        SettingsService.data.workspaceWidget.hoverEnabled = _workspaceOriginalHoverEnabled
        SettingsService.data.barMotion.pulseEnabled = _workspaceOriginalPulseEnabled
        _workspaceWidget._harnessFocusWidthOverride = -1
        _workspaceWidget._harnessOverviewWidthOverride = -1
    }

    function _pushUnique(objects, candidate) {
        if (!candidate)
            return

        if (objects.indexOf(candidate) === -1)
            objects.push(candidate)
    }

    function _visitObjectTree(candidate, visitor, visited) {
        if (!candidate)
            return

        if (visited.indexOf(candidate) !== -1)
            return

        visited.push(candidate)
        visitor(candidate)

        const descendants = []

        if (candidate.contentItem !== undefined)
            _pushUnique(descendants, candidate.contentItem)

        if (candidate.children !== undefined) {
            for (let index = 0; index < candidate.children.length; index++)
                _pushUnique(descendants, candidate.children[index])
        }

        if (candidate.data !== undefined) {
            for (let index = 0; index < candidate.data.length; index++)
                _pushUnique(descendants, candidate.data[index])
        }

        for (let index = 0; index < descendants.length; index++)
            _visitObjectTree(descendants[index], visitor, visited)
    }

    function _hasObjectName(candidate, objectName) {
        let found = false

        _visitObjectTree(candidate, item => {
            if (item.objectName === objectName)
                found = true
        }, [])

        return found
    }

    function _findObjectByName(candidate, objectName) {
        let found = null

        _visitObjectTree(candidate, item => {
            if (!found && item.objectName === objectName)
                found = item
        }, [])

        return found
    }

    function _isVisible(candidate) {
        return candidate !== null && candidate !== undefined && candidate.visible !== false
    }

    function _assertSettingsContract() {
        _assert(Theme.anim.barExpandExpandOvershootRatio !== undefined,
            "missing Theme.anim.barExpand* tokens")
        _assert(Theme.anim.barExpandPulseEnabled !== undefined,
            "missing Theme.anim.barExpandPulseEnabled semantic token")
        _assert(SettingsService.data.barMotion !== undefined,
            "missing SettingsService.data.barMotion")
    }

    function _assertSharedMotionSectionMounted() {
        _assert(_hasObjectName(_settingsPanel, "barMotionPresetSelector"),
            "missing shared bar motion preset selector in WidgetSettingsPanel")
        _assert(_hasObjectName(_settingsPanel, "barMotionIntensitySlider"),
            "missing shared bar motion intensity slider in WidgetSettingsPanel")
        _assert(_hasObjectName(_settingsPanel, "barMotionSpeedSlider"),
            "missing shared bar motion speed slider in WidgetSettingsPanel")
        _assert(_hasObjectName(_settingsPanel, "barMotionPulseToggle"),
            "missing shared bar motion pulse toggle in WidgetSettingsPanel")
    }

    function _openWidgetSettings(instanceKey) {
        BarLayoutService.activeWidgetInstanceKey = instanceKey
        BarLayoutService.widgetSettingsX = 120
        BarLayoutService.widgetSettingsPanelOpen = true
    }

    function _assertSharedAndWidgetSpecificSeparation(instanceKey, expectsSpecificSection) {
        _openWidgetSettings(instanceKey)

        const sharedMotionGroup = _findObjectByName(_settingsPanel, "widgetSettingsSharedMotionGroup")
        const widgetSpecificGroup = _findObjectByName(_settingsPanel, "widgetSettingsWidgetSpecificGroup")
        const emptyState = _findObjectByName(_settingsPanel, "widgetSettingsWidgetSpecificEmptyState")
        const workspaceSection = _findObjectByName(_settingsPanel, "workspaceWidgetSettingsSection")

        _assert(_isVisible(sharedMotionGroup),
            "missing visible shared motion group for " + instanceKey)
        _assert(_isVisible(widgetSpecificGroup),
            "missing visible widget-specific group for " + instanceKey)
        _assert(sharedMotionGroup.parent === widgetSpecificGroup,
            "expected shared motion block to live inside the functional group for " + instanceKey)
        _assertSharedMotionSectionMounted()

        if (expectsSpecificSection) {
            _assert(_isVisible(workspaceSection),
                "missing widget-specific settings section for " + instanceKey)
            _assert(!_isVisible(emptyState),
                "widget-specific empty state should be hidden for " + instanceKey)
        } else {
            _assert(_isVisible(emptyState),
                "missing widget-specific empty state for " + instanceKey)
            _assert(!_isVisible(workspaceSection),
                "unexpected workspace widget settings section for " + instanceKey)
        }
    }

    function _assertBarMotionPresetProfiles() {
        const originalPreset = SettingsService.data.barMotion.preset
        const profiles = {}

        for (const preset of ["soft", "balanced", "snappy"]) {
            SettingsService.data.barMotion.preset = preset
            profiles[preset] = {
                preloadDuration: Theme.anim.barExpandPreloadDuration,
                overshootDuration: Theme.anim.barExpandOvershootDuration,
                settleDuration: Theme.anim.barExpandSettleDuration,
                expandOvershootRatio: Theme.anim.barExpandExpandOvershootRatio,
                collapseOvershootRatio: Theme.anim.barExpandCollapseOvershootRatio,
                expandPulseOpacity: Theme.anim.barExpandExpandPulseOvershootOpacity,
                expandPulseScale: Theme.anim.barExpandExpandPulseOvershootScale,
                collapsePulseScale: Theme.anim.barExpandCollapsePulseOvershootScale
            }
        }

        _assert(profiles.soft.preloadDuration > profiles.balanced.preloadDuration,
            "expected soft preset to slow preload motion")
        _assert(profiles.balanced.preloadDuration > profiles.snappy.preloadDuration,
            "expected snappy preset to speed preload motion")
        _assert(profiles.soft.overshootDuration > profiles.balanced.overshootDuration,
            "expected soft preset to lengthen overshoot motion")
        _assert(profiles.balanced.overshootDuration > profiles.snappy.overshootDuration,
            "expected snappy preset to shorten overshoot motion")
        _assert(profiles.soft.expandOvershootRatio < profiles.balanced.expandOvershootRatio,
            "expected soft preset to reduce expand overshoot")
        _assert(profiles.balanced.expandOvershootRatio < profiles.snappy.expandOvershootRatio,
            "expected snappy preset to increase expand overshoot")
        _assert(profiles.soft.collapseOvershootRatio < profiles.balanced.collapseOvershootRatio,
            "expected soft preset to reduce collapse overshoot")
        _assert(profiles.balanced.collapseOvershootRatio < profiles.snappy.collapseOvershootRatio,
            "expected snappy preset to increase collapse overshoot")
        _assert(profiles.soft.expandPulseOpacity < profiles.balanced.expandPulseOpacity,
            "expected soft preset to reduce pulse opacity")
        _assert(profiles.balanced.expandPulseOpacity < profiles.snappy.expandPulseOpacity,
            "expected snappy preset to increase pulse opacity")
        _assert(profiles.soft.expandPulseScale < profiles.balanced.expandPulseScale,
            "expected soft preset to reduce expand pulse scale")
        _assert(profiles.balanced.expandPulseScale < profiles.snappy.expandPulseScale,
            "expected snappy preset to increase expand pulse scale")
        _assert(profiles.soft.collapsePulseScale > profiles.balanced.collapsePulseScale,
            "expected soft preset to keep collapse pulse closer to 1x")
        _assert(profiles.balanced.collapsePulseScale > profiles.snappy.collapsePulseScale,
            "expected snappy preset to deepen collapse pulse recoil")

        SettingsService.data.barMotion.preset = originalPreset
    }

    function _assertBarMotionSanitization() {
        const maxIntensity = 2.0
        const originalIntensity = SettingsService.data.barMotion.intensity
        const originalSpeedMultiplier = SettingsService.data.barMotion.speedMultiplier

        SettingsService.data.barMotion.intensity = -3
        SettingsService.data.barMotion.speedMultiplier = 0

        _assert(SettingsService.data.barMotion.intensity >= 0,
            "barMotion.intensity should clamp invalid negative values")
        _assert(SettingsService.data.barMotion.speedMultiplier > 0,
            "barMotion.speedMultiplier should clamp invalid non-positive values")
        _assert(Theme.anim.barExpandPreloadDuration >= 1,
            "Theme.anim.barExpandPreloadDuration should stay valid after barMotion sanitization")
        _assert(Theme.anim.barExpandExpandOvershootRatio >= 0,
            "Theme.anim.barExpandExpandOvershootRatio should stay valid after barMotion sanitization")
        _assert(Theme.anim.barExpandExpandPulseOvershootOpacity >= 0,
            "Theme.anim.barExpandExpandPulseOvershootOpacity should stay valid after barMotion sanitization")

        SettingsService.data.barMotion.intensity = 999

        _assert(SettingsService.data.barMotion.intensity <= maxIntensity,
            "barMotion.intensity should clamp persisted oversized values")
        _assert(Theme.anim.barExpandCollapsePulseOvershootScale >= 0,
            "Theme.anim.barExpandCollapsePulseOvershootScale should stay non-negative after oversized barMotion sanitization")

        SettingsService.data.barMotion.intensity = originalIntensity
        SettingsService.data.barMotion.speedMultiplier = originalSpeedMultiplier
    }

    function _assertTimelinePhases() {
        _assert(_timelineObservedExpandUndershoot,
            "expected expand width to dip below collapsed width before expanding")
        _assert(_timelineObservedExpandOvershoot,
            "expected expand width to exceed expanded width before settling")
        _assert(_timelineObservedImmediateExpandRetargetWidthMotion,
            "expected expand width to react during the running timeline after expanded target grows")
        _assert(Math.abs(_timelineExpandedSettleWidth - transition.expandedWidth) < 0.5,
            "expected expand to resync to latest expandedWidth before collapse")
        _assert(Math.abs(_timelineExpandedSettleHeight - transition.expandedHeight) < 0.5,
            "expected expand to resync to latest expandedHeight before collapse")
        _assert(_timelinePulseOpacityMax > 0.01,
            "expected pulse opacity to animate while pulse is enabled")
        _assert(_timelinePulseScaleMax > 1.001,
            "expected pulse scale to animate while pulse is enabled")
        _assert(_timelineObservedCollapseHeightOvershoot,
            "expected collapse height to exceed expanded height before shrinking")
        _assert(_timelineObservedImmediateCollapseRetargetWidthMotion,
            "expected collapse width to react during the running timeline after collapsed target shrinks")
        _assert(_timelineObservedCollapseWidthUndershoot,
            "expected collapse width to dip below collapsed width before settling")
        _assert(_timelineObservedCollapseHeightUndershoot,
            "expected collapse height to dip below collapsed height before settling")
        _assert(_timelinePulseOpacityMaxWhileDisabled < 0.001,
            "expected pulse opacity to stay flat while pulse is disabled")
        _assert(_timelinePulseScaleDeviationWhileDisabled < 0.001,
            "expected pulse scale to stay flat while pulse is disabled")
        _assert(!transition.running,
            "expected transition timeline to settle before verification")
        _assert(Math.abs(transition.animatedWidth - transition.collapsedWidth) < 0.5,
            "expected collapsed width to settle back to collapsedWidth")
        _assert(Math.abs(transition.animatedHeight - transition.collapsedHeight) < 0.5,
            "expected collapsed height to settle back to collapsedHeight")
    }

    function _findWorkspaceTransition() {
        return _findObjectByName(_workspaceWidget, "workspaceSharedTransition")
    }

    function _findWorkspacePillClip() {
        return _findObjectByName(_workspaceWidget, "workspacePillClip")
    }

    function _findWorkspacePillBackground() {
        return _findObjectByName(_workspaceWidget, "workspacePillBackground")
    }

    function _findWorkspaceFocusRow() {
        return _findObjectByName(_workspaceWidget, "workspaceFocusRow")
    }

    function _primeWorkspaceHarness() {
        _workspaceOriginalDefaultMode = SettingsService.data.workspaceWidget.defaultMode
        _workspaceOriginalHoverEnabled = SettingsService.data.workspaceWidget.hoverEnabled
        _workspaceOriginalPulseEnabled = SettingsService.data.barMotion.pulseEnabled

        SettingsService.data.workspaceWidget.defaultMode = "focus"
        SettingsService.data.workspaceWidget.hoverEnabled = false
        SettingsService.data.barMotion.pulseEnabled = true

        NiriService.workspaces.clear()
        NiriService.workspaces.append({ wsId: "1", idx: 1, isActive: true, name: "1", output: "HDMI-A-1" })
        NiriService.workspaces.append({ wsId: "2", idx: 2, isActive: false, name: "2", output: "HDMI-A-1" })
        NiriService.workspaces.append({ wsId: "3", idx: 3, isActive: false, name: "3", output: "HDMI-A-1" })

        NiriService.windows.clear()
        NiriService.windows.append({ winId: "101", title: "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW", appId: "firefox", workspaceId: "1", isFocused: true, colIdx: 0, rowIdx: 0 })
        NiriService.windows.append({ winId: "201", title: "Editor", appId: "code", workspaceId: "2", isFocused: false, colIdx: 0, rowIdx: 0 })
        NiriService.windows.append({ winId: "301", title: "Terminal", appId: "foot", workspaceId: "3", isFocused: false, colIdx: 0, rowIdx: 0 })
        NiriService.windowsUpdated()

        _workspaceWidget._flashActive = false
        _workspaceWidget._holdFlashExtension = false
        _workspaceWidget._emptyWorkspaceSettling = false
        _workspaceWidget._modeOverride = "focus"

        _workspaceTransition = _findWorkspaceTransition()
        _workspacePillClip = _findWorkspacePillClip()
        _workspacePillBackground = _findWorkspacePillBackground()
        _workspaceFocusRow = _findWorkspaceFocusRow()

        _assert(_workspaceTransition !== null,
            "missing WorkspaceWidget shared transition in harness")
        _assert(_workspacePillClip !== null,
            "missing WorkspaceWidget pill clip in harness")
        _assert(_workspacePillBackground !== null,
            "missing WorkspaceWidget pill background in harness")
        _assert(_workspaceFocusRow !== null,
            "missing WorkspaceWidget focus row in harness")

        _workspacePrimeTimer.restart()
    }

    function _sampleWorkspaceState() {
        if (!_workspaceModeActive || !_workspaceTransition || !_workspacePillClip)
            return

        const currentWidth = _workspacePillClip.width
        const currentHeight = _workspaceTransition.animatedHeight
        const currentTransitionWidth = _workspaceTransition.animatedWidth
        const currentLocalPulseOpacity = _workspaceFocusRow ? _workspaceFocusRow._pulseOpacity : 0

        if (!_workspaceWidget._flashActive) {
            _workspaceSharedWidthOwnershipMaxDelta = Math.max(_workspaceSharedWidthOwnershipMaxDelta,
                Math.abs(currentWidth - currentTransitionWidth))
        }

        _workspaceLocalFocusPulseMax = Math.max(_workspaceLocalFocusPulseMax, currentLocalPulseOpacity)

        if (_workspaceFlashActive) {
            _workspaceFlashHeightMax = Math.max(_workspaceFlashHeightMax, _workspacePillBackground.height)
            _workspaceFlashSharedHeightMin = Math.min(_workspaceFlashSharedHeightMin, currentHeight)
            _workspaceFlashSharedHeightMax = Math.max(_workspaceFlashSharedHeightMax, currentHeight)
        }

        if (!_workspaceCollapseStarted) {
            _workspaceExpandMinWidth = Math.min(_workspaceExpandMinWidth, currentWidth)
            _workspaceExpandMaxWidth = Math.max(_workspaceExpandMaxWidth, currentWidth)
            _workspaceTransitionExpandMaxWidth = Math.max(_workspaceTransitionExpandMaxWidth, currentTransitionWidth)
            _workspaceExpandMinHeight = Math.min(_workspaceExpandMinHeight, currentHeight)
            _workspaceExpandMaxHeight = Math.max(_workspaceExpandMaxHeight, currentHeight)
            _workspacePulseOpacityMax = Math.max(_workspacePulseOpacityMax, _workspaceTransition.pulseOpacity)
            _workspacePulseScaleMax = Math.max(_workspacePulseScaleMax, _workspaceTransition.pulseScale)
            return
        }

        _workspaceCollapseMinWidth = Math.min(_workspaceCollapseMinWidth, currentWidth)
        _workspaceCollapseMaxWidth = Math.max(_workspaceCollapseMaxWidth, currentWidth)
        _workspaceTransitionCollapseMinWidth = Math.min(_workspaceTransitionCollapseMinWidth, currentTransitionWidth)
        _workspaceCollapseMinHeight = Math.min(_workspaceCollapseMinHeight, currentHeight)
        _workspaceCollapseMaxHeight = Math.max(_workspaceCollapseMaxHeight, currentHeight)
    }

    function _assertWorkspaceContract() {
        _assert(_workspaceTransition.animateWidth,
            "expected workspace transition to own width animation")
        _assert(!_workspaceTransition.animateHeight,
            "expected workspace transition to leave height fixed")
        _assert(_workspaceSharedWidthOwnershipMaxDelta < 0.5,
            "expected workspace pill width to stay owned by the shared transition"
                + " (maxDelta=" + _workspaceSharedWidthOwnershipMaxDelta + ")")
        _assert(Math.abs(_workspaceTransition.collapsedHeight - _workspaceTransition.expandedHeight) < 0.5,
            "expected workspace collapsed and expanded heights to stay equal")
        _assert(_workspaceExpandMinWidth < _workspaceCollapsedWidth - 0.5,
            "expected workspace width to reverse-preload below collapsed width before expanding"
                + " (min=" + _workspaceExpandMinWidth + ", collapsed=" + _workspaceCollapsedWidth + ")")
        _assert(_workspaceExpandMaxWidth > _workspaceExpandedWidth + 0.5,
            "expected workspace width to overshoot past expanded width before settling"
                + " (max=" + _workspaceExpandMaxWidth
                + ", transitionMax=" + _workspaceTransitionExpandMaxWidth
                + ", expanded=" + _workspaceExpandedWidth + ")")
        _assert(_workspaceCollapseMaxWidth > _workspaceExpandedWidth + 0.5,
            "expected workspace width to reverse-preload above expanded width before collapsing"
                + " (max=" + _workspaceCollapseMaxWidth
                + ", transitionMax=" + _workspaceTransitionExpandMaxWidth
                + ", expanded=" + _workspaceExpandedWidth + ")")
        _assert(_workspaceCollapseMinWidth < _workspaceCollapsedWidth - 0.5,
            "expected workspace width to overshoot below collapsed width before settling"
                + " (min=" + _workspaceCollapseMinWidth + ", collapsed=" + _workspaceCollapsedWidth + ")")
        _assert(Math.abs(_workspaceExpandMinHeight - _workspaceHeightTruth) < 0.5,
            "expected workspace expand height minimum to stay at the fixed truth")
        _assert(Math.abs(_workspaceExpandMaxHeight - _workspaceHeightTruth) < 0.5,
            "expected workspace expand height maximum to stay at the fixed truth")
        _assert(Math.abs(_workspaceCollapseMinHeight - _workspaceHeightTruth) < 0.5,
            "expected workspace collapse height minimum to stay at the fixed truth")
        _assert(Math.abs(_workspaceCollapseMaxHeight - _workspaceHeightTruth) < 0.5,
            "expected workspace collapse height maximum to stay at the fixed truth")
        _assert(_workspacePulseOpacityMax > 0.01,
            "expected workspace pulse opacity to animate on the forward beat")
        _assert(_workspacePulseScaleMax > 1.001,
            "expected workspace pulse scale to animate on the forward beat")
        _assert(_workspaceLocalFocusPulseMax < 0.001,
            "expected focus-row local pulse to stay suppressed during shared width morph")
        _assert(!_workspaceTransition.running,
            "expected workspace shared transition timeline to settle before verification")
        _assert(_workspaceTransitionExpandMaxWidth > _workspaceExpandedWidth + 0.5,
            "expected workspace shared transition itself to overshoot on expand"
                + " (max=" + _workspaceTransitionExpandMaxWidth + ", expanded=" + _workspaceExpandedWidth + ")")
        _assert(_workspaceTransitionCollapseMinWidth < _workspaceCollapsedWidth - 0.5,
            "expected workspace shared transition itself to undershoot on collapse"
                + " (min=" + _workspaceTransitionCollapseMinWidth + ", collapsed=" + _workspaceCollapsedWidth + ")")
        _assert(_workspaceTransition.expanded,
            "expected workspace shared transition to return to the wider focus truth after the reverse morph")
        _assert(Math.abs(_workspaceTransition.animatedWidth - _workspaceExpandedWidth) < 0.5,
            "expected workspace shared transition width to settle back to the wider focus truth")
        _assert(Math.abs(_workspaceTransition.animatedHeight - _workspaceHeightTruth) < 0.5,
            "expected workspace height to remain fixed after collapse")
        _assert(_workspaceFlashHeightMax > _workspaceHeightTruth + 0.5,
            "expected workspace flash height choreography to stay local on the pill background")
        _assert(Math.abs(_workspaceFlashSharedHeightMin - _workspaceHeightTruth) < 0.5,
            "expected shared transition height minimum to stay fixed during workspace flash")
        _assert(Math.abs(_workspaceFlashSharedHeightMax - _workspaceHeightTruth) < 0.5,
            "expected shared transition height maximum to stay fixed during workspace flash")
    }

    function _findSuperIslandPillClip() {
        return _findObjectByName(_superIslandWidget, "superIslandPillClip")
    }

    function _findSuperIslandPillBackground() {
        return _findObjectByName(_superIslandWidget, "superIslandPillBackground")
    }

    function _findSuperIslandTransition() {
        return _findObjectByName(_superIslandWidget, "superIslandSharedTransition")
    }

    function _superIslandCurrentWidth() {
        return _superIslandPillClip ? _superIslandPillClip.width : 0
    }

    function _superIslandCurrentHeight() {
        return _superIslandPillBackground ? _superIslandPillBackground.height : 0
    }

    function _primeSuperIslandHarness() {
        _superIslandOriginalPulseEnabled = SettingsService.data.barMotion.pulseEnabled
        _superIslandOriginalSuppressExternalSources = SuperIslandService._suppressExternalSources
        SettingsService.data.barMotion.pulseEnabled = true
        SuperIslandService._suppressExternalSources = true

        _superIslandPillClip = _findSuperIslandPillClip()
        _superIslandPillBackground = _findSuperIslandPillBackground()

        _assert(_superIslandPillClip !== null,
            "missing SuperIslandWidget pill clip in harness")
        _assert(_superIslandPillBackground !== null,
            "missing SuperIslandWidget pill background in harness")
        _superIslandTransition = _findSuperIslandTransition()
        _assert(_superIslandTransition !== null,
            "missing SuperIslandWidget shared transition in harness")

        const wideMainEvent = {
            id: "bar-motion-wide-main",
            type: "media",
            groupKey: "media",
            priority: "important",
            title: "Extremely wide transient payload",
            subtitle: "playing",
            icon: "dialog-information",
            workspaceLabel: "",
            timeoutMs: 0,
            timestamp: Date.now()
        }
        const shortFlashEvent = {
            id: _superIslandActiveEventId,
            type: "notification",
            groupKey: "bar-motion-super-island",
            priority: "important",
            title: "Short baseline",
            subtitle: "Return target",
            icon: "dialog-information",
            workspaceLabel: "",
            timeoutMs: 0,
            timestamp: Date.now()
        }

        _superIslandWidget._mainDisplayEvent = wideMainEvent
        _superIslandWidget._flashSourceEvent = shortFlashEvent
        _superIslandWidget._phase = "hold"
        _superIslandWidget._mainTrackY = _superIslandWidget._mainTrackCenterY
        _superIslandWidget._mainTrackScale = 1
        _superIslandWidget._mainTrackOpacity = 1
        _superIslandWidget._flashTrackY = _superIslandWidget._flashStripY
        _superIslandWidget._flashTrackScale = _superIslandWidget._flashScale
        _superIslandWidget._flashTrackOpacity = 0.6

        _sampleSuperIslandState()
        _superIslandCollapseTrigger.restart()
        _superIslandVerificationTimer.restart()
    }

    function _sampleSuperIslandState() {
        if (!_superIslandModeActive || !_superIslandPillClip || !_superIslandPillBackground)
            return

        _superIslandSampleTick += 1

        const currentWidth = _superIslandCurrentWidth()
        const currentHeight = _superIslandCurrentHeight()
        const widthActive = Math.abs(currentWidth - _superIslandExpandedWidth) > 0.5
        const heightActive = Math.abs(currentHeight - _superIslandExpandedHeight) > 0.5

        if (!_superIslandCollapseStarted)
            return

        _superIslandCollapseMaxWidth = Math.max(_superIslandCollapseMaxWidth, currentWidth)
        _superIslandCollapseMinWidth = Math.min(_superIslandCollapseMinWidth, currentWidth)
        _superIslandCollapseMaxHeight = Math.max(_superIslandCollapseMaxHeight, currentHeight)
        _superIslandCollapseMinHeight = Math.min(_superIslandCollapseMinHeight, currentHeight)
        _superIslandRestoreTruthWidth = _superIslandTransition.collapsedWidth
        _superIslandRestoreTruthHeight = _superIslandTransition.collapsedHeight

        if (_superIslandObservedRestoreSettled) {
            _superIslandFinalWidthMin = Math.min(_superIslandFinalWidthMin, currentWidth)
            _superIslandFinalWidthMax = Math.max(_superIslandFinalWidthMax, currentWidth)
            _superIslandFinalHeightMin = Math.min(_superIslandFinalHeightMin, currentHeight)
            _superIslandFinalHeightMax = Math.max(_superIslandFinalHeightMax, currentHeight)
        }

        if (_superIslandWidthCollapseStartTick === -1 && widthActive)
            _superIslandWidthCollapseStartTick = _superIslandSampleTick

        if (_superIslandHeightCollapseStartTick === -1 && heightActive)
            _superIslandHeightCollapseStartTick = _superIslandSampleTick

        if ((widthActive || heightActive) && _superIslandWidget._flashTrackOpacity > 0.01)
            _superIslandObservedFlashTrackWhileGeometryActive = true

        if ((widthActive || heightActive)
                && Math.abs(_superIslandWidget._flashTrackY - _superIslandFlashTrackYAtCollapseStart) > 0.5) {
            _superIslandObservedFlashTrackMotionWhileGeometryActive = true
        }

        if (!_superIslandObservedRestoreSettled
                && _superIslandTransition
                && !_superIslandTransition.running
                && Math.abs(currentWidth - _superIslandRestoreTruthWidth) < 0.5
                && Math.abs(currentHeight - _superIslandRestoreTruthHeight) < 0.5) {
            _superIslandObservedRestoreSettled = true
            _superIslandFinalWidthMin = currentWidth
            _superIslandFinalWidthMax = currentWidth
            _superIslandFinalHeightMin = currentHeight
            _superIslandFinalHeightMax = currentHeight
        }
    }

    function _assertSuperIslandContract() {
        _assert(_superIslandWidthCollapseStartTick !== -1,
            "expected super-island restore width to start changing"
                + " (collapsed=" + _superIslandCollapsedWidth
                + ", expanded=" + _superIslandExpandedWidth
                + ", min=" + _superIslandCollapseMinWidth
                + ", max=" + _superIslandCollapseMaxWidth
                + ", transitionCollapsed=" + _superIslandTransition.collapsedWidth
                + ", transitionExpanded=" + _superIslandTransition.expandedWidth + ")")
        _assert(_superIslandHeightCollapseStartTick !== -1,
            "expected super-island restore height to start changing")
        _assert(Math.abs(_superIslandWidthCollapseStartTick - _superIslandHeightCollapseStartTick) <= 1,
            "expected super-island restore width and height to start together")
        _assert(_superIslandCollapseMaxWidth > _superIslandExpandedWidth + 0.5,
            "expected super-island restore width to reverse-preload before shrinking")
        _assert(_superIslandCollapseMinWidth < _superIslandCollapsedWidth - 0.5,
            "expected super-island restore width to overshoot below collapsed width")
        _assert(_superIslandCollapseMaxHeight > _superIslandExpandedHeight + 0.5,
            "expected super-island restore height to reverse-preload before shrinking")
        _assert(_superIslandCollapseMinHeight < _superIslandCollapsedHeight - 0.5,
            "expected super-island restore height to overshoot below collapsed height")
        _assert(_superIslandObservedFlashTrackWhileGeometryActive,
            "expected flash-track content to stay visible while shared geometry restores")
        _assert(_superIslandObservedFlashTrackMotionWhileGeometryActive,
            "expected flash-track choreography to stay widget-local during restore")
        _assert(_superIslandObservedRestoreSettled,
            "expected super-island restore to settle back to the collapsed truth")
        _assert(_superIslandTransition !== null && !_superIslandTransition.running,
            "expected super-island shared transition timeline to stop after restore")
        _assert(Math.abs(_superIslandFinalWidthMin - _superIslandRestoreTruthWidth) < 0.5,
            "expected settled super-island width minimum to match collapsed truth")
        _assert(Math.abs(_superIslandFinalWidthMax - _superIslandRestoreTruthWidth) < 0.5,
            "expected settled super-island width maximum to stay at collapsed truth")
        _assert(Math.abs(_superIslandFinalHeightMin - _superIslandRestoreTruthHeight) < 0.5,
            "expected settled super-island height minimum to match collapsed truth")
        _assert(Math.abs(_superIslandFinalHeightMax - _superIslandRestoreTruthHeight) < 0.5,
            "expected settled super-island height maximum to stay at collapsed truth")
        _assert(!_superIslandWidget.flashTrackVisible,
            "expected super-island flash track to settle closed after restore")
    }

    function _assertAllModesCovered() {
        const unsupportedModes = []

        for (let index = 0; index < _knownModes.length; index++) {
            const mode = _knownModes[index]
            if (_implementedModes.indexOf(mode) === -1)
                unsupportedModes.push(mode)
        }

        _assert(unsupportedModes.length === 0,
            "all mode is blocked until these harness modes are implemented: " + unsupportedModes.join(", "))
    }

    function _runAssertions() {
        switch (_mode) {
        case "settings":
            _assertModeImplemented("settings")
            _assertSettingsContract()
            _assertBarMotionSanitization()
            _assertBarMotionPresetProfiles()
            _assertSharedAndWidgetSpecificSeparation("clock_0", false)
            _assertSharedAndWidgetSpecificSeparation("workspaceWidget_0", true)
            break
        case "timeline":
            _assertModeImplemented("timeline")
            _assertSettingsContract()
            _timelineOriginalPulseEnabled = SettingsService.data.barMotion.pulseEnabled
            SettingsService.data.barMotion.pulseEnabled = true
            transition.expanded = true
            _sampleTimelineState()
            break
        case "super-island":
            _assertModeImplemented("super-island")
            _assertSettingsContract()
            _primeSuperIslandHarness()
            break
        case "workspace":
            _assertModeImplemented("workspace")
            _assertSettingsContract()
            _primeWorkspaceHarness()
            break
        case "all":
            _assertAllModesCovered()
            throw new Error("all mode must be aggregated through tests/run-bar-motion-harness.sh so timeline, super-island, and workspace suites execute for real")
        default:
            throw new Error("unknown harness mode: " + _mode)
        }
    }

    Component.onCompleted: {
        _openWidgetSettings("clock_0")

        try {
            Qt.callLater(() => {
                try {
                    _runAssertions()

                    if (_timelineModeActive || _superIslandModeActive || _workspaceModeActive)
                        return

                    _reportStatus("PASS", _mode)
                } catch (error) {
                    _restoreTimelineSettings()
                    _restoreSuperIslandSettings()
                    _restoreWorkspaceSettings()
                    _reportStatus("FAIL", error.message)
                    Qt.callLater(Qt.quit)
                    return
                }

                Qt.callLater(Qt.quit)
            })
        } catch (error) {
            _restoreTimelineSettings()
            _restoreSuperIslandSettings()
            _restoreWorkspaceSettings()
            _reportStatus("FAIL", error.message)
            Qt.callLater(Qt.quit)
        }
    }
}
