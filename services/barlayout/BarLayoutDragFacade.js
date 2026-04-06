.pragma library

.import "BarLayoutDragSession.js" as DragSessionUtils
.import "BarLayoutStateSync.js" as StateSyncUtils

function dragState(root) {
    return StateSyncUtils.dragStateSnapshot(root)
}

function applyDragState(root, nextState) {
    StateSyncUtils.applyDragState(root, nextState)
}

function insertionIndexForSectionX(sectionName, localX, excludeInstanceKey, sectionGeometryFn, insertionSlotsFn) {
    return DragSessionUtils.insertionIndexForSectionX(
        sectionName,
        localX,
        excludeInstanceKey,
        sectionGeometryFn,
        insertionSlotsFn
    )
}

function insertionIndicatorGeometry(sectionName, insertionIndex, excludeInstanceKey, sectionGeometryFn, insertionSlotsFn) {
    return DragSessionUtils.insertionIndicatorGeometry(
        sectionName,
        insertionIndex,
        excludeInstanceKey,
        sectionGeometryFn,
        insertionSlotsFn
    )
}

function dragTargetAtX(visualCenterX, excludeInstanceKey, sectionGeometryFn, insertionSlotsFn) {
    return DragSessionUtils.dragTargetAtX(
        visualCenterX,
        excludeInstanceKey,
        sectionGeometryFn,
        insertionSlotsFn
    )
}

function sectionForBarX(barX, sectionGeometryFn) {
    return DragSessionUtils.sectionForBarX(barX, sectionGeometryFn)
}

function beginDrag(root, instanceKey, widgetId, visualCenterX, effectiveMeasuredWidthFn, updateDragFn) {
    var beginResult = DragSessionUtils.beginDrag(
        dragState(root),
        instanceKey,
        widgetId,
        visualCenterX,
        effectiveMeasuredWidthFn
    )

    if (!beginResult.changed)
        return root.dragSnapshot

    applyDragState(root, beginResult.state)
    return updateDragFn(visualCenterX)
}

function updateDrag(root, visualCenterX, dragTargetAtXFn) {
    var updateResult = DragSessionUtils.updateDrag(dragState(root), visualCenterX, dragTargetAtXFn)
    if (!updateResult.changed)
        return root.dragSnapshot

    applyDragState(root, updateResult.state)
    return root.dragSnapshot
}

function endDrag(root, alignment, isSamePlacementFn, moveWidgetFn) {
    var result = DragSessionUtils.finalizeDrag(dragState(root), alignment, isSamePlacementFn, moveWidgetFn)
    applyDragState(root, result.state)
    return result.finalTarget
}

function clearDragState(root) {
    applyDragState(root, DragSessionUtils.defaultState())
}
