.pragma library

// Wheel-to-focus resolution for the workspaces bar widget.
//
// Contract (纵滚都切): vertical scroll steps windows first inside the
// active workspace; only when the focused window is at the edge (or the
// workspace is empty) does the same scroll step cross into the neighbor
// workspace. Up (angleDelta.y > 0) moves backward, down moves forward.
//
// All inputs are plain arrays so the logic stays testable under
// qmltestrunner without instantiating NiriService:
//   workspaces: [{ wsId, idx, isActive }]
//   windows: [{ winId, workspaceId, colIdx, rowIdx }]
// Returns null for no-op, otherwise:
//   { kind: "window", winId } | { kind: "workspace", idx }
function orderWindows(left, right) {
    var leftColumn = left.colIdx == null ? 9999 : left.colIdx
    var rightColumn = right.colIdx == null ? 9999 : right.colIdx
    if (leftColumn !== rightColumn)
        return leftColumn - rightColumn

    var leftRow = left.rowIdx == null ? 9999 : left.rowIdx
    var rightRow = right.rowIdx == null ? 9999 : right.rowIdx
    if (leftRow !== rightRow)
        return leftRow - rightRow

    return String(left.winId).localeCompare(String(right.winId))
}

function sortedWorkspaces(workspaces) {
    var rows = (workspaces || []).slice()
    rows.sort(function (a, b) {
        return Number(a.idx) - Number(b.idx)
    })
    return rows
}

function windowsForWorkspace(windows, wsId) {
    var target = String(wsId == null ? "" : wsId)
    var rows = []
    for (var i = 0; i < (windows || []).length; i++) {
        var win = windows[i]
        if (!win)
            continue
        if (String(win.workspaceId) !== target)
            continue
        rows.push(win)
    }
    rows.sort(orderWindows)
    return rows
}

function resolveWheelStep(workspaces, windows, focusedWinId, direction) {
    var step = Number(direction)
    if (step > 0)
        step = 1
    else if (step < 0)
        step = -1
    else
        return null

    var sorted = sortedWorkspaces(workspaces)
    if (!sorted.length)
        return null

    var activePos = -1
    for (var w = 0; w < sorted.length; w++) {
        if (sorted[w] && sorted[w].isActive) {
            activePos = w
            break
        }
    }
    if (activePos < 0)
        return null

    var activeWs = sorted[activePos]
    var wins = windowsForWorkspace(windows, activeWs.wsId)
    var focused = String(focusedWinId == null ? "" : focusedWinId)
    var focusedPos = -1
    for (var k = 0; k < wins.length; k++) {
        if (String(wins[k].winId) === focused) {
            focusedPos = k
            break
        }
    }

    if (step > 0) {
        // Forward: next window first; unknown focus lands on the first
        // window instead of immediately leaving the workspace.
        if (focusedPos >= 0 && focusedPos + 1 < wins.length)
            return { kind: "window", winId: String(wins[focusedPos + 1].winId) }
        if (focusedPos < 0 && wins.length > 0)
            return { kind: "window", winId: String(wins[0].winId) }
        if (activePos + 1 < sorted.length)
            return { kind: "workspace", idx: Number(sorted[activePos + 1].idx) }
        return null
    }

    // Backward: previous window first; unknown focus lands on the last
    // window so a stray focus never ejects the user from the workspace.
    if (focusedPos > 0)
        return { kind: "window", winId: String(wins[focusedPos - 1].winId) }
    if (focusedPos < 0 && wins.length > 0)
        return { kind: "window", winId: String(wins[wins.length - 1].winId) }
    if (activePos - 1 >= 0)
        return { kind: "workspace", idx: Number(sorted[activePos - 1].idx) }
    return null
}

// Normalize a wheel event to a step direction: vertical first, then
// horizontal fallback for mice that report sideways scrolls.
function directionFromDeltas(angleY, angleX, pixelY, pixelX) {
    var y = Number(angleY)
    if (y > 0)
        return -1
    if (y < 0)
        return 1
    var x = Number(angleX)
    if (x > 0)
        return -1
    if (x < 0)
        return 1
    var py = Number(pixelY)
    if (py > 0)
        return -1
    if (py < 0)
        return 1
    var px = Number(pixelX)
    if (px > 0)
        return -1
    if (px < 0)
        return 1
    return 0
}
