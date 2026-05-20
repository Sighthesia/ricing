.pragma library

function buildStepQueue(fromPosition, toPosition) {
    var steps = []
    var dir = toPosition > fromPosition ? 1 : -1
    for (var pos = fromPosition + dir; dir > 0 ? pos <= toPosition : pos >= toPosition; pos += dir) {
        steps.push(pos)
    }
    return steps
}

function opacityForDistance(distance, capsulePitch, fadeDistance) {
    var raw = (fadeDistance - distance * capsulePitch) / (fadeDistance - capsulePitch)
    return Math.max(0, Math.min(1, raw))
}

function boundaryBounceTarget(edgePosition, direction, amplitude) {
    return edgePosition + direction * amplitude
}

function relativeOffset(workspacePosition, visualFocusPosition) {
    return workspacePosition - visualFocusPosition
}

function focusWidth(collapsedWidth, focusedWidth, progress) {
    var t = Math.max(0, Math.min(1, progress))
    return collapsedWidth + (focusedWidth - collapsedWidth) * t
}

function focusProgressForOffset(relativeOffset) {
    return Math.max(0, 1 - Math.abs(relativeOffset))
}

function useFocusedWidthForCapsule(active, outgoingWithContent, focusProgress) {
    return !!active || (!!outgoingWithContent && focusProgress > 0)
}

function shouldExpandCapsule(staggerVisible, hintActive) {
    return !!staggerVisible && !!hintActive
}

function neighborBaseWidth(collapsedSize, minimumWidth) {
    return Math.max(collapsedSize, minimumWidth)
}

function staggerVisibilityForIndex(index, stageTop, stageMiddle, stageBottom) {
    if (index === 0)
        return !!stageTop
    if (index === 1)
        return !!stageMiddle
    if (index === 2)
        return !!stageBottom
    return true
}
