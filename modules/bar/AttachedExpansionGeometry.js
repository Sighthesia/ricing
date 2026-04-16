.pragma library

function metrics(root, effectiveShellRadius) {
    var minRadius = 0.01
    var pillLeft = (root.width - root.pillWidth) / 2
    var pillRight = pillLeft + root.pillWidth
    var pillRadius = Math.max(minRadius, root.pillHeight / 2)
    var panelLeft = 0.5
    var panelRight = root.width - 0.5
    var panelTop = Math.max(root.pillHeight, root.panelY - root.y + root.attachmentOverlap)
    var panelBottom = root.height - 0.5
    var panelRadius = Math.max(minRadius, Math.min(effectiveShellRadius, Math.max(1, (panelBottom - panelTop) / 2)))
    var availableCornerHeight = Math.max(minRadius, panelTop - root.pillHeight)
    var neckRight = Math.max(pillRight, Math.min(panelRight - panelRadius - minRadius, pillRight + root.bridgeOutset))
    var neckLeft = Math.min(pillLeft, Math.max(panelLeft + panelRadius + minRadius, pillLeft - root.bridgeOutset))
    var cornerHorizontalSpan = Math.max(
        minRadius,
        Math.min(panelRight - panelRadius - neckRight, neckLeft - (panelLeft + panelRadius))
    )
    var cornerRadiusTarget = Math.max(minRadius, Math.min(root.inwardCornerRadius, availableCornerHeight, cornerHorizontalSpan))
    var cornerRadiusFloor = Math.max(minRadius, Math.min(root.inwardCornerRadius, effectiveShellRadius) * 0.35)
    var cutRadius = cornerRadiusTarget

    if (cornerRadiusTarget < cornerRadiusFloor
            && availableCornerHeight >= cornerRadiusFloor
            && cornerHorizontalSpan >= cornerRadiusFloor) {
        cutRadius = cornerRadiusFloor
    }

    return {
        minRadius: minRadius,
        pillLeft: pillLeft,
        pillRight: pillRight,
        pillRadius: pillRadius,
        panelLeft: panelLeft,
        panelRight: panelRight,
        panelTop: panelTop,
        panelBottom: panelBottom,
        panelRadius: panelRadius,
        availableCornerHeight: availableCornerHeight,
        neckRight: neckRight,
        neckLeft: neckLeft,
        cornerHorizontalSpan: cornerHorizontalSpan,
        cutRadius: cutRadius,
        cornerStartY: panelTop - cutRadius,
        rightShoulderX: neckRight + cutRadius,
        leftShoulderX: neckLeft - cutRadius
    }
}
