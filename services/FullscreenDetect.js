.pragma library

// Fullscreen detection for niri.
//
// niri's IPC has no `is_fullscreen` field (see niri-ipc `Window`: id, title,
// app_id, pid, workspace_id, is_focused, is_floating, is_urgent, layout,
// focus_timestamp). The signal that does exist is geometry: in niri a
// fullscreen tile is sized to the workspace *view* size, which is the whole
// output (`Workspace::view_size = output_size(&output)`), while a maximized
// tile is sized to the *working area* (the output minus layer-shell exclusive
// zones) and a normal tile is further inset by the layout gaps and borders
// (`src/layout/tile.rs`: `tile_size()` returns `max(window_size, view_size)`
// only for `SizingMode::Fullscreen`).
//
// So "tile covers the entire output" is an exact test for fullscreen, and it
// also correctly reports false for maximized windows, for a single-column
// window that happens to fill the working area, and for windowed (fake)
// fullscreen — which niri keeps as an ordinary tile on purpose.
//
// All inputs are plain objects/arrays so the logic stays testable under
// qmltestrunner without instantiating NiriService:
//
//   outputSizes:      { "<connector>": { width, height } }   logical pixels
//   activeWorkspaces: { "<connector>": "<workspace id>" }
//   windows:          [{ workspaceId, tileWidth, tileHeight }]

// Fullscreen tile_size comes straight from output_size(), but fractional-scale
// rounding can still land a logical pixel off, so allow a one-pixel slack.
var tolerance = 1

function _positive(value) {
    var number = Number(value)
    if (!isFinite(number) || number <= 0)
        return 0
    return number
}

// True when a tile covers the whole output in both axes.
function coversOutput(tileWidth, tileHeight, outputWidth, outputHeight, slack) {
    var width = _positive(tileWidth)
    var height = _positive(tileHeight)
    var outWidth = _positive(outputWidth)
    var outHeight = _positive(outputHeight)
    if (!width || !height || !outWidth || !outHeight)
        return false

    var allowed = slack == null ? tolerance : Math.max(0, Number(slack))
    if (!isFinite(allowed))
        allowed = tolerance
    return Math.abs(width - outWidth) <= allowed && Math.abs(height - outHeight) <= allowed
}

// Fullscreen state for every known output. Windows on a workspace that is not
// the active one on its output are ignored: niri is not showing them, so the
// bar must not collapse for a fullscreen window the user cannot see.
function fullscreenOutputs(outputSizes, activeWorkspaces, windows, slack) {
    var result = ({})
    var sizes = outputSizes || {}
    for (var name in sizes) {
        if (!Object.prototype.hasOwnProperty.call(sizes, name))
            continue
        var size = sizes[name] || {}
        // An output whose logical extents never arrived is left out entirely
        // rather than reported as "not fullscreen": a caller reading a missing
        // key and a caller reading `false` must not be able to tell the
        // difference, or a half-known output could pin a bar on screen.
        if (!_positive(size.width) || !_positive(size.height))
            continue
        var activeId = activeWorkspaces && activeWorkspaces[name] != null
            ? String(activeWorkspaces[name])
            : null
        if (activeId === null) {
            result[name] = false
            continue
        }

        var fullscreen = false
        for (var i = 0; i < (windows || []).length; i++) {
            var win = windows[i]
            if (!win)
                continue
            if (String(win.workspaceId) !== activeId)
                continue
            if (coversOutput(win.tileWidth, win.tileHeight, size.width, size.height, slack)) {
                fullscreen = true
                break
            }
        }
        result[name] = fullscreen
    }
    return result
}
