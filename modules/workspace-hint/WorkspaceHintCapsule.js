.pragma library

// Compute a shared maximum title width so all cards fit within availableRowWidth.
// Each card keeps its own non-title chrome width; only the title width is capped.
function computeCardTitleWidthCap(titleWidths, baseWidths, availableRowWidth, interCardSpacing) {
    var safeTitleWidths = titleWidths || []
    var safeBaseWidths = baseWidths || []
    var cardCount = Math.min(safeTitleWidths.length, safeBaseWidths.length)
    if (cardCount <= 0 || availableRowWidth <= 0)
        return Infinity

    var spacingTotal = Math.max(0, cardCount - 1) * interCardSpacing
    var baseWidthTotal = 0
    var naturalTitleTotal = 0
    var sortableTitleWidths = []

    for (var index = 0; index < cardCount; index++) {
        var titleWidth = Math.max(0, safeTitleWidths[index] || 0)
        baseWidthTotal += Math.max(0, safeBaseWidths[index] || 0)
        naturalTitleTotal += titleWidth
        sortableTitleWidths.push(titleWidth)
    }

    var availableTitleWidth = availableRowWidth - spacingTotal - baseWidthTotal

    if (availableTitleWidth <= 0)
        return 0

    if (naturalTitleTotal <= availableTitleWidth)
        return Infinity

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
