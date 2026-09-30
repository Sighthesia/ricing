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

// Default slack, used when an output's scale is unknown: one logical pixel.
var tolerance = 1

// Slack for one output, in logical pixels.
//
// Two independent errors stack between what niri publishes and what this code
// compares, and they are different sizes.
//
// `niri msg -j outputs` reports `logical` extents as INTEGERS, while a
// fullscreen tile is sized from `output_size()` in full f64 precision. On a
// 2880x1800 panel at 1.75 that is 1645.714x1028.571 published as 1645x1028, so
// the IPC size is short by up to one logical pixel per axis.
//
// The tile overshoots on top of that, because niri rounds tile geometry to a
// physical pixel and then reports it in logical space. A fullscreen tile on that
// same panel measures 1646.286x1029.143 — over one logical pixel PAST the
// integer IPC size, not short of it. That is a 1/1.75 = 0.571 step, so the
// error is bounded by a couple of physical pixels, not by one logical pixel.
//
// So the slack has to be a few PHYSICAL pixels, expressed in logical pixels:
// 3/scale, plus half a pixel of headroom. That is 2.21 logical px at 1.75 and
// 6.5 at 0.5 — still far below the 16px gaps that distinguish a fullscreen tile
// from a tiled one, so the slack can never make an ordinary window read as
// fullscreen.
function slackForScale(scale) {
    var value = Number(scale)
    if (!isFinite(value) || value <= 0)
        return tolerance
    return 3 / value + 0.5
}

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
        var allowed = slack == null ? slackForScale(size.scale) : Math.max(0, Number(slack))
        if (!isFinite(allowed))
            allowed = tolerance
        for (var i = 0; i < (windows || []).length; i++) {
            var win = windows[i]
            if (!win)
                continue
            if (String(win.workspaceId) !== activeId)
                continue
            if (coversOutput(win.tileWidth, win.tileHeight, size.width, size.height, allowed)) {
                fullscreen = true
                break
            }
        }
        result[name] = fullscreen
    }
    return result
}
