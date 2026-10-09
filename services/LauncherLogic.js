.pragma library

// Pure launcher contracts for the wave launcher: query-prefix parsing,
// stable result sorting, selection clamping, and keyboard action decisions.
// No QML or service dependencies; all inputs are defensively normalized.

var clipboardPrefix = ">clip "
var shortcutPrefix = ">key "

function normalizeText(value) {
    return value == null ? "" : String(value).replace(/\s+/g, " ").trim()
}

function toCount(value) {
    var number = Number(value)
    return isFinite(number) ? number : 0
}

function parseQuery(query) {
    var body = query == null ? "" : String(query).replace(/^\s+/, "")
    var clipRest = matchPrefix(body, clipboardPrefix)
    if (clipRest !== null)
        return { mode: "clipboard", text: normalizeText(clipRest), prefix: clipboardPrefix }
    var keyRest = matchPrefix(body, shortcutPrefix)
    if (keyRest !== null)
        return { mode: "shortcuts", text: normalizeText(keyRest), prefix: shortcutPrefix }
    return { mode: "apps", text: normalizeText(body), prefix: "" }
}

function matchPrefix(text, prefix) {
    var head = text.slice(0, prefix.length).toLowerCase()
    return head === prefix ? text.slice(prefix.length) : null
}

function displayNameOf(item) {
    return item == null || item.displayName == null ? "" : String(item.displayName)
}

function identifierOf(item) {
    return item == null || item.id == null ? "" : String(item.id)
}

function iconOf(item) {
    return item == null || item.icon == null ? "" : String(item.icon)
}

function sortResults(items) {
    if (!items || !items.length)
        return []
    var sorted = items.slice()
    sorted.sort(function (left, right) {
        var byWeight = toCount(right.favoriteWeight) - toCount(left.favoriteWeight)
        if (byWeight !== 0)
            return byWeight
        var byRecent = toCount(right.lastUsedAt) - toCount(left.lastUsedAt)
        if (byRecent !== 0)
            return byRecent
        var byName = displayNameOf(left).localeCompare(displayNameOf(right))
        if (byName !== 0)
            return byName
        return identifierOf(left) < identifierOf(right) ? -1 : identifierOf(left) > identifierOf(right) ? 1 : 0
    })
    return sorted
}

function clampSelection(index, count) {
    if (!count || count < 1)
        return -1
    var value = Math.round(toCount(index))
    if (value < 0)
        return 0
    if (value > count - 1)
        return count - 1
    return value
}

function keyboardAction(key, hasInput, hasSelection, interactive) {
    var normalized = key == null ? "" : String(key).toLowerCase()
    if (normalized === "escape" || normalized === "esc")
        return hasInput ? "clear" : "close"
    if (normalized === "enter" || normalized === "return")
        return interactive && hasSelection ? "execute" : "none"
    if (normalized === "up")
        return interactive ? "up" : "none"
    if (normalized === "down")
        return interactive ? "down" : "none"
    return "none"
}

// Escape contract for routed sessions: clearing must not fall back to the
// apps list, so the query rewinds to the active route's bare prefix (e.g.
// ">clip") instead of "". Once nothing is typed beyond the prefix there is
// no input left and Escape closes.
function escapeAction(queryText) {
    var text = queryText == null ? "" : String(queryText)
    var parsed = parseQuery(text)
    if (parsed.text.length > 0)
        return { action: "clear", query: parsed.prefix }
    return { action: "close", query: text }
}

// ---- Category lens ----
// The category chip bar narrows a pooled set on top of the text filter.
// "" is the unfiltered "All" chip and the session's own "no lens" value, so
// an item without a category id stays reachable while unfiltered and drops
// out of every named chip.

function normalizeCategory(value) {
    return value == null ? "" : String(value)
}

function categoryOf(item) {
    return item == null || item.category == null ? "" : String(item.category)
}

function matchesCategory(item, category) {
    var wanted = normalizeCategory(category)
    if (wanted.length === 0)
        return true
    return item != null && categoryOf(item) === wanted
}

// One pooled item answering both lenses at once: the text needle and the
// active category.
function itemVisible(item, text, category) {
    return resultMatches(item, text) && matchesCategory(item, category)
}

// An empty tally, and the accumulator the summary is built from. Counting a
// streamed set batch by batch costs one pass over each batch instead of one
// pass over everything per batch, and the ids are registered as they arrive so
// a chip keeps its slot while the set is still filling.
function newCategoryTally() {
    return { total: 0, counts: ({}), order: [] }
}

// Adds a pooled set into a tally. `text` is the current needle: only rows that
// would be shown are counted, exactly as categorySummary does in one pass.
function tallyCategories(tally, items, text) {
    if (!tally || !items || !items.length)
        return tally
    for (var i = 0; i < items.length; i++) {
        var item = items[i]
        if (!item)
            continue
        var id = categoryOf(item)
        if (id.length > 0) {
            var key = "$" + id
            if (!Object.prototype.hasOwnProperty.call(tally.counts, key)) {
                tally.counts[key] = 0
                tally.order.push(id)
            }
        }
        if (resultMatches(item, text)) {
            tally.total++
            if (id.length > 0)
                tally.counts["$" + id]++
        }
    }
    return tally
}

// Freezes a tally into the shape the chip rail reads. Ids that arrived with a
// zero count keep their slot, so a chip does not vanish and reflow the bar.
function categoryTallyToSummary(tally) {
    var summary = { total: 0, categories: [] }
    if (!tally)
        return summary
    summary.total = tally.total
    for (var i = 0; i < tally.order.length; i++) {
        var id = tally.order[i]
        summary.categories.push({ id: id, count: tally.counts["$" + id] })
    }
    return summary
}

