.pragma library

function computeExpandedPrimaryWidth(maxCapsuleWidth, naturalPrimaryWidth, workspaceAreaMinWidth) {
    var safeMaxWidth = Math.max(1, maxCapsuleWidth || 0)
    var safeNaturalWidth = Math.max(0, naturalPrimaryWidth || 0)
    var safeWorkspaceAreaWidth = Math.max(0, workspaceAreaMinWidth || 0)

    return Math.min(safeMaxWidth, Math.max(safeNaturalWidth, safeWorkspaceAreaWidth))
}

// Compute a maximum title width for NON-FOCUSED cards so the whole row fits
// within availableRowWidth, while the focused card keeps its full natural
// title. focusedIndex selects the card that is exempt from capping (-1 = none).
// Each card keeps its own non-title chrome width; only the title width is capped.
function computeCardTitleWidthCap(titleWidths, baseWidths, availableRowWidth, interCardSpacing, focusedIndex) {
    var safeTitleWidths = titleWidths || []
    var safeBaseWidths = baseWidths || []
    var cardCount = Math.min(safeTitleWidths.length, safeBaseWidths.length)
    if (cardCount <= 0 || availableRowWidth <= 0)
        return Infinity

    var focused = (focusedIndex === undefined) ? -1 : focusedIndex
    var spacingTotal = Math.max(0, cardCount - 1) * interCardSpacing
    var baseWidthTotal = 0
    var naturalTitleTotal = 0
    var focusedTitleWidth = 0
    var sortableTitleWidths = []

    for (var index = 0; index < cardCount; index++) {
        var titleWidth = Math.max(0, safeTitleWidths[index] || 0)
        baseWidthTotal += Math.max(0, safeBaseWidths[index] || 0)
        naturalTitleTotal += titleWidth
        if (index === focused)
            focusedTitleWidth = titleWidth
        else
            sortableTitleWidths.push(titleWidth)
    }

    var availableTitleWidth = availableRowWidth - spacingTotal - baseWidthTotal

    if (availableTitleWidth <= 0)
        return 0

    if (naturalTitleTotal <= availableTitleWidth)
        return Infinity

    // Reserve the focused card's full natural title; non-focused cards share
    // whatever remains. If the focused title alone overflows, non-focused
    // cards collapse to their minimum and the focused one still wins.
    availableTitleWidth -= focusedTitleWidth
    if (availableTitleWidth <= 0)
        return 0

    sortableTitleWidths.sort(function(a, b) {
        return a - b
    })

    for (var sortedIndex = 0; sortedIndex < sortableTitleWidths.length; sortedIndex++) {
        var remainingCount = sortableTitleWidths.length - sortedIndex
        var proposedCap = availableTitleWidth / remainingCount
        if (proposedCap <= sortableTitleWidths[sortedIndex])
            return proposedCap

        availableTitleWidth -= sortableTitleWidths[sortedIndex]
    }

    return sortableTitleWidths.length > 0 ? sortableTitleWidths[sortableTitleWidths.length - 1] : Infinity
}
