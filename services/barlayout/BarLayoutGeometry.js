.pragma library

function emptySectionGeometry(sectionName) {
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

function emptyPickerAnchor(sectionName) {
    return {
        section: sectionName,
        centerX: 0,
        leftMargin: 0,
        active: false
    }
}

function sectionForBarX(barX, leftGeometry, centerGeometry, rightGeometry) {
    if (barX < centerGeometry.left)
        return "left"

    if (barX <= centerGeometry.right)
        return "center"

    if (barX <= rightGeometry.right || rightGeometry.width <= 0)
        return "right"

    return barX < leftGeometry.left ? "left" : "right"
}

function pointerBarXForSection(sectionLeft, localX) {
    return sectionLeft + Math.max(0, Number(localX) || 0)
}

function insertionBoundaryBarX(visualLeft, slots, insertionIndex) {
    if (!Array.isArray(slots) || slots.length <= 0)
        return visualLeft

    if (insertionIndex <= 0)
        return slots[0].left

    if (insertionIndex >= slots.length)
        return slots[slots.length - 1].right

    return slots[insertionIndex].left
}

function slotGeometryRecord(sectionName, widget, slotIndex, left, width) {
    return {
        id: widget.id,
        instanceKey: widget.instanceKey,
        section: sectionName,
        order: widget.order,
        alignment: widget.alignment,
        slotIndex: slotIndex,
        measuredWidth: widget.measuredWidth,
        left: left,
        width: width,
        right: left + width,
        centerX: left + width / 2
    }
}

function widgetGeometryFromSlot(sectionName, slot) {
    return {
        widgetId: slot.id,
        instanceKey: slot.instanceKey,
        section: sectionName,
        left: slot.left,
        right: slot.right,
        width: slot.width,
        centerX: slot.centerX,
        slotIndex: slot.slotIndex,
        order: slot.order
    }
}

function clampedSectionGeometry(sectionName, left, right, contentWidth, slotCount) {
    var nextLeft = Number(left) || 0
    var nextRight = Number(right) || 0

    if (nextRight < nextLeft)
        nextRight = nextLeft

    var width = Math.max(0, nextRight - nextLeft)
    var visualWidth = Math.max(0, Number(contentWidth) || 0)

    return {
        section: sectionName,
        left: nextLeft,
        right: nextRight,
        width: width,
        centerX: nextLeft + width / 2,
        visualLeft: nextLeft,
        visualWidth: visualWidth,
        visualCenterX: nextLeft + visualWidth / 2,
        slotCount: slotCount,
        contentWidth: visualWidth
    }
}

function clampPickerLeftMargin(centerX, barContentPadding, barContentWidth, pickerPanelWidth) {
    var minLeft = barContentPadding
    var maxLeft = Math.max(minLeft, barContentWidth - pickerPanelWidth - barContentPadding)
    var idealLeft = (Number(centerX) || 0) - pickerPanelWidth / 2

    return Math.max(minLeft, Math.min(maxLeft, idealLeft))
}
