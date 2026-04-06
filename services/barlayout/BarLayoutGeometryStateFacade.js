.pragma library

.import "BarLayoutArrivalSession.js" as ArrivalSessionUtils
.import "BarLayoutGeometryPipeline.js" as GeometryPipelineUtils

function arrivalState(root) {
    return {
        arrivalGeometries: root._arrivalGeometries,
        arrivalRevealLocks: root._arrivalRevealLocks
    }
}

function applyArrivalState(root, nextState) {
    root._arrivalGeometries = nextState.arrivalGeometries
    root._arrivalRevealLocks = nextState.arrivalRevealLocks
}

function resetArrivalState(root) {
    applyArrivalState(root, ArrivalSessionUtils.resetState())
}

function clearArrivalGeometry(root, instanceKey) {
    var result = ArrivalSessionUtils.clear(arrivalState(root), instanceKey)
    if (!result.changed)
        return false

    applyArrivalState(root, result.state)
    return true
}

function completeArrivalGeometry(root, instanceKey) {
    return clearArrivalGeometry(root, instanceKey)
}

function requestArrivalReveal(root, instanceKey, sectionSlotsFn) {
    var result = ArrivalSessionUtils.requestReveal(arrivalState(root), instanceKey, sectionSlotsFn)
    if (!result.changed)
        return false

    applyArrivalState(root, result.state)
    return true
}

function finishArrivalReveal(root, instanceKey, sectionSlotsFn) {
    var result = ArrivalSessionUtils.finishReveal(arrivalState(root), instanceKey, sectionSlotsFn)
    if (!result.changed)
        return false

    applyArrivalState(root, result.state)
    return true
}

function applyGeometrySnapshot(root, snapshot) {
    root._sectionGeometries = snapshot.sectionGeometries
    root._slotGeometries = snapshot.slotGeometries
    root._widgetGeometries = snapshot.widgetGeometries
    root._superIslandInstanceKey = snapshot.superIslandInstanceKey
    root._pickerAnchors = snapshot.pickerAnchors
    root._arrivalGeometries = snapshot.arrivalGeometries
    root.geometryArrivals = snapshot.arrivalGeometries
}

function cleanupStaleGeometryState(root, layoutModel, instanceKeyAtFn) {
    var cleanupResult = GeometryPipelineUtils.cleanupStaleGeometryState(
        layoutModel,
        instanceKeyAtFn,
        root._widgetMeasuredWidths,
        root._widgetMeasurementMetadata,
        root._arrivalGeometries,
        root._arrivalRevealLocks,
        root.draggedInstanceKey
    )

    if (cleanupResult.changed) {
        root._widgetMeasuredWidths = cleanupResult.widgetMeasuredWidths
        root._widgetMeasurementMetadata = cleanupResult.widgetMeasurementMetadata
        root._arrivalGeometries = cleanupResult.arrivalGeometries
        root._arrivalRevealLocks = cleanupResult.arrivalRevealLocks
    }

    return cleanupResult
}

function recomputeGeometryContracts(root, options) {
    var cleanupResult = cleanupStaleGeometryState(root, options.layoutModel, options.instanceKeyAtFn)

    if (cleanupResult.clearDragState)
        options.clearDragStateFn()

    applyGeometrySnapshot(root, GeometryPipelineUtils.recomputeGeometryContracts({
        layoutModel: options.layoutModel,
        instanceKeyAtFn: options.instanceKeyAtFn,
        effectiveMeasuredWidthFn: options.effectiveMeasuredWidthFn,
        arrivalGeometries: root._arrivalGeometries,
        widgetPickerTargetSection: root.widgetPickerTargetSection,
        barContentWidth: root._barContentWidth,
        barContentPadding: root._barContentPadding,
        pickerPanelWidth: options.pickerPanelWidth
    }))
}