// Per-category tally over a pooled set. Ids are registered from the whole
// pool - not just the current text matches - so a chip keeps its slot (and
// its 0 count) while typing instead of vanishing and reflowing the bar.
// Unclassified items contribute to total only; they have no chip of their
// own.
function categorySummary(items, text) {
    return categoryTallyToSummary(
        tallyCategories(newCategoryTally(), items, text))
}

// Searchable text for one pooled item; mirrors the adapter needles via
// searchText with a displayName+description fallback.
function haystackOf(item) {
    if (item == null)
        return ""
    return item.searchText != null && String(item.searchText).length > 0
            ? String(item.searchText)
            : String(item.displayName == null ? "" : item.displayName) + " "
              + String(item.description == null ? "" : item.description)
}

// Client-side filtering over a pooled result set: keeps row identity stable
// across keystrokes so the surface can fold/reveal instead of reloading.
function filterResults(items, text, category) {
    if (!items || !items.length)
        return []
    var needle = String(text == null ? "" : text).replace(/\s+/g, " ").trim().toLowerCase()
    var wanted = normalizeCategory(category)
    if (!needle && wanted.length === 0)
        return items.slice()
    var out = []
    for (var i = 0; i < items.length; i++) {
        var item = items[i]
        if (!item)
            continue
        if (itemVisible(item, needle, wanted))
            out.push(item)
    }
    return out
}

// Index of the last item matching text, or -1 when nothing matches; lets a
// windowed list size itself so every current match is materialized instead
// of waiting for a scroll that folded rows can never trigger. An empty
// needle matches everything and reports the full range. The category lens
// takes part in the scan: a deep match hidden behind another chip must not
// stretch the window.
function lastMatchIndex(items, text, category) {
    if (!items || !items.length)
        return -1
    var needle = String(text == null ? "" : text).replace(/\s+/g, " ").trim().toLowerCase()
    var wanted = normalizeCategory(category)
    if (!needle && wanted.length === 0)
        return items.length - 1
    for (var i = items.length - 1; i >= 0; i--) {
        if (!items[i])
            continue
        if (itemVisible(items[i], needle, wanted))
            return i
    }
    return -1
}

// Single-item match used by rows deciding their own fold state.
function resultMatches(item, text) {
    var needle = String(text == null ? "" : text).replace(/\s+/g, " ").trim().toLowerCase()
    if (!needle)
        return true
    if (!item)
        return false
    return haystackOf(item).toLowerCase().indexOf(needle) >= 0
}

// Keeps the same item selected across a refilter when it still matches;
// otherwise falls back to clamping the old index into the new bounds so a
// vanished selection lands somewhere sane instead of always jumping to top.
// Selection across a query edit: keep the anchor only while the result set
// shrinks (narrowing); broadening or replacement lands back on the first
// row so growing lists never leave the highlight buried mid-list.
function refilterSelection(items, index, nextItems) {
    var count = nextItems ? nextItems.length : 0
    var shrinking = items ? count > 0 && count <= items.length : false
    if (shrinking) {
        var wanted = index >= 0 && index < items.length ? identifierOf(items[index]) : ""
        if (wanted !== "") {
            for (var i = 0; i < count; i++)
                if (identifierOf(nextItems[i]) === wanted)
                    return i
        }
    }
    return clampSelection(0, count)
}

function preservedSelection(items, index, nextItems) {
    var count = nextItems ? nextItems.length : 0
    var wanted = index >= 0 && items && index < items.length ? identifierOf(items[index]) : ""
    if (wanted !== "") {
        for (var i = 0; i < count; i++)
            if (identifierOf(nextItems[i]) === wanted)
                return i
    }
    return clampSelection(index, count)
}

// Content equality by ordered ids and icons: lets the session keep the same
// pooled array (and therefore the same live delegates) when a pull returns
// data identical to what is already rendered, while still allowing a late
// icon-theme lookup to replace an earlier empty icon.
function poolMatches(left, right) {
    if (left === right)
        return true
    if (!left || !right || left.length !== right.length)
        return false
    for (var i = 0; i < left.length; i++)
        if (identifierOf(left[i]) !== identifierOf(right[i])
                || iconOf(left[i]) !== iconOf(right[i]))
            return false
    return true
}

// Preserve a known-good icon when a later desktop-entry pull transiently
// resolves the same app to an empty source. Matched by id, not by position:
// ranking changes reorder rows and installs/removals change the length, and
// neither may disable the protection for the rows that stayed. A later
// successful lookup still replaces an empty icon, while id/order changes
// remain untouched.
function preferStableIcons(previous, next) {
    if (!previous || !next || !previous.length || !next.length)
        return next
    var knownGood = ({})
    for (var p = 0; p < previous.length; p++) {
        var oldId = identifierOf(previous[p])
        var oldIcon = iconOf(previous[p])
        if (oldId !== "" && oldIcon !== "")
            knownGood["$" + oldId] = oldIcon
    }
    var merged = next.slice()
    for (var i = 0; i < next.length; i++) {
        if (iconOf(next[i]) !== "")
            continue
        var good = knownGood["$" + identifierOf(next[i])]
        if (good !== undefined && good !== "") {
            var replacement = ({})
            for (var key in next[i])
                replacement[key] = next[i][key]
            replacement.icon = good
            merged[i] = replacement
        }
    }
    return merged
}
