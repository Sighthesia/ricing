.pragma library

function insertionIndexForPointer(pointerX, slots) {
    for (var i = 0; i < slots.length; i++) {
        if (pointerX < slots[i].centerX)
            return i
    }

    return slots.length
}

function insertionIndicatorGeometry(sectionName, index, boundaryX, sectionLeft) {
    return {
        section: sectionName,
        index: index,
        sectionLocalX: boundaryX - sectionLeft,
        barX: boundaryX,
        visible: index >= 0
    }
}

function dragTargetForVisualCenter(visualCenterX, sectionName, sectionGeometry, insertionIndex) {
    return {
        section: sectionName,
        index: insertionIndex,
        pointerX: Math.max(0, Number(visualCenterX) || 0),
        localX: Math.max(0, Number(visualCenterX) || 0) - sectionGeometry.left
    }
}

function beginDragState(instanceKey, widgetId, frozenWidth, visualCenterX) {
    var centerX = Math.max(0, Number(visualCenterX) || 0)

    return {
        active: true,
        instanceKey: instanceKey,
        widgetId: widgetId,
        draggedWidth: frozenWidth,
        dragVisualCenterX: centerX,
        dragVisualX: centerX - frozenWidth / 2
    }
}

function updateDragVisualState(draggedWidth, visualCenterX, sectionName, insertionIndex) {
    var centerX = Math.max(0, Number(visualCenterX) || 0)

    return {
        dragVisualCenterX: centerX,
        dragVisualX: centerX - draggedWidth / 2,
        dragHoverZone: sectionName,
        ghostSection: sectionName,
        ghostIndex: insertionIndex
    }
}

function endDragResult(isDragging, ghostSection, ghostIndex, draggedInstanceKey, draggedWidgetId, draggedWidth) {
    return {
        active: isDragging,
        section: ghostSection,
        index: ghostIndex,
        instanceKey: draggedInstanceKey,
        widgetId: draggedWidgetId,
        draggedWidth: draggedWidth,
        samePlacement: false,
        moved: false
    }
}
