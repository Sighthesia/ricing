.pragma library

function barUsableBounds(barContentWidth, barContentPadding) {
    var usableLeft = barContentPadding
    var usableRight = Math.max(usableLeft, barContentWidth - barContentPadding)

    return {
        left: usableLeft,
        right: usableRight,
        width: Math.max(0, usableRight - usableLeft),
        midpoint: barContentWidth / 2
    }
}

function sectionGeometryContract(sectionName, usableBounds, contentWidths, adaptiveBounds, visualPlacement) {
    var contentWidth = Math.max(0, contentWidths[sectionName] || 0)
    var alignmentMode = sectionName === "center" ? "center" : sectionName
    var anchorMode = sectionName === "center" ? "center" : "edge"
    var fixedEdge = sectionName === "left"
        ? "left"
        : (sectionName === "right" ? "right" : "none")
    var layoutLeft = sectionName === "center"
        ? adaptiveBounds.centerLeft
        : (sectionName === "right" ? adaptiveBounds.rightLeft : usableBounds.left)
    var layoutRight = sectionName === "center"
        ? adaptiveBounds.centerRight
        : (sectionName === "left" ? adaptiveBounds.leftRight : usableBounds.right)
    var visualLeft = Number(visualPlacement.left) || layoutLeft
    var visualWidth = Math.max(0, Number(visualPlacement.width) || contentWidth)
    var visualRight = visualLeft + visualWidth
    var contentLeft = visualLeft
    var contentRight = visualRight
    var pushOffsetX = visualLeft - layoutLeft
    var centerPushesLeft = !!(adaptiveBounds && adaptiveBounds.centerPushesLeft)
    var centerPushesRight = !!(adaptiveBounds && adaptiveBounds.centerPushesRight)
    var pushedByCenter = (sectionName === "left" && centerPushesLeft)
        || (sectionName === "right" && centerPushesRight)
    var driftPolicy = pushedByCenter ? "push" : "pinned"
    var pushSource = pushedByCenter
        ? (sectionName === "left" ? "center-overlap-left" : "center-overlap-right")
        : ""

    return {
        layoutLeft: layoutLeft,
        layoutRight: layoutRight,
        layoutWidth: Math.max(0, layoutRight - layoutLeft),
        visualLeft: visualLeft,
        visualRight: visualRight,
        visualWidth: visualWidth,
        contentLeft: contentLeft,
        contentRight: contentRight,
        contentWidth: Math.max(0, contentWidth),
        anchorMode: anchorMode,
        alignmentMode: alignmentMode,
        fixedEdge: fixedEdge,
        driftPolicy: driftPolicy,
        driftMinX: layoutLeft,
        driftMaxX: visualLeft,
        pushOffsetX: pushOffsetX,
        pushTargetOffsetX: pushOffsetX,
        pushSource: pushSource,
        layoutReservationWidth: Math.max(0, layoutRight - layoutLeft),
        layoutRevealWidth: visualWidth
    }
}

function resolveAdaptiveSectionBounds(usableBounds, contentWidths) {
    var centerVisualWidth = Math.max(0, contentWidths.center || 0)
    var desiredLeftRight = Math.min(usableBounds.right, usableBounds.left + (contentWidths.left || 0))
    var desiredRightLeft = Math.max(usableBounds.left, usableBounds.right - (contentWidths.right || 0))
    var centerLeft = usableBounds.midpoint - centerVisualWidth / 2
    var centerRight = usableBounds.midpoint + centerVisualWidth / 2
    var leftOverlap = Math.max(0, desiredLeftRight - centerLeft)
    var rightOverlap = Math.max(0, centerRight - desiredRightLeft)
    var collisionEpsilon = 0.5
    var centerPushesLeft = leftOverlap > collisionEpsilon
    var centerPushesRight = rightOverlap > collisionEpsilon

    return {
        leftRight: Math.min(desiredLeftRight, centerLeft),
        centerLeft: centerLeft,
        centerRight: centerRight,
        rightLeft: Math.max(desiredRightLeft, centerRight),
        leftVisualRight: Math.min(desiredLeftRight, centerLeft),
        rightVisualLeft: Math.max(desiredRightLeft, centerRight),
        centerOwnsExclusiveWidth: centerPushesLeft || centerPushesRight,
        centerPushesLeft: centerPushesLeft,
        centerPushesRight: centerPushesRight
    }
}

function resolveVisualPlacement(sectionName, usableBounds, contentWidths, adaptiveBounds) {
    var contentWidth = Math.max(0, contentWidths[sectionName] || 0)

    if (sectionName === "center") {
        var centerVisualLeft = usableBounds.midpoint - contentWidth / 2

        return {
            left: centerVisualLeft,
            width: contentWidth,
            centerX: usableBounds.midpoint
        }
    }

    if (sectionName === "right") {
        var rightLeftBound = adaptiveBounds ? adaptiveBounds.rightVisualLeft : usableBounds.left
        var rightVisualLeft = Math.max(rightLeftBound, usableBounds.right - contentWidth)

        return {
            left: rightVisualLeft,
            width: contentWidth,
            centerX: rightVisualLeft + contentWidth / 2
        }
    }

    var leftRightBound = adaptiveBounds ? adaptiveBounds.leftVisualRight : usableBounds.right
    var leftVisualLeft = Math.min(usableBounds.left, leftRightBound - contentWidth)

    return {
        left: leftVisualLeft,
        width: contentWidth,
        centerX: leftVisualLeft + contentWidth / 2
    }
}

function primaryInstanceKeyForWidget(widgetId, slotGeometries, sectionNames, barContentWidth) {
    if (!widgetId)
        return ""

    var preferredInstanceKey = ""
    var closestDistance = Number.POSITIVE_INFINITY
    var barMidpoint = barContentWidth / 2

    for (var i = 0; i < sectionNames.length; i++) {
        var sectionName = sectionNames[i]
        var slots = slotGeometries[sectionName]

        if (!Array.isArray(slots))
            continue

        for (var slotIndex = 0; slotIndex < slots.length; slotIndex++) {
            if (slots[slotIndex].id !== widgetId)
                continue

            var slotCenterX = Number(slots[slotIndex].centerX) || 0
            var distance = Math.abs(slotCenterX - barMidpoint)

            if (distance < closestDistance) {
                closestDistance = distance
                preferredInstanceKey = slots[slotIndex].instanceKey || ""
            }
        }
    }

    return preferredInstanceKey
}
