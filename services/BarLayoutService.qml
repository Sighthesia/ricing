pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services
import "barlayout/BarLayoutGeometry.js" as GeometryUtils
import "barlayout/BarLayoutLayoutModel.js" as LayoutModelUtils
import "barlayout/BarLayoutMeasurement.js" as MeasurementUtils
import "barlayout/BarLayoutOverlaySync.js" as OverlaySyncUtils
import "barlayout/BarLayoutGeometryPipeline.js" as GeometryPipelineUtils
import "barlayout/BarLayoutSession.js" as SessionUtils
import "barlayout/BarLayoutPersistence.js" as PersistenceUtils
import "barlayout/BarLayoutArrivalSession.js" as ArrivalSessionUtils
import "barlayout/BarLayoutDragSession.js" as DragSessionUtils

// Shared bar layout service for geometry contracts, picker state, and persisted layout.
Singleton {
    id: root

    // Panel and overlay coordination state.
    // Panel state: "none" | "layout" | "config"
    property string activePanel: "none"
    property bool _suppressPanelMirror: false
    property bool _suppressNotificationHistoryMirror: false

    // True while the right-click context menu is open.
    // Used as a cross-window signal for the click-away backdrop.
    property bool contextMenuOpen: false

    // True while the tray's cascading QML menu is open.
    property bool trayMenuOpen: false

    // True while the widget picker panel is visible.
    property bool widgetPickerOpen: false

    // Which widget instance is currently being configured (instanceKey format: "{widgetId}_{n}").
    // Empty string means no widget is selected.
    property string activeWidgetInstanceKey: ""

    // Bar-coordinate X of the centre of the widget under configuration.
    // Used by WidgetSettingsPanel to position itself.
    property real widgetSettingsX: 0

    // True while the widget settings panel is visible.
    property bool widgetSettingsPanelOpen: false

    // True when the current widget-settings session entered layout mode automatically.
    property bool widgetSettingsAutoEnteredLayout: false

    // True when widgets should suppress their normal primary-button actions.
    property bool suppressWidgetPrimaryActions: settingsMode

    // True while the wallpaper picker overlay is visible.
    property bool wallpaperPickerOpen: false

    // True while the notification history panel is visible.
    property bool notificationHistoryOpen: false

    property int mediaControlFlashExtension: 0
    property var _transientExtensions: ({
        mediaControlFlashExtension: 0
    })
    readonly property var transientExtensions: _transientExtensions
    readonly property int barTransientExtension: _maxTransientExtension(transientExtensions)

    // Which bar section the picker should insert widgets into.
    // Updated whenever the user clicks a section in layout mode.
    property string widgetPickerTargetSection: "right"

    // Left-edge pixel offset used by WidgetPickerWindow to position itself
    // below the active section. Updated together with widgetPickerTargetSection.
    readonly property real widgetPickerLeftMargin: {
        let anchor = pickerAnchorGeometry(widgetPickerTargetSection)
        return anchor ? anchor.leftMargin : 0
    }

    // Horizontal anchor position for the media control detail panel.
    property real mediaControlPanelX: 0

    readonly property real barContentWidth: _barContentWidth
    readonly property real barContentPadding: _barContentPadding
    readonly property var geometryMeasuredWidths: _widgetMeasuredWidths
    readonly property var geometrySections: _sectionGeometries
    readonly property var geometrySlots: _slotGeometries
    readonly property var geometryWidgets: _widgetGeometries
    readonly property var geometryPickerAnchors: _pickerAnchors
    readonly property string superIslandInstanceKey: _superIslandInstanceKey
    readonly property var superIslandGeometry:
        _superIslandInstanceKey && _widgetGeometries[_superIslandInstanceKey] !== undefined
            ? _widgetGeometries[_superIslandInstanceKey]
            : null
    property var geometryArrivals: ({})
    readonly property var dragSnapshot: ({
        active: isDragging,
        widgetId: draggedWidgetId,
        instanceKey: draggedInstanceKey,
        hoverZone: dragHoverZone,
        visual: {
            left: dragVisualX,
            centerX: dragVisualCenterX,
            width: draggedWidth
        },
        ghost: {
            active: isDragging && ghostSection !== "" && ghostIndex >= 0,
            section: ghostSection,
            index: ghostIndex,
            line: isDragging && ghostSection !== "" && ghostIndex >= 0
                ? insertionIndicatorGeometry(ghostSection, ghostIndex, draggedInstanceKey)
                : null
        }
    })

    property real _barContentWidth: 0
    property real _barContentPadding: 0
    property var _widgetMeasuredWidths: ({})
    property var _widgetMeasurementMetadata: ({})
    property var _sectionGeometries: ({})
    property var _slotGeometries: ({})
    property var _widgetGeometries: ({})
    property var _pickerAnchors: ({})
    property var _arrivalGeometries: ({})
    property var _arrivalRevealLocks: ({})
    property var _nextInstanceSerialByWidget: ({})
    property string _superIslandInstanceKey: ""

    // FIXME: replace with service-backed shared width defaults once bar widget sizing is tokenized.
    readonly property real _fallbackMeasuredWidth: 48
    // FIXME: share picker width through a single geometry token once picker sizing is centralized.
    readonly property real _pickerPanelWidth: 480

    // Computed alias — keeps all existing DragOverlay/BarSection bindings unchanged
    readonly property bool settingsMode: activePanel === "layout"

    // Leaving layout mode must also close any widget-settings session that was opened from it.
    onSettingsModeChanged: {
        if (!settingsMode) {
            _clearWidgetSettingsSession()
        }
    }

    onActivePanelChanged: {
        if (_suppressPanelMirror)
            return

        if (activePanel === "config") {
            IslandOverlayService.openOverlay("settings", {
                source: "bar-panel"
            })
            return
        }

        if (activePanel !== "config" && IslandOverlayService.mode === "settings" && IslandOverlayService.state !== "closed") {
            IslandOverlayService.closeOverlay("bar-panel")
        }
    }

    onNotificationHistoryOpenChanged: {
        if (_suppressNotificationHistoryMirror)
            return

        if (notificationHistoryOpen) {
            IslandOverlayService.openOverlay("notifications", {
                source: "notification-bell"
            })
            return
        }

        if (IslandOverlayService.mode === "notifications" && IslandOverlayService.state !== "closed")
            IslandOverlayService.closeOverlay("notification-bell")
    }

    onWidgetPickerTargetSectionChanged: _recomputeGeometryContracts()

    // Widget settings and panel state.
    function openWidgetSettings(instanceKey, widgetCenterX) {
        let nextState = SessionUtils.openWidgetSettingsState(settingsMode, instanceKey, widgetCenterX)

        if (nextState.shouldAutoEnterLayout) {
            activePanel = "layout"
        }

        activeWidgetInstanceKey = nextState.activeWidgetInstanceKey
        widgetSettingsX = nextState.widgetSettingsX
        widgetSettingsPanelOpen = nextState.widgetSettingsPanelOpen
        widgetSettingsAutoEnteredLayout = nextState.widgetSettingsAutoEnteredLayout
    }

    function _clearWidgetSettingsSession() {
        let nextState = SessionUtils.clearWidgetSettingsSessionState()
        widgetSettingsPanelOpen = nextState.widgetSettingsPanelOpen
        activeWidgetInstanceKey = nextState.activeWidgetInstanceKey
        widgetSettingsAutoEnteredLayout = nextState.widgetSettingsAutoEnteredLayout
    }

    // Shared bar metrics and transient vertical extension.
    function setBarMetrics(contentWidth, padding) {
        let nextContentWidth = Math.max(0, Number(contentWidth) || 0)
        let nextPadding = Math.max(0, Number(padding) || 0)

        if (_barContentWidth === nextContentWidth && _barContentPadding === nextPadding) {
            return
        }

        _barContentWidth = nextContentWidth
        _barContentPadding = nextPadding
        _recomputeGeometryContracts()
    }

    function setTransientExtension(ownerKey, height) {
        if (!ownerKey) {
            return false
        }

        let nextHeight = Math.max(0, Number(height) || 0)
        let nextExtensions = Object.assign({}, _transientExtensions)

        if (nextExtensions[ownerKey] === nextHeight) {
            return true
        }

        nextExtensions[ownerKey] = nextHeight
        _transientExtensions = nextExtensions
        return true
    }

    function _maxTransientExtension(transientExtensions) {
        let maxHeight = 0

        for (let ownerKey in transientExtensions) {
            let nextHeight = Math.max(0, Number(transientExtensions[ownerKey]) || 0)

            if (nextHeight > maxHeight) {
                maxHeight = nextHeight
            }
        }

        return maxHeight
    }

    function clearTransientExtension(ownerKey) {
        if (!ownerKey || _transientExtensions[ownerKey] === undefined) {
            return false
        }

        let nextExtensions = Object.assign({}, _transientExtensions)
        delete nextExtensions[ownerKey]
        _transientExtensions = nextExtensions
        return true
    }

    onMediaControlFlashExtensionChanged: {
        setTransientExtension("mediaControlFlashExtension", mediaControlFlashExtension)
    }

    function setWidgetMeasuredWidth(instanceKey, width, options) {
        let result = MeasurementUtils.setWidgetMeasuredWidth(
            _widgetMeasuredWidths,
            _widgetMeasurementMetadata,
            instanceKey,
            width,
            options
        )

        if (!result.accepted)
            return false

        if (result.requestClear)
            return clearWidgetMeasuredWidth(instanceKey, result.clearOptions)

        if (!result.changed)
            return true

        _widgetMeasuredWidths = result.widgetMeasuredWidths
        _widgetMeasurementMetadata = result.widgetMeasurementMetadata

        if (result.widthChanged)
            _recomputeGeometryContracts()

        return true
    }

    function clearWidgetMeasuredWidth(instanceKey, options) {
        let result = MeasurementUtils.clearWidgetMeasuredWidth(
            _widgetMeasuredWidths,
            _widgetMeasurementMetadata,
            instanceKey,
            options
        )

        if (!result.accepted)
            return false

        _widgetMeasuredWidths = result.widgetMeasuredWidths
        _widgetMeasurementMetadata = result.widgetMeasurementMetadata

        if (result.hadMeasuredWidth)
            _recomputeGeometryContracts()

        return true
    }

    function measuredWidthForInstance(instanceKey) {
        return MeasurementUtils.measuredWidthForInstance(_widgetMeasuredWidths, instanceKey)
    }

    // Geometry contract accessors expose stable fallbacks for all bar sections.
    function sectionGeometry(sectionName) {
        if (_sectionGeometries[sectionName] !== undefined) {
            return _sectionGeometries[sectionName]
        }

        return GeometryUtils.emptySectionGeometry(sectionName)
    }

    function sectionSlots(sectionName) {
        let slots = _slotGeometries[sectionName]

        if (Array.isArray(slots)) {
            return slots
        }

        return []
    }

    function pickerAnchorGeometry(sectionName) {
        if (_pickerAnchors[sectionName] !== undefined) {
            return _pickerAnchors[sectionName]
        }

        return GeometryUtils.emptyPickerAnchor(sectionName)
    }

    function arrivalGeometry(instanceKey) {
        if (!instanceKey) {
            return null
        }

        return _arrivalGeometries[instanceKey] !== undefined
            ? _arrivalGeometries[instanceKey]
            : null
    }

    function widgetGeometry(instanceKey) {
        if (!instanceKey) {
            return null
        }

        return _widgetGeometries[instanceKey] !== undefined
            ? _widgetGeometries[instanceKey]
            : null
    }

    function revealLockHolder(sectionName) {
        if (!sectionName || _arrivalRevealLocks[sectionName] === undefined) {
            return ""
        }

        return _arrivalRevealLocks[sectionName] || ""
    }

    // Arrival reveal helpers keep overlay-to-delegate handoff serialized per section.
    function _resetArrivalState() {
        _applyArrivalState(ArrivalSessionUtils.resetState())
    }

    function _applyArrivalState(nextState) {
        _arrivalGeometries = nextState.arrivalGeometries
        _arrivalRevealLocks = nextState.arrivalRevealLocks
    }

    function clearArrivalGeometry(instanceKey) {
        let result = ArrivalSessionUtils.clear({
            arrivalGeometries: _arrivalGeometries,
            arrivalRevealLocks: _arrivalRevealLocks
        }, instanceKey)

        if (!result.changed)
            return false

        _applyArrivalState(result.state)
        return true
    }

    function completeArrivalGeometry(instanceKey) {
        return clearArrivalGeometry(instanceKey)
    }

    function requestArrivalReveal(instanceKey) {
        let result = ArrivalSessionUtils.requestReveal({
            arrivalGeometries: _arrivalGeometries,
            arrivalRevealLocks: _arrivalRevealLocks
        }, instanceKey, sectionSlots)

        if (!result.changed)
            return false

        _applyArrivalState(result.state)
        return true
    }

    function finishArrivalReveal(instanceKey) {
        let result = ArrivalSessionUtils.finishReveal({
            arrivalGeometries: _arrivalGeometries,
            arrivalRevealLocks: _arrivalRevealLocks
        }, instanceKey, sectionSlots)

        if (!result.changed)
            return false

        _applyArrivalState(result.state)
        return true
    }

    function openWidgetPickerForSection(sectionName) {
        if (!sectionName) {
            return
        }

        widgetPickerTargetSection = sectionName
        widgetPickerOpen = true
    }

    function toggleWidgetPickerForSection(sectionName) {
        let nextState = SessionUtils.toggleWidgetPickerState(widgetPickerOpen, widgetPickerTargetSection, sectionName)
        if (!nextState.changed)
            return

        widgetPickerOpen = nextState.widgetPickerOpen
        widgetPickerTargetSection = nextState.widgetPickerTargetSection
    }

    // Drag helpers work in bar coordinates so wrappers and overlays share one contract.
    function insertionIndexForSectionX(sectionName, localX, excludeInstanceKey) {
        return DragSessionUtils.insertionIndexForSectionX(
            sectionName,
            localX,
            excludeInstanceKey,
            sectionGeometry,
            _insertionSlots
        )
    }

    function insertionIndicatorGeometry(sectionName, insertionIndex, excludeInstanceKey) {
        return DragSessionUtils.insertionIndicatorGeometry(
            sectionName,
            insertionIndex,
            excludeInstanceKey,
            sectionGeometry,
            _insertionSlots
        )
    }

    function dragTargetAtX(visualCenterX, excludeInstanceKey) {
        return DragSessionUtils.dragTargetAtX(
            visualCenterX,
            excludeInstanceKey,
            sectionGeometry,
            _insertionSlots
        )
    }

    function sectionForBarX(barX) {
        return DragSessionUtils.sectionForBarX(barX, sectionGeometry)
    }

    function _dragState() {
        return {
            isDragging: isDragging,
            dragHoverZone: dragHoverZone,
            draggedWidgetId: draggedWidgetId,
            draggedInstanceKey: draggedInstanceKey,
            dragVisualX: dragVisualX,
            dragVisualCenterX: dragVisualCenterX,
            draggedWidth: draggedWidth,
            ghostSection: ghostSection,
            ghostIndex: ghostIndex
        }
    }

    function _applyDragState(nextState) {
        isDragging = nextState.isDragging
        dragHoverZone = nextState.dragHoverZone
        draggedWidgetId = nextState.draggedWidgetId
        draggedInstanceKey = nextState.draggedInstanceKey
        dragVisualX = nextState.dragVisualX
        dragVisualCenterX = nextState.dragVisualCenterX
        draggedWidth = nextState.draggedWidth
        ghostSection = nextState.ghostSection
        ghostIndex = nextState.ghostIndex
    }

    function beginDrag(instanceKey, widgetId, visualCenterX) {
        let beginResult = DragSessionUtils.beginDrag(
            _dragState(),
            instanceKey,
            widgetId,
            visualCenterX,
            _effectiveMeasuredWidth
        )

        if (!beginResult.changed)
            return dragSnapshot

        _applyDragState(beginResult.state)

        return updateDrag(visualCenterX)
    }

    function updateDrag(visualCenterX) {
        let updateResult = DragSessionUtils.updateDrag(_dragState(), visualCenterX, dragTargetAtX)
        if (!updateResult.changed)
            return dragSnapshot

        _applyDragState(updateResult.state)

        return dragSnapshot
    }

    function endDrag(alignment) {
        let result = DragSessionUtils.finalizeDrag(
            _dragState(),
            alignment,
            isSamePlacement,
            moveWidget
        )

        _applyDragState(result.state)
        return result.finalTarget
    }

    function _clearDragState() {
        _applyDragState(DragSessionUtils.defaultState())
    }

    function _effectiveMeasuredWidth(instanceKey) {
        let measuredWidth = measuredWidthForInstance(instanceKey)

        if (measuredWidth > 0) {
            return measuredWidth
        }

        return _fallbackMeasuredWidth
    }

    function _insertionSlots(sectionName, excludeInstanceKey) {
        return GeometryPipelineUtils.insertionSlots(
            sectionGeometry(sectionName),
            sectionSlots(sectionName),
            excludeInstanceKey
        )
    }

    function _createInstanceKey(widgetId) {
        let result = LayoutModelUtils.createInstanceKey(_nextInstanceSerialByWidget, widgetId)
        _nextInstanceSerialByWidget = result.nextSerialByWidget
        return result.instanceKey
    }

    function _ensureLayoutInstanceKeys() {
        _nextInstanceSerialByWidget = LayoutModelUtils.ensureLayoutInstanceKeys(layoutModel, _nextInstanceSerialByWidget)
    }

    function _cleanupStaleGeometryState() {
        let cleanupResult = GeometryPipelineUtils.cleanupStaleGeometryState(
            layoutModel,
            instanceKeyAt,
            _widgetMeasuredWidths,
            _widgetMeasurementMetadata,
            _arrivalGeometries,
            _arrivalRevealLocks,
            draggedInstanceKey
        )

        if (cleanupResult.changed) {
            _widgetMeasuredWidths = cleanupResult.widgetMeasuredWidths
            _widgetMeasurementMetadata = cleanupResult.widgetMeasurementMetadata
            _arrivalGeometries = cleanupResult.arrivalGeometries
            _arrivalRevealLocks = cleanupResult.arrivalRevealLocks
        }

        if (cleanupResult.clearDragState) {
            _clearDragState()
        }
    }

    function _applyGeometrySnapshot(snapshot) {
        _sectionGeometries = snapshot.sectionGeometries
        _slotGeometries = snapshot.slotGeometries
        _widgetGeometries = snapshot.widgetGeometries
        _superIslandInstanceKey = snapshot.superIslandInstanceKey
        _pickerAnchors = snapshot.pickerAnchors
        _arrivalGeometries = snapshot.arrivalGeometries
        geometryArrivals = snapshot.arrivalGeometries
    }

    function _recomputeGeometryContracts() {
        _cleanupStaleGeometryState()

        let snapshot = GeometryPipelineUtils.recomputeGeometryContracts({
            layoutModel: layoutModel,
            instanceKeyAtFn: instanceKeyAt,
            effectiveMeasuredWidthFn: _effectiveMeasuredWidth,
            arrivalGeometries: _arrivalGeometries,
            widgetPickerTargetSection: widgetPickerTargetSection,
            barContentWidth: _barContentWidth,
            barContentPadding: _barContentPadding,
            pickerPanelWidth: _pickerPanelWidth
        })

        _applyGeometrySnapshot(snapshot)
    }

    function closeWidgetSettings() {
        let nextState = SessionUtils.closeWidgetSettingsState(widgetSettingsAutoEnteredLayout)

        if (nextState.clearSession)
            _clearWidgetSettingsSession()

        if (nextState.shouldExitLayout) {
            activePanel = "none"
        }
    }

    function _syncNotificationHistoryFromOverlay() {
        let result = OverlaySyncUtils.syncNotificationHistoryFromOverlay(
            IslandOverlayService.mode,
            IslandOverlayService.state,
            notificationHistoryOpen
        )

        if (!result.changed)
            return

        _suppressNotificationHistoryMirror = true
        notificationHistoryOpen = result.notificationHistoryOpen
        _suppressNotificationHistoryMirror = false
    }

    Connections {
        target: IslandOverlayService

        function onStateChanged() {
            root._syncNotificationHistoryFromOverlay()

            let panelClose = OverlaySyncUtils.panelCloseFromOverlayState(
                IslandOverlayService.mode,
                IslandOverlayService.state,
                activePanel
            )

            if (!panelClose.shouldClosePanel)
                return

            _suppressPanelMirror = true
            activePanel = panelClose.activePanel
            _suppressPanelMirror = false
        }

        function onModeChanged() {
            root._syncNotificationHistoryFromOverlay()

            let panelState = OverlaySyncUtils.panelStateFromOverlay(IslandOverlayService.mode, activePanel)
            if (!panelState.changed)
                return

            _suppressPanelMirror = true
            activePanel = panelState.activePanel
            _suppressPanelMirror = false
        }
    }

    property bool isDragging: false
    property string dragHoverZone: ""
    property string draggedWidgetId: ""
    property string draggedInstanceKey: ""
    // Floating copy position in BarContent coordinates
    property real dragVisualX: 0
    property real dragVisualCenterX: 0
    property real draggedWidth: 0
    // Ghost insertion indicator: section + index + width
    property string ghostSection: ""
    property int ghostIndex: -1
    property ListModel layoutModel: ListModel {}

    signal layoutChanged()

    // Persisted layout model and hot-reload snapshot.
    // Default layout descriptor (from bar-design.md §三)
    readonly property var defaultLayout: [
        { id: "workspaceWidget", section: "left",   alignment: "left", order: 0, enabled: true, instanceKey: "workspaceWidget_0" },
        { id: "superIsland",     section: "center", alignment: "left", order: 0, enabled: true, instanceKey: "superIsland_0" }
    ]

    readonly property string _configDir: Quickshell.workingDirectory + "/.state"
    readonly property string _configFile: _configDir + "/layout.json"

    // Persist across hot reloads
    PersistentProperties {
        id: persist
        reloadableId: "barLayoutPersist"
        property string layoutJson: ""
    }

    Component.onCompleted: {
        PersistenceUtils.loadFromPersistOrDisk(
            persist.layoutJson,
            applyJson,
            function() { fileReader.running = true }
        )

        _recomputeGeometryContracts()
    }

    // Read saved layout from disk on startup
    Process {
        id: fileReader
        command: ["cat", root._configFile]
        stdout: SplitParser {
            onRead: data => {
                let trimmed = data.trim();
                if (trimmed !== "") root.applyJson(trimmed);
            }
        }
        onRunningChanged: {
            // If file doesn't exist or cat fails, fall back to default
            if (!running && root.layoutModel.count === 0)
                root.resetLayout();
        }
    }

    // Write layout to disk (fire-and-forget)
    Process {
        id: fileWriter
        stdinEnabled: true
        command: ["sh", "-c", "mkdir -p '" + root._configDir + "' && cat > '" + root._configFile + "'"]
    }

    function serializeLayout() {
        return LayoutModelUtils.serializeLayoutModel(layoutModel)
    }

    function _replaceLayout(entries) {
        layoutModel.clear()

        for (let i = 0; i < entries.length; i++) {
            layoutModel.append(entries[i])
        }

        _ensureLayoutInstanceKeys()
    }

    function _layoutIndexForInstanceKey(instanceKey) {
        return LayoutModelUtils.layoutIndexForInstanceKey(layoutModel, instanceKey)
    }

    function applyJson(json) {
        PersistenceUtils.applyLayoutJson(
            json,
            layoutModel.count,
            resetLayout,
            function(entries) {
                _resetArrivalState()
                _replaceLayout(entries)
            },
            function() {
                _recomputeGeometryContracts()
                layoutChanged()
            },
            function(error) {
                console.log("BarLayoutService: failed to parse layout JSON:", error)
            }
        )
    }

    function saveLayout() {
        PersistenceUtils.saveLayoutJson(layoutModel, persist, fileWriter)
    }

    function moveWidget(instanceKey, toSection, toAlignment, toOrder) {
        let result = LayoutModelUtils.moveWidget(layoutModel, instanceKey, toSection, toAlignment, toOrder)
        if (!result.changed)
            return

        _recomputeGeometryContracts()
        layoutChanged()
        saveLayout()
    }

    // Returns true if the widget already occupies the given slot
    // including alignment. Used to suppress no-op reorders.
    function isSamePlacement(instanceKey, sectionName, order, alignment) {
        let modelIndex = _layoutIndexForInstanceKey(instanceKey)

        if (modelIndex < 0) {
            return false
        }

        let item = layoutModel.get(modelIndex)
        return item.section === sectionName && item.order === order && item.alignment === alignment
    }

    // Returns the stable instance key for the widget at layoutModel[modelIndex].
    // Key format: "{widgetId}_{n}" where n counts how many prior entries share the same widgetId.
    function instanceKeyAt(modelIndex) {
        return LayoutModelUtils.instanceKeyAt(layoutModel, modelIndex)
    }

    function resetLayout() {
        _resetArrivalState()
        _replaceLayout(defaultLayout)

        _recomputeGeometryContracts()
        layoutChanged()
    }

    // Inserts a new widget instance at the end of the given section.
    function addWidget(widgetId, section) {
        let maxOrder = LayoutModelUtils.maxOrderForSection(layoutModel, section)
        let instanceKey = _createInstanceKey(widgetId)

        layoutModel.append({
            id: widgetId,
            section: section,
            alignment: "left",
            order: maxOrder + 1,
            enabled: true,
            instanceKey: instanceKey
        });
        _recomputeGeometryContracts();

        if (settingsMode) {
            let addResult = ArrivalSessionUtils.addOverlayArrivalForWidget(
                {
                    arrivalGeometries: _arrivalGeometries,
                    arrivalRevealLocks: _arrivalRevealLocks
                },
                sectionSlots(section),
                instanceKey,
                widgetId,
                section
            )

            if (addResult.changed)
                _applyArrivalState(addResult.state)
        }

        layoutChanged();
        saveLayout();
    }

    // Removes the widget instance identified by instanceKey from the layout model.
    // instanceKey must match what instanceKeyAt() would return for that entry.
    function removeWidget(instanceKey) {
        let modelIndex = _layoutIndexForInstanceKey(instanceKey)

        if (modelIndex >= 0) {
            clearArrivalGeometry(instanceKey)
            layoutModel.remove(modelIndex)

            if (activeWidgetInstanceKey === instanceKey) {
                closeWidgetSettings()
            }

            _recomputeGeometryContracts()
            layoutChanged()
            saveLayout()
            return
        }

        console.warn("BarLayoutService: removeWidget called with unknown key:", instanceKey)
    }
}
