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

function resolveAdaptiveSectionBounds(usableBounds, contentWidths) {
    var desiredLeftRight = Math.min(usableBounds.right, usableBounds.left + (contentWidths.left || 0))
    var desiredRightLeft = Math.max(usableBounds.left, usableBounds.right - (contentWidths.right || 0))
    var centerHalfRoom = Math.min(
        Math.max(0, usableBounds.midpoint - desiredLeftRight),
        Math.max(0, desiredRightLeft - usableBounds.midpoint)
    )
    var centerVisualWidth = Math.max(0, contentWidths.center || 0)
    var centerOwnsExclusiveWidth = centerVisualWidth > centerHalfRoom * 2
    var centerInteractionWidth = centerOwnsExclusiveWidth
        ? centerVisualWidth
        : Math.max(0, Math.min(centerVisualWidth, centerHalfRoom * 2))
    var centerLeft = usableBounds.midpoint - centerInteractionWidth / 2
    var centerRight = usableBounds.midpoint + centerInteractionWidth / 2

    return {
        leftRight: centerLeft,
        centerLeft: centerLeft,
        centerRight: centerRight,
        rightLeft: centerRight,
        leftVisualRight: centerOwnsExclusiveWidth ? centerLeft : Math.min(desiredLeftRight, centerLeft),
        rightVisualLeft: centerOwnsExclusiveWidth ? centerRight : Math.max(desiredRightLeft, centerRight),
        centerOwnsExclusiveWidth: centerOwnsExclusiveWidth
    }
}

function resolveVisualPlacement(sectionName, usableBounds, contentWidths, adaptiveBounds) {
    var contentWidth = Math.max(0, contentWidths[sectionName] || 0)

    if (sectionName === "center") {
        var centerLeftBound = adaptiveBounds ? adaptiveBounds.centerLeft : usableBounds.left
        var centerRightBound = adaptiveBounds ? adaptiveBounds.centerRight : usableBounds.right
        var centerBoundWidth = Math.max(0, centerRightBound - centerLeftBound)
        var centerWidth = adaptiveBounds && adaptiveBounds.centerOwnsExclusiveWidth
            ? contentWidth
            : Math.min(contentWidth, centerBoundWidth)
        var centerVisualLeft = usableBounds.midpoint - centerWidth / 2

        return {
            left: centerVisualLeft,
            width: centerWidth,
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
