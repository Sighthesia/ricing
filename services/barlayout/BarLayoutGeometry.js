.pragma library

function _numberOr(value, fallback) {
    var next = Number(value)
    return isNaN(next) ? fallback : next
}

function emptySectionGeometry(sectionName) {
    return {
        section: sectionName,
        layoutLeft: 0,
        layoutRight: 0,
        layoutWidth: 0,
        visualLeft: 0,
        visualRight: 0,
        visualWidth: 0,
        contentLeft: 0,
        contentRight: 0,
        contentWidth: 0,
        anchorMode: "edge",
        alignmentMode: "left",
        fixedEdge: "left",
        driftPolicy: "pinned",
        driftMinX: 0,
        driftMaxX: 0,
        pushOffsetX: 0,
        pushTargetOffsetX: 0,
        pushSource: "",
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
    if (barX < _numberOr(centerGeometry.visualLeft, centerGeometry.left))
        return "left"

    if (barX <= _numberOr(centerGeometry.visualRight, centerGeometry.right))
        return "center"

    if (barX <= _numberOr(rightGeometry.visualRight, rightGeometry.right) || _numberOr(rightGeometry.visualWidth, rightGeometry.width) <= 0)
        return "right"

    return barX < _numberOr(leftGeometry.visualLeft, leftGeometry.left) ? "left" : "right"
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

function slotGeometryRecord(sectionName, widget, slotIndex, left, width, sectionGeometry) {
    var nextBaseLeft = _numberOr(left, 0)
    var nextWidth = Math.max(0, _numberOr(width, 0))
    var nextSectionGeometry = sectionGeometry || emptySectionGeometry(sectionName)
    var layoutLeft = _numberOr(nextSectionGeometry.layoutLeft, 0)
    var pushOffsetX = _numberOr(nextSectionGeometry.pushOffsetX, 0)
    var baseRight = nextBaseLeft + nextWidth
    var baseCenterX = nextBaseLeft + nextWidth / 2
    var localLeft = nextBaseLeft - layoutLeft
    var localRight = localLeft + nextWidth
    var localCenterX = localLeft + nextWidth / 2
    var visualLeft = nextBaseLeft + pushOffsetX
    var visualRight = visualLeft + nextWidth
    var visualCenterX = visualLeft + nextWidth / 2

    return {
        id: widget.id,
        instanceKey: widget.instanceKey,
        section: sectionName,
        order: widget.order,
        alignment: widget.alignment,
        alignmentMode: widget.alignment || "left",
        slotIndex: slotIndex,
        measuredWidth: widget.measuredWidth,
        baseLeft: nextBaseLeft,
        baseRight: baseRight,
        baseCenterX: baseCenterX,
        localLeft: localLeft,
        localRight: localRight,
        localCenterX: localCenterX,
        sectionPushOffsetX: pushOffsetX,
        visualLeft: visualLeft,
        visualRight: visualRight,
        visualCenterX: visualCenterX,
        left: visualLeft,
        right: visualRight,
        width: nextWidth,
        centerX: visualCenterX
    }
}

function widgetGeometryFromSlot(sectionName, slot) {
    var width = Math.max(0, _numberOr(slot.width, 0))
    return {
        widgetId: slot.id,
        instanceKey: slot.instanceKey,
        section: sectionName,
        alignmentMode: slot.alignmentMode || slot.alignment || "left",
        baseLeft: _numberOr(slot.baseLeft, 0),
        baseRight: _numberOr(slot.baseRight, 0),
        baseCenterX: _numberOr(slot.baseCenterX, 0),
        localLeft: _numberOr(slot.localLeft, 0),
        localRight: _numberOr(slot.localRight, 0),
        localCenterX: _numberOr(slot.localCenterX, 0),
        sectionPushOffsetX: _numberOr(slot.sectionPushOffsetX, 0),
        visualLeft: _numberOr(slot.visualLeft, 0),
        visualRight: _numberOr(slot.visualRight, 0),
        visualCenterX: _numberOr(slot.visualCenterX, 0),
        left: _numberOr(slot.visualLeft, 0),
        right: _numberOr(slot.visualRight, 0),
        width: width,
        centerX: _numberOr(slot.visualCenterX, 0),
        slotIndex: slot.slotIndex,
        order: slot.order
    }
}

function clampedSectionGeometry(sectionName, left, right, contentWidth, slotCount, contract) {
    var nextLayoutLeft = contract && contract.layoutLeft !== undefined ? _numberOr(contract.layoutLeft, 0) : _numberOr(left, 0)
    var nextLayoutRight = contract && contract.layoutRight !== undefined ? _numberOr(contract.layoutRight, nextLayoutLeft) : _numberOr(right, nextLayoutLeft)

    if (nextLayoutRight < nextLayoutLeft)
        nextLayoutRight = nextLayoutLeft

    var layoutWidth = Math.max(0, nextLayoutRight - nextLayoutLeft)
    var visualLeft = contract && contract.visualLeft !== undefined ? _numberOr(contract.visualLeft, nextLayoutLeft) : nextLayoutLeft
    var visualRight = contract && contract.visualRight !== undefined ? _numberOr(contract.visualRight, visualLeft + layoutWidth) : visualLeft + layoutWidth
    var visualWidth = Math.max(0, visualRight - visualLeft)
    var contentLeft = contract && contract.contentLeft !== undefined ? _numberOr(contract.contentLeft, visualLeft) : visualLeft
    var contentRight = contract && contract.contentRight !== undefined ? _numberOr(contract.contentRight, visualRight) : visualRight
    var contentWidthValue = contract && contract.contentWidth !== undefined
        ? Math.max(0, _numberOr(contract.contentWidth, visualWidth))
        : Math.max(0, _numberOr(contentWidth, visualWidth))
    var alignmentMode = contract && contract.alignmentMode !== undefined
        ? String(contract.alignmentMode || "left")
        : (sectionName === "center" ? "center" : sectionName)
    var anchorMode = contract && contract.anchorMode !== undefined
        ? String(contract.anchorMode || "edge")
        : (sectionName === "center" ? "center" : "edge")
    var fixedEdge = contract && contract.fixedEdge !== undefined
        ? String(contract.fixedEdge || "")
        : (sectionName === "left" ? "left" : (sectionName === "right" ? "right" : "none"))
    var driftPolicy = contract && contract.driftPolicy !== undefined
        ? String(contract.driftPolicy || "pinned")
        : "pinned"
    var driftMinX = contract && contract.driftMinX !== undefined ? _numberOr(contract.driftMinX, visualLeft) : visualLeft
    var driftMaxX = contract && contract.driftMaxX !== undefined ? _numberOr(contract.driftMaxX, visualRight) : visualRight
    var pushOffsetX = contract && contract.pushOffsetX !== undefined ? _numberOr(contract.pushOffsetX, visualLeft - nextLayoutLeft) : visualLeft - nextLayoutLeft
    var pushTargetOffsetX = contract && contract.pushTargetOffsetX !== undefined ? _numberOr(contract.pushTargetOffsetX, pushOffsetX) : pushOffsetX
    var pushSource = contract && contract.pushSource !== undefined ? String(contract.pushSource || "") : ""

    return {
        section: sectionName,
        layoutLeft: nextLayoutLeft,
        layoutRight: nextLayoutRight,
        layoutWidth: layoutWidth,
        visualLeft: visualLeft,
        visualRight: visualRight,
        visualWidth: visualWidth,
        contentLeft: contentLeft,
        contentRight: contentRight,
        contentWidth: contentWidthValue,
        anchorMode: anchorMode,
        alignmentMode: alignmentMode,
        fixedEdge: fixedEdge,
        driftPolicy: driftPolicy,
        driftMinX: driftMinX,
        driftMaxX: driftMaxX,
        pushOffsetX: pushOffsetX,
        pushTargetOffsetX: pushTargetOffsetX,
        pushSource: pushSource,
        left: visualLeft,
        right: visualRight,
        width: visualWidth,
        centerX: visualLeft + visualWidth / 2,
        slotCount: slotCount,
        contentWidth: contentWidthValue
    }
}

function clampPickerLeftMargin(centerX, barContentPadding, barContentWidth, pickerPanelWidth) {
    var minLeft = barContentPadding
    var maxLeft = Math.max(minLeft, barContentWidth - pickerPanelWidth - barContentPadding)
    var idealLeft = (Number(centerX) || 0) - pickerPanelWidth / 2

    return Math.max(minLeft, Math.min(maxLeft, idealLeft))
}
