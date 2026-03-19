pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    // Panel state: "none" | "layout" | "config"
    property string activePanel: "none"

    // True while the right-click context menu is open.
    // Used as a cross-window signal for the click-away backdrop.
    property bool contextMenuOpen: false

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

    // Extra pixels the bar extends downward below exclusiveZone during widget flashes.
    property int workspaceFlashExtension: 0
    property int superIslandFlashExtension: 0
    property int mediaControlFlashExtension: 0
    property int systemTrayFlashExtension: 0
    readonly property int barFlashExtension:
        Math.max(
            workspaceFlashExtension,
            superIslandFlashExtension,
            mediaControlFlashExtension,
            systemTrayFlashExtension
        )

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
    readonly property var geometryPickerAnchors: _pickerAnchors
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
    property var _pickerAnchors: ({})
    property var _arrivalGeometries: ({})
    property var _arrivalRevealLocks: ({})
    property var _nextInstanceSerialByWidget: ({})

    // FIXME: replace with service-backed shared width defaults once bar widget sizing is tokenized.
    readonly property real _fallbackMeasuredWidth: 48
    // FIXME: share picker width through a single geometry token once picker sizing is centralized.
    readonly property real _pickerPanelWidth: 480

    // Computed alias — keeps all existing DragOverlay/BarSection bindings unchanged
    readonly property bool settingsMode: activePanel === "layout"

    onSettingsModeChanged: {
        if (!settingsMode) {
            widgetSettingsPanelOpen = false;
            activeWidgetInstanceKey = "";
            widgetSettingsAutoEnteredLayout = false;
        }
    }

    onWidgetPickerTargetSectionChanged: _recomputeGeometryContracts()

    function openWidgetSettings(instanceKey, widgetCenterX) {
        let shouldAutoEnterLayout = !settingsMode

        if (shouldAutoEnterLayout) {
            activePanel = "layout"
        }

        widgetSettingsAutoEnteredLayout = shouldAutoEnterLayout
        activeWidgetInstanceKey = instanceKey
        widgetSettingsX = widgetCenterX
        widgetSettingsPanelOpen = true
    }

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

    function setWidgetMeasuredWidth(instanceKey, width, options) {
        if (!instanceKey) {
            return false
        }

        let nextWidth = Math.max(0, Number(width) || 0)
        let updateOptions = options || {}
        let source = updateOptions.source || "external"
        let reporterId = updateOptions.reporterId || ""
        let preserveExternalSnapshot = source === "runtime" && updateOptions.preserveExternalSnapshot === true

        if (nextWidth <= 0) {
            return clearWidgetMeasuredWidth(instanceKey, {
                reporterId: reporterId
            })
        }

        let currentWidth = measuredWidthForInstance(instanceKey)
        let currentMetadata = _widgetMeasurementMetadata[instanceKey] || null
        let currentSource = currentMetadata && currentMetadata.source
            ? currentMetadata.source
            : "external"
        let currentReporterId = currentMetadata && currentMetadata.reporterId
            ? currentMetadata.reporterId
            : ""

        if (preserveExternalSnapshot && currentWidth > 0 && currentSource !== "runtime") {
            return false
        }

        let nextMeasuredWidths = Object.assign({}, _widgetMeasuredWidths)
        let nextMeasurementMetadata = Object.assign({}, _widgetMeasurementMetadata)
        let widthChanged = nextMeasuredWidths[instanceKey] !== nextWidth
        let metadataChanged = currentSource !== source || currentReporterId !== reporterId

        if (!widthChanged && !metadataChanged) {
            return true
        }

        nextMeasuredWidths[instanceKey] = nextWidth
        nextMeasurementMetadata[instanceKey] = {
            source: source,
            reporterId: reporterId
        }

        _widgetMeasuredWidths = nextMeasuredWidths
        _widgetMeasurementMetadata = nextMeasurementMetadata

        if (widthChanged) {
            _recomputeGeometryContracts()
        }

        return true
    }

    function clearWidgetMeasuredWidth(instanceKey, options) {
        let clearOptions = options || {}
        let reporterId = clearOptions.reporterId || ""
        let hasMeasuredWidth = _widgetMeasuredWidths[instanceKey] !== undefined
        let hasMeasurementMetadata = _widgetMeasurementMetadata[instanceKey] !== undefined

        if (!instanceKey || (!hasMeasuredWidth && !hasMeasurementMetadata)) {
            return false
        }

        let currentMetadata = _widgetMeasurementMetadata[instanceKey] || null
        let currentSource = currentMetadata && currentMetadata.source
            ? currentMetadata.source
            : "external"
        let currentReporterId = currentMetadata && currentMetadata.reporterId
            ? currentMetadata.reporterId
            : ""

        if (reporterId) {
            if (currentSource !== "runtime") {
                return false
            }

            if (currentReporterId && currentReporterId !== reporterId) {
                return false
            }
        }

        let nextMeasuredWidths = Object.assign({}, _widgetMeasuredWidths)
        let nextMeasurementMetadata = Object.assign({}, _widgetMeasurementMetadata)

        delete nextMeasuredWidths[instanceKey]
        delete nextMeasurementMetadata[instanceKey]

        _widgetMeasuredWidths = nextMeasuredWidths
        _widgetMeasurementMetadata = nextMeasurementMetadata

        if (hasMeasuredWidth) {
            _recomputeGeometryContracts()
        }

        return true
    }

    function measuredWidthForInstance(instanceKey) {
        if (!instanceKey) {
            return 0
        }

        let measuredWidth = _widgetMeasuredWidths[instanceKey]
        return typeof measuredWidth === "number" ? measuredWidth : 0
    }

    function sectionGeometry(sectionName) {
        if (_sectionGeometries[sectionName] !== undefined) {
            return _sectionGeometries[sectionName]
        }

        return _emptySectionGeometry(sectionName)
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

        return _emptyPickerAnchor(sectionName)
    }

    function arrivalGeometry(instanceKey) {
        if (!instanceKey) {
            return null
        }

        return _arrivalGeometries[instanceKey] !== undefined
            ? _arrivalGeometries[instanceKey]
            : null
    }

    function revealLockHolder(sectionName) {
        if (!sectionName || _arrivalRevealLocks[sectionName] === undefined) {
            return ""
        }

        return _arrivalRevealLocks[sectionName] || ""
    }

    function clearArrivalGeometry(instanceKey) {
        if (!instanceKey || _arrivalGeometries[instanceKey] === undefined) {
            return false
        }

        let nextArrivalGeometries = Object.assign({}, _arrivalGeometries)
        let nextArrivalRevealLocks = Object.assign({}, _arrivalRevealLocks)
        delete nextArrivalGeometries[instanceKey]

        for (let sectionName in nextArrivalRevealLocks) {
            if (nextArrivalRevealLocks[sectionName] === instanceKey) {
                delete nextArrivalRevealLocks[sectionName]
            }
        }

        _arrivalGeometries = nextArrivalGeometries
        _arrivalRevealLocks = nextArrivalRevealLocks
        return true
    }

    function completeArrivalGeometry(instanceKey) {
        return clearArrivalGeometry(instanceKey)
    }

    function requestArrivalReveal(instanceKey) {
        let snapshot = arrivalGeometry(instanceKey)
        if (!snapshot || snapshot.active !== true) {
            return false
        }

        let nextArrivalGeometries = Object.assign({}, _arrivalGeometries)
        nextArrivalGeometries[instanceKey] = Object.assign({}, snapshot, {
            readyForDelegate: true
        })
        _arrivalGeometries = nextArrivalGeometries

        return _tryReleaseArrivalForSection(snapshot.section)
    }

    function finishArrivalReveal(instanceKey) {
        if (!instanceKey) {
            return false
        }

        let releaseSection = ""
        for (let sectionName in _arrivalRevealLocks) {
            if (_arrivalRevealLocks[sectionName] === instanceKey) {
                releaseSection = sectionName
                break
            }
        }

        if (!releaseSection) {
            return false
        }

        let nextArrivalRevealLocks = Object.assign({}, _arrivalRevealLocks)
        delete nextArrivalRevealLocks[releaseSection]
        _arrivalRevealLocks = nextArrivalRevealLocks

        completeArrivalGeometry(instanceKey)

        return _tryReleaseArrivalForSection(releaseSection)
    }

    function _tryReleaseArrivalForSection(sectionName) {
        if (!sectionName || _arrivalRevealLocks[sectionName]) {
            return false
        }

        let slots = sectionSlots(sectionName)
        for (let i = 0; i < slots.length; i++) {
            let snapshot = _arrivalGeometries[slots[i].instanceKey]
            if (!snapshot || snapshot.active !== true) {
                continue
            }

            if (snapshot.readyForDelegate !== true) {
                return false
            }

            let releasedInstanceKey = snapshot.instanceKey
            let nextArrivalGeometries = Object.assign({}, _arrivalGeometries)
            let nextArrivalRevealLocks = Object.assign({}, _arrivalRevealLocks)

            nextArrivalGeometries[releasedInstanceKey] = Object.assign({}, snapshot, {
                phase: "delegate",
                delegateReleased: true
            })
            nextArrivalRevealLocks[sectionName] = releasedInstanceKey

            _arrivalGeometries = nextArrivalGeometries
            _arrivalRevealLocks = nextArrivalRevealLocks
            return true
        }

        return false
    }

    function openWidgetPickerForSection(sectionName) {
        if (!sectionName) {
            return
        }

        widgetPickerTargetSection = sectionName
        widgetPickerOpen = true
    }

    function toggleWidgetPickerForSection(sectionName) {
        if (!sectionName) {
            return
        }

        if (widgetPickerOpen && widgetPickerTargetSection === sectionName) {
            widgetPickerOpen = false
            return
        }

        openWidgetPickerForSection(sectionName)
    }

    function insertionIndexForSectionX(sectionName, localX, excludeInstanceKey) {
        let geometry = sectionGeometry(sectionName)
        let pointerX = geometry.left + Math.max(0, Number(localX) || 0)
        let slots = _insertionSlots(sectionName, excludeInstanceKey)

        for (let i = 0; i < slots.length; i++) {
            if (pointerX < slots[i].centerX) {
                return i
            }
        }

        return slots.length
    }

    function insertionIndicatorGeometry(sectionName, insertionIndex, excludeInstanceKey) {
        let geometry = sectionGeometry(sectionName)
        let slots = _insertionSlots(sectionName, excludeInstanceKey)
        let index = Math.max(0, Number(insertionIndex) || 0)
        let boundaryX = geometry.visualLeft

        if (slots.length > 0) {
            if (index <= 0) {
                boundaryX = slots[0].left
            } else if (index >= slots.length) {
                boundaryX = slots[slots.length - 1].right
            } else {
                boundaryX = slots[index].left
            }
        }

        return {
            section: sectionName,
            index: index,
            sectionLocalX: boundaryX - geometry.left,
            barX: boundaryX,
            visible: index >= 0
        }
    }

    function dragTargetAtX(visualCenterX, excludeInstanceKey) {
        let pointerX = Math.max(0, Number(visualCenterX) || 0)
        let sectionName = sectionForBarX(pointerX)
        let geometry = sectionGeometry(sectionName)
        let localX = pointerX - geometry.left

        return {
            section: sectionName,
            index: insertionIndexForSectionX(sectionName, localX, excludeInstanceKey)
        }
    }

    function sectionForBarX(barX) {
        return _sectionForBarX(barX)
    }

    function beginDrag(instanceKey, widgetId, visualCenterX) {
        if (!instanceKey || !widgetId) {
            return dragSnapshot
        }

        let frozenWidth = _effectiveMeasuredWidth(instanceKey)

        draggedInstanceKey = instanceKey
        draggedWidgetId = widgetId
        draggedWidth = frozenWidth
        isDragging = true

        return updateDrag(visualCenterX)
    }

    function updateDrag(visualCenterX) {
        if (!isDragging || !draggedInstanceKey) {
            return dragSnapshot
        }

        let nextCenterX = Math.max(0, Number(visualCenterX) || 0)
        let dragTarget = dragTargetAtX(nextCenterX, draggedInstanceKey)

        dragVisualCenterX = nextCenterX
        dragVisualX = nextCenterX - draggedWidth / 2
        dragHoverZone = dragTarget.section
        ghostSection = dragTarget.section
        ghostIndex = dragTarget.index

        return dragSnapshot
    }

    function endDrag(alignment) {
        let targetAlignment = alignment || "left"
        let finalTarget = {
            active: isDragging,
            section: ghostSection,
            index: ghostIndex,
            instanceKey: draggedInstanceKey,
            widgetId: draggedWidgetId,
            draggedWidth: draggedWidth,
            samePlacement: false,
            moved: false
        }

        if (finalTarget.active && finalTarget.instanceKey) {
            finalTarget.samePlacement = finalTarget.section !== ""
                && isSamePlacement(
                    finalTarget.instanceKey,
                    finalTarget.section,
                    finalTarget.index,
                    targetAlignment
                )

            if (finalTarget.section !== "" && !finalTarget.samePlacement) {
                moveWidget(
                    finalTarget.instanceKey,
                    finalTarget.section,
                    targetAlignment,
                    finalTarget.index
                )
                finalTarget.moved = true
            }
        }

        _clearDragState()

        return finalTarget
    }

    function _clearDragState() {
        isDragging = false
        dragHoverZone = ""
        draggedWidgetId = ""
        draggedInstanceKey = ""
        dragVisualX = 0
        dragVisualCenterX = 0
        draggedWidth = 0
        ghostSection = ""
        ghostIndex = -1
    }

    function _emptySectionGeometry(sectionName) {
        return {
            section: sectionName,
            left: 0,
            right: 0,
            width: 0,
            centerX: 0,
            slotCount: 0,
            contentWidth: 0
        }
    }

    function _emptyPickerAnchor(sectionName) {
        return {
            section: sectionName,
            centerX: 0,
            leftMargin: 0,
            active: false
        }
    }

    function _sectionForBarX(barX) {
        let leftGeometry = sectionGeometry("left")
        let centerGeometry = sectionGeometry("center")
        let rightGeometry = sectionGeometry("right")

        if (barX < centerGeometry.left) {
            return "left"
        }

        if (barX <= centerGeometry.right) {
            return "center"
        }

        if (barX <= rightGeometry.right || rightGeometry.width <= 0) {
            return "right"
        }

        return barX < leftGeometry.left ? "left" : "right"
    }

    function _effectiveMeasuredWidth(instanceKey) {
        let measuredWidth = measuredWidthForInstance(instanceKey)

        if (measuredWidth > 0) {
            return measuredWidth
        }

        return _fallbackMeasuredWidth
    }

    function _insertionSlots(sectionName, excludeInstanceKey) {
        let slots = sectionSlots(sectionName)
        let geometry = sectionGeometry(sectionName)

        if (!excludeInstanceKey) {
            return slots
        }

        let filteredSlots = []
        let currentLeft = geometry.visualLeft

        for (let i = 0; i < slots.length; i++) {
            if (slots[i].instanceKey === excludeInstanceKey) {
                continue
            }

            let slot = slots[i]
            filteredSlots.push({
                id: slot.id,
                instanceKey: slot.instanceKey,
                section: slot.section,
                order: slot.order,
                alignment: slot.alignment,
                slotIndex: filteredSlots.length,
                measuredWidth: slot.measuredWidth,
                left: currentLeft,
                width: slot.width,
                right: currentLeft + slot.width,
                centerX: currentLeft + slot.width / 2
            })
            currentLeft += slot.width
        }

        return filteredSlots
    }

    function _parseInstanceSerial(widgetId, instanceKey) {
        if (!widgetId || !instanceKey) {
            return -1
        }

        let prefix = widgetId + "_"
        if (!instanceKey.startsWith(prefix)) {
            return -1
        }

        let serial = Number(instanceKey.slice(prefix.length))
        if (!Number.isInteger(serial) || serial < 0) {
            return -1
        }

        return serial
    }

    function _createInstanceKey(widgetId) {
        let nextSerials = Object.assign({}, _nextInstanceSerialByWidget)
        let serial = nextSerials[widgetId] || 0

        nextSerials[widgetId] = serial + 1
        _nextInstanceSerialByWidget = nextSerials

        return widgetId + "_" + serial
    }

    function _ensureLayoutInstanceKeys() {
        let nextSerials = Object.assign({}, _nextInstanceSerialByWidget)

        for (let i = 0; i < layoutModel.count; i++) {
            let item = layoutModel.get(i)
            let serial = _parseInstanceSerial(item.id, item.instanceKey)

            if (serial < 0) {
                continue
            }

            nextSerials[item.id] = Math.max(nextSerials[item.id] || 0, serial + 1)
        }

        for (let i = 0; i < layoutModel.count; i++) {
            let item = layoutModel.get(i)
            if (_parseInstanceSerial(item.id, item.instanceKey) >= 0) {
                continue
            }

            let serial = nextSerials[item.id] || 0
            layoutModel.setProperty(i, "instanceKey", item.id + "_" + serial)
            nextSerials[item.id] = serial + 1
        }

        _nextInstanceSerialByWidget = nextSerials
    }

    function _orderedEnabledWidgetsForSection(sectionName) {
        let widgets = []

        for (let i = 0; i < layoutModel.count; i++) {
            let item = layoutModel.get(i)

            if (!item.enabled || item.section !== sectionName) {
                continue
            }

            widgets.push({
                id: item.id,
                section: item.section,
                alignment: item.alignment,
                order: item.order,
                modelIndex: i,
                instanceKey: instanceKeyAt(i)
            })
        }

        widgets.sort((a, b) => {
            if (a.order !== b.order) {
                return a.order - b.order
            }

            return a.modelIndex - b.modelIndex
        })

        return widgets
    }

    function _slotGeometryOutput(sectionName, sectionLeft, orderedWidgets) {
        let slots = []
        let currentLeft = sectionLeft

        for (let i = 0; i < orderedWidgets.length; i++) {
            let widget = orderedWidgets[i]
            let measuredWidth = _effectiveMeasuredWidth(widget.instanceKey)

            slots.push({
                id: widget.id,
                instanceKey: widget.instanceKey,
                section: sectionName,
                order: widget.order,
                alignment: widget.alignment,
                slotIndex: i,
                measuredWidth: measuredWidth,
                left: currentLeft,
                width: measuredWidth,
                right: currentLeft + measuredWidth,
                centerX: currentLeft + measuredWidth / 2
            })

            currentLeft += measuredWidth
        }

        return slots
    }

    function _measuredContentWidth(orderedWidgets) {
        let totalWidth = 0

        for (let i = 0; i < orderedWidgets.length; i++) {
            totalWidth += _effectiveMeasuredWidth(orderedWidgets[i].instanceKey)
        }

        return Math.max(0, totalWidth)
    }

    function _layoutInstanceKeySet() {
        let instanceKeys = ({})

        for (let i = 0; i < layoutModel.count; i++) {
            let instanceKey = instanceKeyAt(i)
            if (!instanceKey) {
                continue
            }

            instanceKeys[instanceKey] = true
        }

        return instanceKeys
    }

    function _cleanupStaleGeometryState() {
        let activeInstanceKeys = _layoutInstanceKeySet()
        let staleGeometryEntries = []

        for (let instanceKey in _widgetMeasuredWidths) {
            if (activeInstanceKeys[instanceKey]) {
                continue
            }

            staleGeometryEntries.push(instanceKey)
        }

        for (let instanceKey in _widgetMeasurementMetadata) {
            if (activeInstanceKeys[instanceKey] || staleGeometryEntries.indexOf(instanceKey) >= 0) {
                continue
            }

            staleGeometryEntries.push(instanceKey)
        }

        if (staleGeometryEntries.length > 0) {
            let nextMeasuredWidths = Object.assign({}, _widgetMeasuredWidths)
            let nextMeasurementMetadata = Object.assign({}, _widgetMeasurementMetadata)
            let nextArrivalGeometries = Object.assign({}, _arrivalGeometries)
            let nextArrivalRevealLocks = Object.assign({}, _arrivalRevealLocks)

            for (let i = 0; i < staleGeometryEntries.length; i++) {
                delete nextMeasuredWidths[staleGeometryEntries[i]]
                delete nextMeasurementMetadata[staleGeometryEntries[i]]
                delete nextArrivalGeometries[staleGeometryEntries[i]]

                for (let sectionName in nextArrivalRevealLocks) {
                    if (nextArrivalRevealLocks[sectionName] === staleGeometryEntries[i]) {
                        delete nextArrivalRevealLocks[sectionName]
                    }
                }
            }

            _widgetMeasuredWidths = nextMeasuredWidths
            _widgetMeasurementMetadata = nextMeasurementMetadata
            _arrivalGeometries = nextArrivalGeometries
            _arrivalRevealLocks = nextArrivalRevealLocks
        }

        if (draggedInstanceKey && !activeInstanceKeys[draggedInstanceKey]) {
            _clearDragState()
        }
    }

    function _clampedSectionGeometry(sectionName, left, right, contentWidth, slotCount) {
        let nextLeft = Number(left) || 0
        let nextRight = Number(right) || 0

        if (nextRight < nextLeft) {
            nextRight = nextLeft
        }

        let width = Math.max(0, nextRight - nextLeft)

        return {
            section: sectionName,
            left: nextLeft,
            right: nextRight,
            width: width,
            centerX: nextLeft + width / 2,
            visualLeft: nextLeft,
            visualWidth: Math.max(0, Number(contentWidth) || 0),
            visualCenterX: nextLeft + Math.max(0, Number(contentWidth) || 0) / 2,
            slotCount: slotCount,
            contentWidth: Math.max(0, Number(contentWidth) || 0)
        }
    }

    function _barUsableBounds() {
        let usableLeft = _barContentPadding
        let usableRight = Math.max(usableLeft, _barContentWidth - _barContentPadding)

        return {
            left: usableLeft,
            right: usableRight,
            width: Math.max(0, usableRight - usableLeft),
            midpoint: _barContentWidth / 2
        }
    }

    function _orderedWidgetsBySection(sectionNames) {
        let orderedWidgets = {}

        for (let i = 0; i < sectionNames.length; i++) {
            let sectionName = sectionNames[i]
            orderedWidgets[sectionName] = _orderedEnabledWidgetsForSection(sectionName)
        }

        return orderedWidgets
    }

    function _contentWidthsBySection(orderedWidgetsBySection, sectionNames) {
        let contentWidths = {}

        for (let i = 0; i < sectionNames.length; i++) {
            let sectionName = sectionNames[i]
            contentWidths[sectionName] = _measuredContentWidth(orderedWidgetsBySection[sectionName])
        }

        return contentWidths
    }

    function _resolveAdaptiveSectionBounds(usableBounds, contentWidths) {
        let desiredLeftRight = Math.min(usableBounds.right, usableBounds.left + (contentWidths.left || 0))
        let desiredRightLeft = Math.max(usableBounds.left, usableBounds.right - (contentWidths.right || 0))
        let centerHalfRoom = Math.min(
            Math.max(0, usableBounds.midpoint - desiredLeftRight),
            Math.max(0, desiredRightLeft - usableBounds.midpoint)
        )
        let centerVisualWidth = contentWidths.center || 0
        let desiredCenterWidth = Math.max(0, Math.min(centerVisualWidth, centerHalfRoom * 2))
        let centerInteractionWidth = Math.max(
            0,
            Math.min(Math.max(centerVisualWidth, desiredCenterWidth), centerHalfRoom * 2)
        )
        let centerLeft = usableBounds.midpoint - centerInteractionWidth / 2
        let centerRight = usableBounds.midpoint + centerInteractionWidth / 2

        return {
            leftRight: centerLeft,
            centerLeft: centerLeft,
            centerRight: centerRight,
            rightLeft: centerRight,
            leftVisualRight: Math.min(desiredLeftRight, centerLeft),
            rightVisualLeft: Math.max(desiredRightLeft, centerRight)
        }
    }

    function _resolveVisualPlacement(sectionName, usableBounds, contentWidths) {
        let contentWidth = contentWidths[sectionName] || 0

        if (sectionName === "center") {
            let visualLeft = usableBounds.midpoint - contentWidth / 2

            return {
                left: Math.max(usableBounds.left, Math.min(usableBounds.right - contentWidth, visualLeft)),
                width: contentWidth,
                centerX: usableBounds.midpoint
            }
        }

        if (sectionName === "right") {
            let visualLeft = Math.max(usableBounds.left, usableBounds.right - contentWidth)

            return {
                left: visualLeft,
                width: contentWidth,
                centerX: visualLeft + contentWidth / 2
            }
        }

        return {
            left: usableBounds.left,
            width: contentWidth,
            centerX: usableBounds.left + contentWidth / 2
        }
    }

    function _sectionGeometryWithVisual(sectionName, left, right, contentWidth, slotCount, visualPlacement) {
        let geometry = _clampedSectionGeometry(sectionName, left, right, contentWidth, slotCount)

        geometry.visualLeft = Math.max(0, Number(visualPlacement.left) || 0)
        geometry.visualWidth = Math.max(0, Number(visualPlacement.width) || 0)
        geometry.visualCenterX = Number(visualPlacement.centerX) || 0

        return geometry
    }

    function _pickerAnchorsFromSections(sectionNames, sectionGeometries) {
        let nextPickerAnchors = {}

        for (let i = 0; i < sectionNames.length; i++) {
            let sectionName = sectionNames[i]
            let geometry = sectionGeometries[sectionName]

            nextPickerAnchors[sectionName] = {
                section: sectionName,
                centerX: geometry.centerX,
                leftMargin: _clampPickerLeftMargin(geometry.centerX),
                active: sectionName === widgetPickerTargetSection
            }
        }

        return nextPickerAnchors
    }

    function _slotGeometriesFromSections(sectionNames, sectionGeometries, orderedWidgetsBySection) {
        let nextSlotGeometries = {}

        for (let i = 0; i < sectionNames.length; i++) {
            let sectionName = sectionNames[i]
            nextSlotGeometries[sectionName] = _slotGeometryOutput(
                sectionName,
                sectionGeometries[sectionName].visualLeft,
                orderedWidgetsBySection[sectionName]
            )
        }

        return nextSlotGeometries
    }

    function _clampPickerLeftMargin(centerX) {
        let minLeft = _barContentPadding
        let maxLeft = Math.max(minLeft, _barContentWidth - _pickerPanelWidth - _barContentPadding)
        let idealLeft = (Number(centerX) || 0) - _pickerPanelWidth / 2

        return Math.max(minLeft, Math.min(maxLeft, idealLeft))
    }

    function _recomputeGeometryContracts() {
        _cleanupStaleGeometryState()

        let sections = ["left", "center", "right"]
        let usableBounds = _barUsableBounds()
        let orderedWidgetsBySection = _orderedWidgetsBySection(sections)
        let contentWidths = _contentWidthsBySection(orderedWidgetsBySection, sections)
        let adaptiveBounds = _resolveAdaptiveSectionBounds(usableBounds, contentWidths)
        let nextSectionGeometries = {
            left: _sectionGeometryWithVisual(
                "left",
                usableBounds.left,
                adaptiveBounds.leftRight,
                contentWidths.left || 0,
                orderedWidgetsBySection.left.length,
                _resolveVisualPlacement("left", usableBounds, contentWidths)
            ),
            center: _sectionGeometryWithVisual(
                "center",
                adaptiveBounds.centerLeft,
                adaptiveBounds.centerRight,
                contentWidths.center || 0,
                orderedWidgetsBySection.center.length,
                _resolveVisualPlacement("center", usableBounds, contentWidths)
            ),
            right: _sectionGeometryWithVisual(
                "right",
                adaptiveBounds.rightLeft,
                usableBounds.right,
                contentWidths.right || 0,
                orderedWidgetsBySection.right.length,
                _resolveVisualPlacement("right", usableBounds, contentWidths)
            )
        }
        let nextSlotGeometries = _slotGeometriesFromSections(
            sections,
            nextSectionGeometries,
            orderedWidgetsBySection
        )
        let nextPickerAnchors = _pickerAnchorsFromSections(sections, nextSectionGeometries)
        let nextArrivalGeometries = Object.assign({}, _arrivalGeometries)

        for (let instanceKey in nextArrivalGeometries) {
            let snapshot = nextArrivalGeometries[instanceKey]
            if (!snapshot || snapshot.active !== true || !snapshot.section) {
                continue
            }

            let sectionSlots = nextSlotGeometries[snapshot.section]
            if (!Array.isArray(sectionSlots)) {
                continue
            }

            for (let i = 0; i < sectionSlots.length; i++) {
                if (sectionSlots[i].instanceKey !== instanceKey) {
                    continue
                }

                nextArrivalGeometries[instanceKey] = Object.assign({}, snapshot, {
                    barLeft: sectionSlots[i].left,
                    barWidth: sectionSlots[i].width,
                    barRight: sectionSlots[i].right,
                    barCenterX: sectionSlots[i].centerX
                })
                break
            }
        }

        _sectionGeometries = nextSectionGeometries
        _slotGeometries = nextSlotGeometries
        _pickerAnchors = nextPickerAnchors
        _arrivalGeometries = nextArrivalGeometries
        geometryArrivals = nextArrivalGeometries
    }

    function closeWidgetSettings() {
        let shouldExitLayout = widgetSettingsAutoEnteredLayout

        widgetSettingsPanelOpen = false
        activeWidgetInstanceKey = ""
        widgetSettingsAutoEnteredLayout = false

        if (shouldExitLayout) {
            activePanel = "none"
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
        // Try loading from hot-reload state first, then from disk
        if (persist.layoutJson !== "") {
            applyJson(persist.layoutJson);
        } else {
            fileReader.running = true;
        }

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
        let arr = [];
        for (let i = 0; i < layoutModel.count; i++) {
            let item = layoutModel.get(i);
            arr.push({
                id: item.id, section: item.section,
                alignment: item.alignment, order: item.order,
                enabled: item.enabled,
                instanceKey: item.instanceKey || ""
            });
        }
        return JSON.stringify(arr);
    }

    function applyJson(json) {
        try {
            let arr = JSON.parse(json);
            if (!Array.isArray(arr) || arr.length === 0) {
                resetLayout();
                return;
            }
            _arrivalGeometries = ({})
            _arrivalRevealLocks = ({})
            layoutModel.clear();
            for (let i = 0; i < arr.length; i++)
                layoutModel.append(arr[i]);
            _ensureLayoutInstanceKeys();
            _recomputeGeometryContracts();
            layoutChanged();
        } catch (e) {
            console.log("BarLayoutService: failed to parse layout JSON:", e);
            resetLayout();
        }
    }

    function saveLayout() {
        let json = serializeLayout();
        persist.layoutJson = json;
        // Write to disk
        fileWriter.running = false;
        fileWriter.running = true;
        fileWriter.write(json + "\n");
    }

    function moveWidget(instanceKey, toSection, toAlignment, toOrder) {

        let currentSection = "";
        let currentAlignment = "";
        let currentOrder = -1;
        for (let i = 0; i < layoutModel.count; i++) {
            let item = layoutModel.get(i);
            if (root.instanceKeyAt(i) === instanceKey) {
                currentSection = item.section;
                currentAlignment = item.alignment;
                currentOrder = item.order;
                break;
            }
        }

        if (currentOrder >= 0 && currentSection === toSection && currentOrder === toOrder) {
            return;
        }

        // Collect all widgets in target section (excluding the moving one)
        let others = [];
        let movingIdx = -1;
        for (let i = 0; i < layoutModel.count; i++) {
            let item = layoutModel.get(i);
            if (root.instanceKeyAt(i) === instanceKey) {
                movingIdx = i;
                continue;
            }
            if (item.section === toSection) {
                others.push({ modelIndex: i, order: item.order });
            }
        }
        if (movingIdx < 0) return;

        // Sort by current order
        others.sort(function(a, b) { return a.order - b.order; });

        // Insert the moving widget at the desired position
        let insertAt = Math.min(toOrder, others.length);
        others.splice(insertAt, 0, { modelIndex: movingIdx, order: -1 });

        // Reassign sequential orders and update section/alignment
        for (let i = 0; i < others.length; i++) {
            let mi = others[i].modelIndex;
            layoutModel.setProperty(mi, "order", i);
            if (mi === movingIdx) {
                layoutModel.setProperty(mi, "section", toSection);
                layoutModel.setProperty(mi, "alignment", toAlignment);
            }
        }
        _recomputeGeometryContracts();
        layoutChanged();
        saveLayout();
    }

    // Returns true if the widget already occupies the given slot
    // including alignment. Used to suppress no-op reorders.
    function isSamePlacement(instanceKey, sectionName, order, alignment) {
        for (let i = 0; i < layoutModel.count; i++) {
            let item = layoutModel.get(i);
            if (root.instanceKeyAt(i) === instanceKey)
                return item.section === sectionName && item.order === order && item.alignment === alignment;
        }
        return false;
    }

    // Returns the stable instance key for the widget at layoutModel[modelIndex].
    // Key format: "{widgetId}_{n}" where n counts how many prior entries share the same widgetId.
    function instanceKeyAt(modelIndex) {
        if (modelIndex < 0 || modelIndex >= layoutModel.count) return "";
        let targetId = layoutModel.get(modelIndex).id;
        let n = 0;
        for (let i = 0; i < modelIndex; i++) {
            if (layoutModel.get(i).id === targetId) n++;
        }
        let storedKey = layoutModel.get(modelIndex).instanceKey
        if (storedKey)
            return storedKey;
        return targetId + "_" + n;
    }

    function resetLayout() {
        _arrivalGeometries = ({})
        _arrivalRevealLocks = ({})
        layoutModel.clear();
        for (let i = 0; i < defaultLayout.length; i++) {
            layoutModel.append(defaultLayout[i]);
        }

        _ensureLayoutInstanceKeys()
        _recomputeGeometryContracts()
        layoutChanged()
    }

    // Inserts a new widget instance at the end of the given section.
    function addWidget(widgetId, section) {
        let maxOrder = -1;
        for (let i = 0; i < layoutModel.count; i++) {
            let item = layoutModel.get(i);
            if (item.section === section && item.order > maxOrder)
                maxOrder = item.order;
        }
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
            let slots = sectionSlots(section)
            for (let i = 0; i < slots.length; i++) {
                if (slots[i].instanceKey !== instanceKey) {
                    continue
                }

                let nextArrivalGeometries = Object.assign({}, _arrivalGeometries)
                nextArrivalGeometries[instanceKey] = {
                    active: true,
                    instanceKey: instanceKey,
                    widgetId: widgetId,
                    section: section,
                    barLeft: slots[i].left,
                    barWidth: slots[i].width,
                    barRight: slots[i].right,
                    barCenterX: slots[i].centerX,
                    phase: "overlay",
                    readyForDelegate: false
                }
                _arrivalGeometries = nextArrivalGeometries
                break
            }
        }

        layoutChanged();
        saveLayout();
    }

    // Removes the widget instance identified by instanceKey from the layout model.
    // instanceKey must match what instanceKeyAt() would return for that entry.
    function removeWidget(instanceKey) {
        for (let i = 0; i < layoutModel.count; i++) {
            if (instanceKeyAt(i) === instanceKey) {
                clearArrivalGeometry(instanceKey)
                layoutModel.remove(i);
                if (activeWidgetInstanceKey === instanceKey) {
                    closeWidgetSettings();
                }
                _recomputeGeometryContracts();
                layoutChanged();
                saveLayout();
                return;
            }
        }
        console.warn("BarLayoutService: removeWidget called with unknown key:", instanceKey);
    }
}
