pragma Singleton

import Quickshell
import QtQuick
import qs.config
import qs.services
import "barlayout" as BarLayoutComponents
import "barlayout/BarLayoutAccessors.js" as AccessorUtils
import "barlayout/BarLayoutCommandFacade.js" as CommandFacadeUtils
import "barlayout/BarLayoutGeometryStateFacade.js" as GeometryStateFacadeUtils
import "barlayout/BarLayoutGeometryPipeline.js" as GeometryPipelineUtils
import "barlayout/BarLayoutMetricsFacade.js" as MetricsFacadeUtils
import "barlayout/BarLayoutOverlayFacade.js" as OverlayFacadeUtils
import "barlayout/BarLayoutSessionFacade.js" as SessionFacadeUtils
import "barlayout/BarLayoutMutations.js" as MutationUtils
import "barlayout/BarLayoutDragFacade.js" as DragFacadeUtils

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
    readonly property real _widgetSpacing: Theme.widgetSpacing
    // FIXME: share picker width through a single geometry token once picker sizing is centralized.
    readonly property real _pickerPanelWidth: 480

    // Computed alias — keeps all existing DragOverlay/BarSection bindings unchanged
    readonly property bool settingsMode: activePanel === "layout"

    // Leaving layout mode must also close any widget-settings session that was opened from it.
    onSettingsModeChanged: {
        if (!settingsMode)
            SessionFacadeUtils.clearWidgetSettings(root)
    }

    onActivePanelChanged: {
        OverlayFacadeUtils.mirrorPanelToOverlay(root, IslandOverlayService)
    }

    onNotificationHistoryOpenChanged: {
        OverlayFacadeUtils.mirrorNotificationHistoryToOverlay(root, IslandOverlayService)
    }

    onWidgetPickerTargetSectionChanged: _recomputeGeometryContracts()

    // Widget settings and panel state.
    function openWidgetSettings(instanceKey, widgetCenterX) {
        SessionFacadeUtils.openWidgetSettings(root, instanceKey, widgetCenterX)
    }

    // Shared bar metrics and transient vertical extension.
    function setBarMetrics(contentWidth, padding) {
        MetricsFacadeUtils.setBarMetrics(
            _barContentWidth,
            _barContentPadding,
            contentWidth,
            padding,
            function(nextBarContentWidth, nextBarContentPadding) {
                _barContentWidth = nextBarContentWidth
                _barContentPadding = nextBarContentPadding
            },
            _recomputeGeometryContracts
        )
    }

    function setTransientExtension(ownerKey, height) {
        return MetricsFacadeUtils.setTransientExtension(
            _transientExtensions,
            ownerKey,
            height,
            function(nextTransientExtensions) {
                _transientExtensions = nextTransientExtensions
            }
        )
    }

    function _maxTransientExtension(transientExtensions) {
        return MetricsFacadeUtils.maxTransientExtension(transientExtensions)
    }

    function clearTransientExtension(ownerKey) {
        return MetricsFacadeUtils.clearTransientExtension(
            _transientExtensions,
            ownerKey,
            function(nextTransientExtensions) {
                _transientExtensions = nextTransientExtensions
            }
        )
    }

    onMediaControlFlashExtensionChanged: {
        setTransientExtension("mediaControlFlashExtension", mediaControlFlashExtension)
    }

    function setWidgetMeasuredWidth(instanceKey, width, options) {
        return MetricsFacadeUtils.setWidgetMeasuredWidth(
            _widgetMeasuredWidths,
            _widgetMeasurementMetadata,
            instanceKey,
            width,
            options,
            {
                clearWidgetMeasuredWidth: clearWidgetMeasuredWidth,
                applyMeasurementState: function(nextMeasuredWidths, nextMeasurementMetadata) {
                    _widgetMeasuredWidths = nextMeasuredWidths
                    _widgetMeasurementMetadata = nextMeasurementMetadata
                },
                recomputeGeometryContracts: _recomputeGeometryContracts
            }
        )
    }

    function clearWidgetMeasuredWidth(instanceKey, options) {
        return MetricsFacadeUtils.clearWidgetMeasuredWidth(
            _widgetMeasuredWidths,
            _widgetMeasurementMetadata,
            instanceKey,
            options,
            {
                applyMeasurementState: function(nextMeasuredWidths, nextMeasurementMetadata) {
                    _widgetMeasuredWidths = nextMeasuredWidths
                    _widgetMeasurementMetadata = nextMeasurementMetadata
                },
                recomputeGeometryContracts: _recomputeGeometryContracts
            }
        )
    }

    function measuredWidthForInstance(instanceKey) {
        return MetricsFacadeUtils.measuredWidthForInstance(_widgetMeasuredWidths, instanceKey)
    }

    // Geometry contract accessors expose stable fallbacks for all bar sections.
    function sectionGeometry(sectionName) {
        return AccessorUtils.sectionGeometry(_sectionGeometries, sectionName)
    }

    function sectionSlots(sectionName) {
        return AccessorUtils.sectionSlots(_slotGeometries, sectionName)
    }

    function pickerAnchorGeometry(sectionName) {
        return AccessorUtils.pickerAnchorGeometry(_pickerAnchors, sectionName)
    }

    function arrivalGeometry(instanceKey) {
        return AccessorUtils.arrivalGeometry(_arrivalGeometries, instanceKey)
    }

    function widgetGeometry(instanceKey) {
        return AccessorUtils.widgetGeometry(_widgetGeometries, instanceKey)
    }

    function revealLockHolder(sectionName) {
        return AccessorUtils.revealLockHolder(_arrivalRevealLocks, sectionName)
    }

    function clearArrivalGeometry(instanceKey) {
        return GeometryStateFacadeUtils.clearArrivalGeometry(root, instanceKey)
    }

    function completeArrivalGeometry(instanceKey) {
        return GeometryStateFacadeUtils.completeArrivalGeometry(root, instanceKey)
    }

    function requestArrivalReveal(instanceKey) {
        return GeometryStateFacadeUtils.requestArrivalReveal(root, instanceKey, sectionSlots)
    }

    function finishArrivalReveal(instanceKey) {
        return GeometryStateFacadeUtils.finishArrivalReveal(root, instanceKey, sectionSlots)
    }

    function openWidgetPickerForSection(sectionName) {
        SessionFacadeUtils.openWidgetPickerForSection(root, sectionName)
    }

    function toggleWidgetPickerForSection(sectionName) {
        SessionFacadeUtils.toggleWidgetPickerForSection(root, sectionName)
    }

    // Drag helpers work in bar coordinates so wrappers and overlays share one contract.
    function insertionIndexForSectionX(sectionName, localX, excludeInstanceKey) {
        return DragFacadeUtils.insertionIndexForSectionX(sectionName, localX, excludeInstanceKey, sectionGeometry, _insertionSlots)
    }

    function insertionIndicatorGeometry(sectionName, insertionIndex, excludeInstanceKey) {
        return DragFacadeUtils.insertionIndicatorGeometry(sectionName, insertionIndex, excludeInstanceKey, sectionGeometry, _insertionSlots)
    }

    function dragTargetAtX(visualCenterX, excludeInstanceKey) {
        return DragFacadeUtils.dragTargetAtX(visualCenterX, excludeInstanceKey, sectionGeometry, _insertionSlots)
    }

    function sectionForBarX(barX) {
        return DragFacadeUtils.sectionForBarX(barX, sectionGeometry)
    }

    function _dragState() {
        return DragFacadeUtils.dragState(root)
    }

    function _applyDragState(nextState) {
        DragFacadeUtils.applyDragState(root, nextState)
    }

    function beginDrag(instanceKey, widgetId, visualCenterX) {
        return DragFacadeUtils.beginDrag(root, instanceKey, widgetId, visualCenterX, _effectiveMeasuredWidth, updateDrag)
    }

    function updateDrag(visualCenterX) {
        return DragFacadeUtils.updateDrag(root, visualCenterX, dragTargetAtX)
    }

    function endDrag(alignment) {
        return DragFacadeUtils.endDrag(root, alignment, isSamePlacement, moveWidget)
    }

    function _clearDragState() {
        DragFacadeUtils.clearDragState(root)
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
            excludeInstanceKey,
            _widgetSpacing
        )
    }

    function _recomputeGeometryContracts() {
        GeometryStateFacadeUtils.recomputeGeometryContracts(root, {
            layoutModel: layoutModel,
            instanceKeyAtFn: instanceKeyAt,
            effectiveMeasuredWidthFn: _effectiveMeasuredWidth,
            clearDragStateFn: _clearDragState,
            pickerPanelWidth: _pickerPanelWidth,
            widgetSpacing: _widgetSpacing
        })
    }

    function closeWidgetSettings() {
        SessionFacadeUtils.closeWidgetSettings(root)
    }

    function _syncNotificationHistoryFromOverlay() {
        OverlayFacadeUtils.syncNotificationHistoryFromOverlay(root, IslandOverlayService)
    }

    Connections {
        target: IslandOverlayService

        function onStateChanged() {
            root._syncNotificationHistoryFromOverlay()
            OverlayFacadeUtils.syncPanelCloseFromOverlayState(root, IslandOverlayService)
        }

        function onModeChanged() {
            root._syncNotificationHistoryFromOverlay()
            OverlayFacadeUtils.syncPanelStateFromOverlay(root, IslandOverlayService)
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

    BarLayoutComponents.BarLayoutPersistenceBridge {
        id: persistenceBridge
        serviceRoot: root
    }

    Component.onCompleted: {
        persistenceBridge.load()
    }

    function serializeLayout() {
        return CommandFacadeUtils.serializeLayout(layoutModel)
    }

    function applyJson(json) {
        return CommandFacadeUtils.applyJson(root, layoutModel, defaultLayout, json)
    }

    function saveLayout() {
        return CommandFacadeUtils.saveLayout(
            layoutModel,
            persistenceBridge.persistStore,
            persistenceBridge.fileWriterProcess
        )
    }

    function moveWidget(instanceKey, toSection, toAlignment, toOrder) {
        return CommandFacadeUtils.moveWidget(
            root,
            layoutModel,
            persistenceBridge.persistStore,
            persistenceBridge.fileWriterProcess,
            instanceKey,
            toSection,
            toAlignment,
            toOrder
        )
    }

    // Returns true if the widget already occupies the given slot
    // including alignment. Used to suppress no-op reorders.
    function isSamePlacement(instanceKey, sectionName, order, alignment) {
        return MutationUtils.isSamePlacement(layoutModel, instanceKey, sectionName, order, alignment)
    }

    // Returns the stable instance key for the widget at layoutModel[modelIndex].
    // Key format: "{widgetId}_{n}" where n counts how many prior entries share the same widgetId.
    function instanceKeyAt(modelIndex) {
        return CommandFacadeUtils.instanceKeyAt(layoutModel, modelIndex)
    }

    function resetLayout() {
        return CommandFacadeUtils.resetLayout(root, layoutModel, defaultLayout)
    }

    // Inserts a new widget instance at the end of the given section.
    function addWidget(widgetId, section) {
        return CommandFacadeUtils.addWidget(
            root,
            layoutModel,
            persistenceBridge.persistStore,
            persistenceBridge.fileWriterProcess,
            widgetId,
            section
        )
    }

    // Removes the widget instance identified by instanceKey from the layout model.
    // instanceKey must match what instanceKeyAt() would return for that entry.
    function removeWidget(instanceKey) {
        let result = CommandFacadeUtils.removeWidget(
            root,
            layoutModel,
            persistenceBridge.persistStore,
            persistenceBridge.fileWriterProcess,
            instanceKey
        )

        if (!result.removed)
            console.warn("BarLayoutService: removeWidget called with unknown key:", instanceKey)
    }
}
