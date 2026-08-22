// Pure text-diff helpers backing osu-style deletion feedback.
// Kept free of QML imports so tests can exercise the logic directly.

// Locate the contiguous range that `oldText` lost to become `newText`.
// Returns { start, removed } where `start` is the index at which the removed
// run began in both strings, or null when nothing was removed. Insertions
// mixed into the same edit (replacement/paste) keep the removal anchored at
// the shared prefix, which is exactly where the deleted glyphs used to sit.
function removeRange(oldText, newText) {
    if (oldText === newText)
        return null

    var minLen = Math.min(oldText.length, newText.length)

    // Shared prefix: where a deletion anchored at the cursor would start.
    var start = 0
    while (start < minLen && oldText[start] === newText[start])
        start++

    // Shared suffix bounded so it can never overlap the prefix scan.
    var oldEnd = oldText.length
    var newEnd = newText.length
    while (oldEnd > start && newEnd > start && oldText[oldEnd - 1] === newText[newEnd - 1]) {
        oldEnd--
        newEnd--
    }

    var removed = oldText.substring(start, oldEnd)
    if (removed.length === 0)
        return null

    return { start: start, removed: removed }
}

// Cumulative x offsets for each character of `removed`, measured with the
// editor font so per-character ghosts land where the native run rendered.
// Mirrors osu's per-character sprite layout (kerning across ghost bounds is
// intentionally ignored, same as osu's FillFlowContainer of sprites).
function cumulativeOffsets(text, advanceOf) {
    var offsets = []
    var acc = 0
    for (var i = 0; i < text.length; i++) {
        offsets.push(acc)
        acc += advanceOf(text[i])
    }
    return offsets
}

// Cascade delay for character `index` inside an n-character removal so the
// rightmost glyph detaches first and the wave travels toward the cursor.
// Total stagger is capped so bulk deletes never outlive the fall itself.
function staggerDelayMs(index, count, stepMs, maxTotalMs) {
    if (count <= 1)
        return 0
    var step = Math.min(stepMs, Math.max(1, Math.floor(maxTotalMs / (count - 1))))
    return (count - 1 - index) * step
}
