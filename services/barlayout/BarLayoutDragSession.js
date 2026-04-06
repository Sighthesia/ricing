.pragma library

.import "BarLayoutGeometry.js" as GeometryUtils
.import "BarLayoutDrag.js" as DragUtils

function defaultState() {
    return {
        isDragging: false,
        dragHoverZone: "",
        draggedWidgetId: "",
        draggedInstanceKey: "",
        dragVisualX: 0,
        dragVisualCenterX: 0,
        draggedWidth: 0,
        ghostSection: "",
        ghostIndex: -1
    }
}

function beginDrag(state, instanceKey, widgetId, visualCenterX, effectiveMeasuredWidthFn) {
    if (!instanceKey || !widgetId)
        return { changed: false, state: state }

    var frozenWidth = effectiveMeasuredWidthFn(instanceKey)
    var beginState = DragUtils.beginDragState(instanceKey, widgetId, frozenWidth, visualCenterX)

    return {
        changed: true,
        state: Object.assign({}, state, {
            draggedInstanceKey: beginState.instanceKey,
            draggedWidgetId: beginState.widgetId,
            draggedWidth: beginState.draggedWidth,
            isDragging: beginState.active,
            dragVisualCenterX: beginState.dragVisualCenterX,
            dragVisualX: beginState.dragVisualX
        })
    }
}

function updateDrag(state, visualCenterX, dragTargetAtXFn) {
    if (!state.isDragging || !state.draggedInstanceKey)
        return { changed: false, state: state }

    var nextCenterX = Math.max(0, Number(visualCenterX) || 0)
    var dragTarget = dragTargetAtXFn(nextCenterX, state.draggedInstanceKey)
    var visualState = DragUtils.updateDragVisualState(
        state.draggedWidth,
        nextCenterX,
        dragTarget.section,
        dragTarget.index
    )

    return {
        changed: true,
        state: Object.assign({}, state, {
            dragVisualCenterX: visualState.dragVisualCenterX,
            dragVisualX: visualState.dragVisualX,
            dragHoverZone: visualState.dragHoverZone,
            ghostSection: visualState.ghostSection,
            ghostIndex: visualState.ghostIndex
        })
    }
}

function finalizeDrag(state, alignment, isSamePlacementFn, moveWidgetFn) {
    var targetAlignment = alignment || "left"
    var finalTarget = DragUtils.endDragResult(
        state.isDragging,
        state.ghostSection,
        state.ghostIndex,
        state.draggedInstanceKey,
        state.draggedWidgetId,
        state.draggedWidth
    )

    if (finalTarget.active && finalTarget.instanceKey) {
        finalTarget.samePlacement = finalTarget.section !== ""
            && isSamePlacementFn(
                finalTarget.instanceKey,
                finalTarget.section,
                finalTarget.index,
                targetAlignment
            )

        if (finalTarget.section !== "" && !finalTarget.samePlacement) {
            moveWidgetFn(finalTarget.instanceKey, finalTarget.section, targetAlignment, finalTarget.index)
            finalTarget.moved = true
        }
    }

    return {
        finalTarget: finalTarget,
        state: defaultState()
    }
}

function sectionForBarX(barX, sectionGeometryFn) {
    var leftGeometry = sectionGeometryFn("left")
    var centerGeometry = sectionGeometryFn("center")
    var rightGeometry = sectionGeometryFn("right")

    return GeometryUtils.sectionForBarX(barX, leftGeometry, centerGeometry, rightGeometry)
}

function insertionIndexForSectionX(sectionName, localX, excludeInstanceKey, sectionGeometryFn, insertionSlotsFn) {
    var geometry = sectionGeometryFn(sectionName)
    var pointerX = GeometryUtils.pointerBarXForSection(geometry.left, localX)
    var slots = insertionSlotsFn(sectionName, excludeInstanceKey)
    return DragUtils.insertionIndexForPointer(pointerX, slots)
}

function insertionIndicatorGeometry(sectionName, insertionIndex, excludeInstanceKey, sectionGeometryFn, insertionSlotsFn) {
    var geometry = sectionGeometryFn(sectionName)
    var slots = insertionSlotsFn(sectionName, excludeInstanceKey)
    var index = Math.max(0, Number(insertionIndex) || 0)
    var boundaryX = GeometryUtils.insertionBoundaryBarX(geometry.visualLeft, slots, index)
    return DragUtils.insertionIndicatorGeometry(sectionName, index, boundaryX, geometry.left)
}

function dragTargetAtX(visualCenterX, excludeInstanceKey, sectionGeometryFn, insertionSlotsFn) {
    var pointerX = Math.max(0, Number(visualCenterX) || 0)
    var sectionName = sectionForBarX(pointerX, sectionGeometryFn)
    var geometry = sectionGeometryFn(sectionName)
    var localX = pointerX - geometry.left
    var insertionIndex = insertionIndexForSectionX(
        sectionName,
        localX,
        excludeInstanceKey,
        sectionGeometryFn,
        insertionSlotsFn
    )

    return DragUtils.dragTargetForVisualCenter(visualCenterX, sectionName, geometry, insertionIndex)
}
