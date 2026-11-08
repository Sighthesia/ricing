.pragma library

// Incremental reconciliation helpers for the shell's two animated list models.
//
// Both lists - the window hint's rows and the workspace widget's icons - keep a
// ListModel alive across a change so a row's delegate (and its loaded icon)
// survives a move, and both mark a row that has just gone away as a GHOST: kept
// in the model at the slot it was removed from, collapsed to zero size, until its
// exit animation finishes. Removing it outright would destroy the only object that
// still knows its old physical position, and the rows after it would jump instead
// of travelling.
//
// A ghost is not part of the desired order, and that makes two questions subtle
// enough to be worth one implementation rather than two copies:
//
//   where a live row must be MOVED to, and
//   what a live row's position is, when the model's index counts ghosts.
//
// Getting either wrong is visible: a move aimed at the desired index pushes every
// ghost it passes towards the end of the list, so a row that is leaving travels
// the length of the list before it disappears instead of staying where it was.

// Model index of `key` under `keyRole`, ghosts included, or -1.
function indexOfKey(model, key, keyRole) {
    const wanted = String(key)
    for (let i = 0; i < model.count; i++) {
        if (String(model.get(i)[keyRole]) === wanted)
            return i
    }
    return -1
}

// The model index that puts a live row at live position `liveIndex`.
//
// Ghosts keep the slots they were removed from, so live rows fill the remaining
// slots in order - which is what "move a row to its live index" has to mean. Aimed
// at the raw index instead, a move pushes each ghost past it one slot further
// towards the end, and a row that is exiting is dragged the length of the list
// while it collapses.
function liveSlot(model, liveIndex, ghostRole) {
    let live = 0
    for (let i = 0; i < model.count; i++) {
        if (model.get(i)[ghostRole])
            continue
        if (live === liveIndex)
            return i
        live++
    }
    return model.count
}

// The live position of `key` - ghosts skipped - or -1. This is the index every
// layout formula is written against: a ghost occupies no height or width, so it is
// not a slot, and an index that counted it would name a row's neighbour.
function liveIndexOfKey(model, key, keyRole, ghostRole) {
    const wanted = String(key)
    let live = 0
    for (let i = 0; i < model.count; i++) {
        const row = model.get(i)
        const ghost = !!row[ghostRole]
        if (String(row[keyRole]) === wanted)
            return ghost ? -1 : live
        if (!ghost)
            live++
    }
    return -1
}
