// Pure drag math helpers for the bar layout system.
// No QML dependencies — operates on plain arrays and numbers.

// Given a pointer X position and an array of widget center positions,
// return the insertion index (0-based) where a drop should land.
// widgetCenters: [{instanceKey, centerX}] sorted by centerX.
function insertionIndexForPointer(pointerX, widgetCenters) {
    if (!widgetCenters || !widgetCenters.length) {
        return 0
    }

    for (var i = 0; i < widgetCenters.length; i++) {
        if (pointerX < widgetCenters[i].centerX) {
            return i
        }
    }

    return widgetCenters.length
}

// Build the initial drag state when a drag begins.
function beginDragState(instanceKey, widgetId, startCenterX) {
    return {
        active: true,
        instanceKey: instanceKey || "",
        widgetId: widgetId || "",
        visualCenterX: Math.max(0, Number(startCenterX) || 0)
    }
}

// Compute updated ghost position during drag movement.
// sectionBounds: [{name, left, right}] — pixel bounds of each section.
// widgetCentersBySection: {sectionName: [{instanceKey, centerX}]} — excluding dragged widget.
function updateDragState(visualCenterX, sectionBounds, widgetCentersBySection, draggedInstanceKey) {
    var centerX = Math.max(0, Number(visualCenterX) || 0)

    // Determine which section the pointer is over
    var hoverSection = ""
    for (var i = 0; i < sectionBounds.length; i++) {
        var bound = sectionBounds[i]
        if (centerX >= bound.left && centerX <= bound.right) {
            hoverSection = bound.name
            break
        }
    }

    // Fallback: closest section
    if (!hoverSection && sectionBounds.length > 0) {
        var minDist = Infinity
        for (var j = 0; j < sectionBounds.length; j++) {
            var sectionCenter = (sectionBounds[j].left + sectionBounds[j].right) / 2
            var dist = Math.abs(centerX - sectionCenter)
            if (dist < minDist) {
                minDist = dist
                hoverSection = sectionBounds[j].name
            }
        }
    }

    // Compute insertion index within the hover section
    var centers = (widgetCentersBySection && widgetCentersBySection[hoverSection]) || []
    // Exclude the dragged widget from center calculations
    var filteredCenters = centers.filter(function (c) {
        return c.instanceKey !== draggedInstanceKey
    })
    var ghostIndex = insertionIndexForPointer(centerX, filteredCenters)

    return {
        visualCenterX: centerX,
        hoverSection: hoverSection,
        ghostSection: hoverSection,
        ghostIndex: ghostIndex
    }
}

// Produce the final result when a drag ends.
function endDragResult(ghostSection, ghostIndex, draggedInstanceKey) {
    return {
        section: ghostSection || "",
        index: Math.max(0, ghostIndex || 0),
        instanceKey: draggedInstanceKey || ""
    }
}
