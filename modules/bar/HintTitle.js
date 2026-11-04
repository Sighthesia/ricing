.pragma library

// What the window hint's title rail says, as one function.
//
// The rail has two states and one rule about numbering, and the rule is the part
// worth having in one place rather than inline in a binding:
//
//   nothing bound being held   ->  "概览 | 工作区 3"
//   a bound key was pressed    ->  "启动器"            (no number)
//                                  "上一个工作区 | 工作区 4"  (workspace actions only)
//
// Why the overview is numbered: the panel is a view of the three workspaces
// around one of them, and nothing else in it says which one that is.
//
// Why a NAVIGATIONAL action is numbered: its name states a direction ("next
// workspace", "focus left", "column to workspace below"), and a direction is the
// one thing such a key can get wrong - niri's workspaces are dynamic, so "down"
// from the last one lands somewhere the user did not picture, and "focus left"
// across a column boundary is not obviously the same as "left" inside one. The
// index turns the claim into an answer.
//
// "Navigational" is the caller's judgement, not a list kept here: it is every
// workspace action plus anything that starts with `focus-` (see
// `NiriKeybindService.liveBindIsNavigational`). A FOCUS action is precisely the
// set that changes where you are.
//
// Why nothing else is: "Launcher" is not about where you are standing, and a
// workspace number after it would be a second, unrelated fact glued to the first.
// Neither is "Move column right" - it changes the layout, not your place in it.
//
// `Tr` is passed in rather than imported so this stays language-free data, and so
// it can be checked without a shell.

// `overviewKey` / `indexedKey` / `actionIndexedKey` are translation keys; the
// caller owns which words they map to.
function title(bindLabel, isNavigational, workspaceIndex, tr, keys) {
    const index = Number(workspaceIndex)
    const known = isFinite(index) && index > 0
    const label = String(bindLabel == null ? "" : bindLabel)

    if (label === "") {
        if (!known)
            return tr(keys.overview, {})
        return tr(keys.overviewIndexed, { index: index })
    }

    // A workspace action answers "did it go where I meant", so it carries the
    // index - unless its name ALREADY is that number. `focus-workspace 5` names
    // itself, and "Workspace 5 | Workspace 5" says one thing twice; the index is
    // only worth appending to a name that states a DIRECTION instead of a place.
    if (isNavigational && known && !namesWorkspace(label, index, tr, keys))
        return tr(keys.actionIndexed, { action: label, index: index })

    return label
}

// Does this label already say which workspace it went to? Asked of the same
// translation the label was rendered from, so a language that reorders the words
// is still recognised, and asked of THIS index so "to workspace 3" from
// workspace 4 still gets the number that says where you ended up.
function namesWorkspace(label, index, tr, keys) {
    const own = tr(keys.workspaceLabel, { index: index })
    return String(label).indexOf(own) >= 0
}
