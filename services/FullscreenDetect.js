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
//   outputSizes:      { "<connector>": { width, height, scale } }
//   activeWorkspaces: { "<connector>": "<workspace id>" }
//   focusedWindows:   { "<connector>": "<window id>" }
//   windows:          [{ winId, workspaceId, isFocused, tileWidth, tileHeight }]
//
// The verdict follows the FOCUSED window of each output's active workspace, not
// "some window that happens to look fullscreen". Any window-based scan is wrong
// in practice: a window that was fullscreen and then unfullscreened, or that
// scrolled out of the active workspace, can keep stale geometry in the model and
// pin the verdict at true forever. Anchoring to the one window the user is
// actually looking at makes every such case self-correcting, because leaving
// fullscreen always changes which window is focused.

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

// Fullscreen state for every known output.
//
// Only the FOCUSED window of the output's active workspace can make it true.
// Requiring the active workspace alone is not enough — a background window on
// that workspace keeps whatever geometry it had, and a fullscreen window that
// was since unfullscreened is exactly that case. Scanning for "any fullscreen
// sized window" is what left a bar collapsed over a plain tiled firefox: its
// stale fullscreen geometry was still in the model, and nothing in the scan
// could tell the difference.
//
// Falling back to the active workspace's only window keeps a single-window
// output working, which is the common case and has no focus event to wait on.
function fullscreenOutputs(outputSizes, activeWorkspaces, focusedWindows, windows, slack) {
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

        var allowed = slack == null ? slackForScale(size.scale) : Math.max(0, Number(slack))
        if (!isFinite(allowed))
            allowed = tolerance

        // Focus is per workspace, not per output: several outputs can be active
        // at once, and only one window overall is focused. Resolve the caller's
        // per-output id against the active workspace's own windows instead.
        var focusedId = focusedWindows && focusedWindows[name] != null
            ? String(focusedWindows[name])
            : null
        var target = null
        var soleWindow = null
        var soleCount = 0
        var candidates = windows || []

        for (var i = 0; i < candidates.length; i++) {
            var win = candidates[i]
            if (!win)
                continue
            if (String(win.workspaceId) !== activeId)
                continue
            soleCount++
            if (soleCount === 1)
                soleWindow = win
            if (String(win.winId) === focusedId) {
                target = win
                break
            }
            // The focus map is empty or stale (nothing focused, or a window that
            // just closed); the model's own flag is the next best evidence.
            if (win.isFocused === true && target === null)
                target = win
        }

        // A single window on the active workspace is the visible window whether
        // or not any focus signal arrived — the common case, and one where a
        // missing focus update must not strand the bar in the wrong state.
        if (!target && soleCount === 1)
            target = soleWindow

        result[name] = !!target && coversOutput(
            target.tileWidth, target.tileHeight, size.width, size.height, allowed)
    }
    return result
}
