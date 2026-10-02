import QtQuick
import QtTest
import "../../modules/bar" as Bar
import "../../modules/lazerbar" as Lazer

// Component contract for the mod-key window hint body: the window list, its
// state markers, and the tap that drives niri. Mounted on its own (no
// PanelWindow), so it runs headless and covers the parts of the hint that the
// window-only popup harness cannot reach.
Item {
    id: root
    // Wide enough for the panel plus its strip overhang. The body sits at x 20 and
    // the panel is three columns and two gaps across, and a synthesized click is
    // dropped when its point falls outside the root - which silently turned the
    // neighbour-tap test into "nothing was reported" rather than into a failure
    // about geometry when the panel grew by a gutter.
    width: 760
    height: 520

    // A snapshot whose every workspace's single window is titled `ws<position>`, so
    // a title in the panel names the workspace it came from and a repeated title is
    // unambiguous. The neighbours are filled in as the switch approaches them, which
    // is what the service reports: the three workspaces around the active one.
    function framedHint(active, previous) {
        function ws(position) {
            return [{ windowId: "w" + position, title: "ws" + position,
                appId: "kitty", icon: "", isFocused: true }]
        }
        return {
            workspaceId: "ws" + active,
            workspaceIndex: active,
            activeWorkspacePosition: active,
            previousActiveWorkspacePosition: previous,
            currentWindowTitle: "ws" + active,
            currentWindowAppId: "kitty",
            currentWindowIcon: "",
            currentIndex: 0,
            windows: ws(active),
            previousWindows: ws(active - 1),
            nextWindows: ws(active + 1),
            workspaces: []
        }
    }

    // Snapshot shaped exactly like WindowHintService's.
    function makeHint(overrides) {
        var hint = {
            workspaceId: "42",
            workspaceIndex: 2,
            // Same positions by default, so an assignment with no explicit
            // movement commits straight away - the no-animation path.
            activeWorkspacePosition: 1,
            previousActiveWorkspacePosition: 1,
            windows: [
                { windowId: "10", title: "kitty", appId: "kitty", icon: "", isFocused: false },
                { windowId: "11", title: "afloat", appId: "kitty", icon: "", isFocused: true }
            ],
            // The service resolves the neighbouring workspaces' windows too, so
            // the panel renders three columns by default. One window each keeps
            // the neighbours from out-growing the active column in tests that
            // are not about the columns.
            previousWindows: [
                { windowId: "20", title: "term", appId: "foot", icon: "", isFocused: false }
            ],
            nextWindows: [
                { windowId: "30", title: "mpv", appId: "mpv", icon: "", isFocused: false }
            ],
            workspaces: [
                { workspaceId: "41", workspaceIndex: 1, isActive: false, icons: [] },
                { workspaceId: "42", workspaceIndex: 2, isActive: true, icons: [{ windowId: "10" }, { windowId: "11" }] }
            ]
        }
        for (var key in (overrides || {}))
            hint[key] = overrides[key]
        return hint
    }

    // Delegates are Repeater-instantiated, so they are reached by the
    // objectNames the content sets rather than through a handle.
    function findAllByName(item, name, out) {
        out = out || []
        if (!item)
            return out
        if (item.objectName === name)
            out.push(item)
        var kids = item.children
        if (kids) {
            for (var i = 0; i < kids.length; i++)
                findAllByName(kids[i], name, out)
        }
        return out
    }

    function findByName(item, name) {
        var all = findAllByName(item, name, [])
        return all.length > 0 ? all[0] : null
    }

    // The content the user is looking at. Mid-crossing that is the arriving frame's
    // active column plus whichever neighbours the panel is currently revealing, all
    // of it inside one strip - so there is no "which copy" question left to ask.
    // The alias is kept because the rest of this file reads it constantly.
    function live() {
        return body
    }

    // The strip: the one object the panel is a window onto. Named here because
    // every geometry assertion reads its real offset and width rather than
    // re-deriving them from the plan.
    function strip() {
        return findByName(body, "windowHintStrip")
    }

    // Every window title the PANEL is currently showing, in order, read off the
    // live objects.
    //
    // The search is rooted at the BODY, not at the strip. That is the point: the
    // claim is about what the user can see, so it must not assume the panel is made
    // of one object. Rooting it at the strip would make the test pass on any layout
    // that happens to have one strip, and would not notice a second one painting the
    // same titles beside it - which is the fault being guarded against.
    //
    // Each row is asked for its real span in panel coordinates, and the rows the
    // panel reveals more than a hair of are kept: a row entirely off-panel is not
    // counted, a row the panel edge is halfway across is.
    //
    // Titles rather than window ids, because the user-visible claim is about
    // titles: two ids sharing one title are still one thing appearing twice.
    function shownTitles() {
        var titles = []
        if (!body.ready || body.width <= 0)
            return titles
        var rows = findAllByName(body, "windowHintWindowRow")
            .concat(findAllByName(body, "windowHintNeighbourRow"))
        for (var i = 0; i < rows.length; ++i) {
            var row = rows[i]
            // The Repeater leaves one role-less placeholder among the delegates,
            // and every model role on it reads undefined.
            if (!row.modelData || row.modelData.title === undefined)
                continue
            if (row.visible === false)
                continue
            var from = row.mapToItem(body, 0, 0).x
            var lo = Math.max(from, 0)
            var hi = Math.min(from + row.width, body.width)
            if (hi - lo > 1)
                titles.push(String(row.modelData.title))
        }
        return titles
    }

    // The distinct titles on screen, and any title that appears more than once.
    function repeatedTitles() {
        var counts = {}
        var titles = shownTitles()
        for (var i = 0; i < titles.length; ++i) {
            var t = titles[i]
            counts[t] = (counts[t] || 0) + 1
        }
        var repeated = []
        for (var key in counts) {
            if (counts[key] > 1)
                repeated.push(key + " x" + counts[key])
        }
        return repeated
    }

    // The panel's left and right edges in body coordinates, and whether painted
    // content reaches both. Read off the real rows rather than off the strip's
    // rect, so a strip that is the right width but the wrong place fails this.
    function panelEdgesReached() {
        // Rooted at the body for the same reason `shownTitles` is: the claim is about
        // the panel's contents, and a layout that covered the panel with two objects
        // would be as correct as one that covered it with a single strip.
        var rows = findAllByName(body, "windowHintWindowRow")
            .concat(findAllByName(body, "windowHintNeighbourRow"))
        var leftmost = body.width
        var rightmost = 0
        for (var i = 0; i < rows.length; ++i) {
            var row = rows[i]
            if (!row.modelData || row.modelData.title === undefined)
                continue
            var from = row.mapToItem(body, 0, 0).x
            var lo = Math.max(from, 0)
            var hi = Math.min(from + row.width, body.width)
            if (hi - lo <= 1)
                continue
            if (lo < leftmost)
                leftmost = lo
            if (hi > rightmost)
                rightmost = hi
        }
        // Within one GUTTER of each edge, not within a pixel.
        //
        // The columns are separated by a gap, so the gaps sweep across the panel as
        // the strip travels, and one of them necessarily crosses each edge near the
        // end of a crossing. Up to `columnGutter` of the edge is therefore showing the
        // surface rather than a column at some instant.
        //
        // That is invisible, and deliberately so: the body sits inside the popup's own
        // `contentInset` of 8px, which is wider than the 6px gap, so a gap crossing the
        // body's edge lands in padding that already shows the surface. Asserting a hard
        // flush edge here would be asserting something the panel does not and should
        // not promise - the flush-column guarantee that mattered was that no whole
        // BAND of panel went uncovered, which this still catches at 6px tolerance
        // against a 552px panel.
        // One inter-card gap, not a pixel.
        //
        // The cards sit `cellPadding` inside their cell and the cells are `columnGutter`
        // apart, so the surface shows between every pair of cards - at rest that is two
        // gaps of `gutter + 2 * cellPadding` inside the panel and `cellPadding` at each
        // edge, which is the design rather than a hole: the widget shows its square's
        // own surface around its content for the same reason.
        //
        // During a crossing that pattern slides under the panel, so the gap that is
        // normally interior crosses an edge, and the bound is one whole gap - the
        // gutter plus a card inset at each side of it. That is still the guarantee
        // that matters: the bug this test was written for left a ~180px band of bare
        // panel at one end, and a 180px column against a 44px bound cannot pass it.
        //
        // The bound is stated as the gap rather than as a constant because the gap
        // MOVES with the padding: widening the cards' inset to make room for the focus
        // indicator took it from `gutter + 2 * 8` = 22 to `gutter + 2 * 19` = 44, and
        // a bound left at the old number started failing on the very first crossing
        // sample - not because a band went uncovered but because the surface now shows
        // twice as much between two cards as it did.
        var slack = body.columnGutter + body.cellPaddingX * 2
        return leftmost <= slack + 1 && rightmost >= body.width - slack - 1
    }

    // The last activation the body reported. The body owns no niri call, so
    // this is the only place the tap route can be observed.
    QtObject {
        id: reported
        property string window: ""
    }

    Bar.BarWindowHintContent {
        id: body
        objectName: "hintBody"
        x: 20
        y: 20
        hint: root.makeHint()
        onWindowActivated: windowId => reported.window = String(windowId)
    }

    TestCase {
        id: test
        name: "WindowHintContent"
        when: windowShown

        function init() {
            reported.window = ""
            // Reduced motion is a process-wide singleton and a test that sets it
            // would otherwise change every test that runs after it.
            Lazer.MotionTokens.reducedMotionOverride = false
            // Every assignment replaces the whole snapshot, so the Repeater
            // tears its delegates down and rebuilds. That has to finish before
            // a test synthesizes a pointer event, or the coordinates are mapped
            // through a scene graph that has not caught up yet.
            body.hint = root.makeHint()
            // Two settles, and both are needed. The Repeater has to rebuild its
            // delegates before a synthesized pointer event maps coordinates
            // through the scene graph; and every marker that glides - the focus
            // frame, and especially the indicator's slow tail - has to land
            // before anything asserts on a position.
            wait(20)
            settleIndicator()
        }

        // ---- the list ---------------------------------------------------
        function test_bodyListsOneRowPerWindow() {
            // At rest the panel is the arriving frame's own three columns, so the
            // only rows that are CARDS are the active workspace's - which is what
            // "one row per window" means now that the strip can carry more.
            var cards = findAllByName(live(), "windowHintWindowRow")
            compare(cards.length, 2, "one card row per window on the active workspace")
            for (var i = 0; i < cards.length; ++i) {
                compare(String(cards[i].modelData.windowId), i === 0 ? "10" : "11",
                    "in the order the snapshot gave them")
            }
        }

        // ---- the three columns -------------------------------------------
        function test_bodyRendersThreeColumnsPreviousActiveNext() {
            // At rest the panel is three columns and the strip is exactly those
            // three: the workspace before, the active one, and the workspace after,
            // in that order, so the workspace you are on is always in the same
            // place. The order is asserted by position, not by existence: three sets
            // of rows that exist is not the same claim as three columns that are in
            // the right places.
            compare(body.plan.slots, 3, "the resting strip is three columns")
            compare(strip().width, 3 * body.columnPitch - body.columnGutter,
                "and no wider than the panel")
            var active = findAllByName(live(), "windowHintWindowRow")
            compare(active.length, 2, "the active column's rows are cards")
            var neighbours = findAllByName(live(), "windowHintNeighbourRow")
            compare(neighbours.length, 2, "one label per neighbour column")
            // Ordered by where their COLUMNS are, mapped into the strip's space. A
            // label's own x is measured from its column, so reading it directly would
            // report 0 for every neighbour and make this assertion vacuous - which is
            // exactly what it did before: it passed on a strip that had every column
            // at x 0. Placed by position rather than by class, because a column
            // rendering itself on the wrong side would still be "a neighbour" by
            // class, and that is the layout fault worth catching.
            var placed = neighbours.map(function(row) {
                return { column: row.parent.mapToItem(strip(), 0, 0).x, id: row.modelData.windowId }
            }).sort(function(a, b) { return a.column - b.column })
            // Stated against the active column's own slot rather than as literals, so
            // the frame is checked as "one column's width either side" instead of as
            // three numbers that could drift apart while still passing.
            var activeSlotX = strip().activeColumnX
            compare(placed[0].column, activeSlotX - body.columnPitch,
                "a neighbour column one width to the left of the active one")
            compare(placed[1].column, activeSlotX + body.columnPitch,
                "and one the same width to the right")
            // Each column shows its OWN workspace's window, not a copy of the
            // active one - a neighbour that listed the active workspace's
            // windows would be decoration pretending to be information.
            compare(placed[0].id, "20", "the left neighbour is the previous workspace")
            compare(placed[1].id, "30", "and the right one is the next workspace")
        }

        function test_neighbourColumnsCarryNoState() {
            // Only the active column holds focus, so a card, a highlight or an
            // indicator on a neighbour would claim a second selection. The
            // neighbour labels are plain text over the panel's own surface.
            var previous = findAllByName(live(), "windowHintNeighbourRow")[0]
            var active = findAllByName(live(), "windowHintWindowRow")[0]
            // The active row is a card; a neighbour is not.
            verify(active.color !== undefined, "the active row is a filled card")
            verify(previous.color === undefined, "a neighbour label paints no fill")
            compare(findAllByName(live(), "windowHintFocusFrame").length, 1,
                "one highlight, for the whole panel")
            compare(findAllByName(live(), "windowHintFocusIndicator").length, 1,
                "and one indicator")
            // A neighbour row is still a tap target: focusing a window in another
            // workspace is the one thing that makes the neighbours worth showing,
            // and niri moves the view to that window's workspace.
            verify(previous.activated !== undefined, "neighbour rows report an activation")
        }

        function test_tappingANeighbourRowReportsItsId() {
            var row = findAllByName(live(), "windowHintNeighbourRow")[1]
            mouseClick(row, row.width / 2, row.height / 2, Qt.LeftButton)
            compare(reported.window, "30")
        }

        function test_stateMarkersSitOnTheActiveColumn() {
            // The active column is the MIDDLE slot, so a highlight left at x 0 would
            // be drawn under the previous workspace's labels and none of it would be
            // visible over the row it is supposed to mark.
            //
            // Every position below is read in the STRIP's space, which is the space
            // the markers and `activeColumnX` are stated in. A row's own x is
            // measured from its column, so comparing one against a marker without
            // mapping it would put a column-relative number next to a strip-relative
            // one - and they agree at rest only because the strip happens to be at 0.
            var rows = findAllByName(live(), "windowHintWindowRow")
            var wash = findByName(live(), "windowHintFocusFrame")
            var bar = findByName(live(), "windowHintFocusIndicator")
            var neighbours = findAllByName(live(), "windowHintNeighbourRow")
            var rowInStrip = rows[0].mapToItem(strip(), 0, 0)
            var leftColumn = neighbours[0].parent.mapToItem(strip(), 0, 0)
            var rightColumn = neighbours[1].parent.mapToItem(strip(), 0, 0)
            compare(wash.x, rowInStrip.x, "the highlight starts where the row starts")
            compare(wash.x, strip().activeColumnX + body.cellPaddingX,
                "and on the active column, inside its padding")
            compare(wash.width, body.columnWidth - body.cellPaddingX * 2,
                "spanning the card inside the padding, was " + wash.width)
            // The left neighbour's column ends exactly where the active one begins,
            // so the check is that the highlight does not reach back over it.
            compare(wash.x, leftColumn.x + body.columnPitch + body.cellPaddingX,
                "and starts where the left neighbour's column ends, inside its padding")
            // The indicator is a mark BESIDE the row now, in the band's left padding,
            // so it is left of the outline rather than over it - which is the widget's
            // arrangement, where the indicator sits outside the marked square.
            verify(bar.x + bar.width <= wash.x,
                "the indicator is outside the highlight, its right edge was "
                    + (bar.x + bar.width) + " against " + wash.x)
            // ...and the same on the far side, or the highlight would cover the next
            // workspace's labels.
            verify(wash.x + wash.width <= rightColumn.x,
                "and stops before the right neighbour's column")
        }

function test_anEmptyNeighbourKeepsItsSlotAndSaysSo() {
            // An empty neighbour workspace must not shrink the panel. It used to:
            // the column took no slot, the panel narrowed, and the active workspace
            // moved out of the middle - so the same three workspaces read as a
            // different panel depending on what the neighbours were running. Now the
            // slot stays and the column states the fact itself, because a blank
            // column would read as a layout fault rather than as "nothing here".
            body.hint = root.makeHint({ previousWindows: [] })
            wait(20)
            compare(body.plan.slots, 3, "the strip is still three columns")
            var emptySlots = findAllByName(live(), "windowHintColumnEmpty")
            // One placeholder, in the left column, and it is the visible one: the
            // other two columns have windows so their placeholders are hidden.
            var visible = emptySlots.filter(function(s) { return s.visible })
            compare(visible.length, 1, "exactly one placeholder is showing")
            var slot = visible[0]
            verify(slot.mapToItem(body, 0, 0).x < 1 + body.cellPaddingX,
                "and it is in the left column, was " + slot.mapToItem(body, 0, 0).x)
            compare(findByName(slot, "windowHintEmptySlotLabel").text, "No windows",
                "which is that it has no windows")
            // The other side is unaffected, and says so by having a row rather than
            // a placeholder.
            compare(findAllByName(live(), "windowHintNeighbourRow").length, 1,
                "the other side still has its one row")
            // The frame is unchanged, and the active workspace is still the middle.
            compare(body.shownColumnCount, 3)
            compare(body.width, 3 * body.columnPitch - body.columnGutter,
                "the panel did not resize")
            compare(findByName(live(), "windowHintFocusFrame").x,
                body.columnPitch + body.cellPaddingX,
                "and the highlight is still on the active column")
        }

        function test_thePanelIsThreeColumnsWideWhateverTheNeighboursHold() {
            // The one case that broke it: both neighbours empty. A panel that
            // reports one column here is a panel that resizes under the pointer as
            // the user moves between the edge workspace and an interior one.
            body.hint = root.makeHint({ windows: [], previousWindows: [], nextWindows: [] })
            wait(20)
            compare(body.shownColumnCount, 3, "three columns")
            compare(body.width, 3 * body.columnPitch - body.columnGutter,
                "the same width as always")
            compare(strip().width, 3 * body.columnPitch - body.columnGutter,
                "and the strip is no wider")
            // All three columns say they are empty - the middle one is not a special
            // case, because an empty workspace is the same fact wherever it is.
            var visible = findAllByName(live(), "windowHintColumnEmpty")
                .filter(function(s) { return s.visible })
            compare(visible.length, 3, "all three columns show a placeholder")
            for (var i = 0; i < 3; ++i) {
                compare(visible[i].height, body.rowHeight,
                    "placeholder " + i + " stands where a row would")
            }
            // Three placeholders at three distinct offsets - the frame is intact, and
            // the offsets are what says which is the active column.
            var xs = visible.map(function(s) { return s.mapToItem(body, 0, 0).x })
                .sort(function(a, b) { return a - b })
            compare(xs[0], body.cellPaddingX,
                "the first column takes the first slot, inside its padding")
            compare(xs[1], body.columnPitch + body.cellPaddingX, "the second the second")
            compare(xs[2], body.columnPitch * 2 + body.cellPaddingX, "and the third the third")
        }

        function test_thePanelIsAsWideAsItsColumns() {
            // The host sizes the input slot from this number, so it has to be the
            // count times the column width and nothing else - a stray padding term
            // would leave a band of input region beside a narrower panel.
            compare(body.width, body.shownColumnCount * body.columnPitch - body.columnGutter)
            compare(body.shownColumnCount, 3)
            compare(body.width, 3 * body.columnPitch - body.columnGutter)
        }

        function test_theActiveWorkspaceIsAlwaysTheMiddleColumn() {
            // The claim this whole layout rests on: the workspace you are on is in
            // the same place whatever is beside it. Asserted across every neighbour
            // combination, because "always" is the part that has to be checked -
            // one passing case would not tell a fixed slot from a derived one.
            var combos = [
                { previousWindows: [{ windowId: "p", title: "p", icon: "", isFocused: false }],
                    nextWindows: [{ windowId: "n", title: "n", icon: "", isFocused: false }] },
                { previousWindows: [], nextWindows: [{ windowId: "n", title: "n", icon: "", isFocused: false }] },
                { previousWindows: [{ windowId: "p", title: "p", icon: "", isFocused: false }],
                    nextWindows: [] },
                { previousWindows: [], nextWindows: [] }
            ]
            for (var i = 0; i < combos.length; ++i) {
                body.hint = root.makeHint(combos[i])
                wait(20)
                var wash = findByName(live(), "windowHintFocusFrame")
                compare(wash.x, body.columnPitch + body.cellPaddingX,
                    "combination " + i + ": the active column is the middle one")
                // And centred on the panel, not merely second of three.
                compare(wash.x + wash.width / 2, body.width / 2,
                    "combination " + i + ": and centred on the panel")
            }
        }

        function test_columnsShareOneRowPitch() {
            // The focus indicator computes its y from the active column's pitch
            // alone. If a neighbour column used a different spacing, the three lists
            // would not line up across the panel and the panel would read as three
            // unrelated stacks. Every column is one delegate of the same component,
            // so this is asserted across the real delegates rather than across a
            // named previous/active/next triple.
            var columns = columnDelegates()
            compare(columns.length, 3, "three column delegates")
            for (var i = 1; i < columns.length; ++i) {
                compare(columns[i].spacing, columns[0].spacing,
                    "column " + i + " matches the first column's pitch")
                compare(columns[i].width, columns[0].width,
                    "and the columns are peers in width")
            }
            // The slots are derived from the index rather than accumulated by a
            // layout pass, so each column knows where it belongs.
            for (var k = 0; k < columns.length; ++k) {
                compare(columns[k].x, k * body.columnPitch,
                    "column " + k + " holds slot " + k)
            }
        }

        // The strip's column delegates, left to right. Reached by geometry rather
        // than by name: the columns share one component and one objectName, so
        // their order is what distinguishes them.
        function columnDelegates() {
            var s = strip()
            if (!s)
                return []
            var out = []
            var rows = findAllByName(s, "windowHintNeighbourRow")
                .concat(findAllByName(s, "windowHintWindowRow"))
            // A column is the parent of a row or of a placeholder, whichever it has.
            var seen = {}
            for (var i = 0; i < rows.length; ++i) {
                var parent = rows[i].parent
                if (parent && !seen[parent]) {
                    seen[parent] = true
                    out.push(parent)
                }
            }
            return out.sort(function(a, b) { return a.x - b.x })
        }

        function test_theWholePanelArrivesInOnePiece() {
            // No row is left behind and none arrives on its own. A switch used to
            // stagger the three columns in row by row, which meant the panel was
            // briefly three different heights' worth of half-drawn content; now the
            // strip is displaced as one object, so every row of every column crosses
            // at the same time and none of them is ever partially faded in.
            var many = []
            for (var i = 0; i < 3; i++)
                many.push({ windowId: "p" + i, title: "p" + i, icon: "", isFocused: false })
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 1,
                previousWindows: many,
                windows: many,
                nextWindows: many
            })
            // Sampled DURING the crossing, which is when the strip carries both
            // frames at once.
            wait(Math.round(body.slideDuration / 2))
            verify(body.swapping, "still crossing")
            // The strip holds one column per workspace in the union of the two
            // frames, so a two-step move is five columns and every one of them has
            // its rows - none held back, none missing.
            compare(body.plan.slots, 5, "a two-step crossing carries five columns")
            var all = findAllByName(strip(), "windowHintWindowRow")
                .concat(findAllByName(strip(), "windowHintNeighbourRow"))
            // 3 rows in each of the four columns that have them, plus the arriving
            // frame's active column.
            compare(all.length, 12, "every row of every column is on the strip")
            // All opaque: a row that faded in on its own would be a hole in the
            // displacement, and one strip is precisely what rules a hole out.
            for (var r = 0; r < all.length; ++r)
                verify(all[r].opacity > 0.9, "row " + r + " is solid, was " + all[r].opacity)
            settleSlide()
            // Landed: the strip has narrowed to the arriving frame's own three
            // columns, so the four that were travelling through the panel are gone.
            compare(body.plan.slots, 3, "and the strip is three columns again")
            compare(findAllByName(strip(), "windowHintWindowRow").length, 3)
        }

        function test_bodyShowsNothingButTheList() {
            // The panel is body-only: no header, no divider, no workspace row. Anything
            // here is a copy of what the bar already shows or of what the rows
            // themselves say.
            verify(findByName(live(), "windowHintWorkspaceChip") === null)
            verify(findByName(live(), "windowHintDivider") === null)
        }

        function test_bodyCarriesNoWorkspaceActivation() {
            // Switching workspaces stays on mod+digit; the list only focuses
            // windows. A stray workspace signal would be dead API.
            verify(body.workspaceActivated === undefined)
        }

        function test_body_isSizedForThePopupSlot() {
            // The popup measures its geometry from this height; a zero here
            // would map a 1px-tall input region.
            verify(body.implicitHeight >= 28)
        }

        // ---- state markers ----------------------------------------------
        function test_theFocusTintIsTheFocusedRowsOwnBackground() {
            // The tint has to be painted by the ROW, because that is the only thing
            // underneath the icon and the title. It was a separate element at z 5
            // above the rows instead - the only arrangement that let a shared element
            // mark an opaque card - and `settingsSelected` is the primary at a
            // quarter alpha, so it veiled both. This is `LauncherResultRow.qml`'s
            // arrangement: the row's own fill, with its content as children on top.
            var tint = Lazer.LazerTheme.settingsSelected
            var rows = findAllByName(live(), "windowHintWindowRow")
            var tinted = rows.filter(function(r) { return r.color === tint })
            compare(tinted.length, 1, "exactly one row carries the tint")
            compare(tinted[0], rows[body.focusedRowIndex],
                "and it is the focused row, not row " + rows.indexOf(tinted[0]))
            compare(rows[0].color, Lazer.LazerTheme.settingsCard,
                "the rows either side keep the plain card")
            // A Rectangle borders itself by default; the tint is this row's signal,
            // so the default hairline would be a second, wrong outline around it.
            compare(rows[0].border.width, 0)
        }

        function test_theSharedHighlightCannotCoverTheRowContent() {
            // The claim the whole rearrangement exists for: nothing that marks the
            // focused row is painted over its icon or its title.
            //
            // A fully transparent fill is the assertion - anything with alpha would
            // composite over the content, and at a quarter alpha it visibly veils it.
            // The tint itself is the row's own background, which the content is a
            // child of, so it is under the content by construction.
            var frame = findByName(live(), "windowHintFocusFrame")
            compare(frame.color.a, 0, "the shared highlight fills nothing, alpha was "
                + frame.color.a)
            // What it draws instead is the outline, so the glide is still visible.
            verify(frame.border.width > 0, "it outlines instead, width was "
                + frame.border.width)
            compare(frame.border.color, Lazer.LazerTheme.settingsAccent,
                "in the accent, was " + frame.border.color)
        }

        function test_theIndicatorSitsBesideTheCardNotInsideIt() {
            // The marker is a mark BESIDE the row it marks, in the band's left padding.
            // `Workspaces.qml` puts its indicator outside the marked square - under it,
            // in the bar's own gap - and this had it 4px in from the card's left edge,
            // between the card's edge and its icon.
            var rows = findAllByName(live(), "windowHintWindowRow")
            var wash = findByName(live(), "windowHintFocusFrame")
            var bar = findByName(live(), "windowHintFocusIndicator")
            var icon = findByName(live(), "windowHintWindowIcon")
            compare(icon.x, rows[0].children[0].x, "glyphs share one inset")
            // Left of the card, so its whole width is clear of the card's left edge.
            // The bar is a child of the strip and the row a child of one of its
            // columns, so the row is mapped into the strip's space before the two are
            // comparable - the row's own x is measured from its column.
            var rowInStrip = rows[0].mapToItem(strip(), 0, 0)
            verify(bar.x + bar.width <= rowInStrip.x,
                "the bar ends left of the card, was " + (bar.x + bar.width)
                    + " against " + rowInStrip.x)
            // Inside the band's own left padding though, or it would sit on the
            // neighbouring column. Centred in it: 3px of a 3px bar in an 8px padding
            // leaves 2px either side.
            // One padding on both sides, which is the claim: the marker is as far from
            // the band's edge as the card is from its own, and as far from the card as
            // from the band. 8 is `Workspaces.cellPadding`, stated here so the suite
            // owns the number rather than restating whatever the component computes.
            var leftGap = bar.x - strip().activeColumnX
            var rightGap = body.cellPaddingX - leftGap - bar.width
            compare(leftGap, 8, "8px clear of the band's left edge, was " + leftGap)
            compare(rightGap, 8, "and 8px clear of the card, was " + rightGap)
            // The icon's inset is a plain card padding, not room made for the marker:
            // the marker is outside the card, so nothing inside has to clear it. 8 is
            // `Workspaces.cellPadding` - the gap between an icon and its square's edge
            // in the widget this panel keeps borrowing from - stated here rather than
            // read back from the body, so the claim is a number the suite owns.
            compare(icon.x, 8, "the icon sits at the widget's own card padding, was "
                + icon.x)
            compare(wash.x, strip().activeColumnX + body.cellPaddingX,
                "and the outline is on the active column, inside its padding")
            // The title follows the glyph, so the whole row shifts with it.
            var title = findByName(live(), "windowHintWindowTitle")
            compare(title.anchors.leftMargin, 8)
        }

        function test_indicatorStacksAboveTheFocusHighlight() {
            // The indicator is a mark ON the highlight. Siblings that share a z
            // fall back to declaration order, so the stacking has to be stated:
            // rows at the default 0, the highlight at 5, the indicator at 6. With
            // the highlight on top the bar would be painted over and the current
            // window would lose its indicator entirely.
            var rows = findAllByName(live(), "windowHintWindowRow")
            var wash = findByName(live(), "windowHintFocusFrame")
            var bar = findByName(live(), "windowHintFocusIndicator")
            verify(bar.z > wash.z, "indicator above the highlight, was " + bar.z)
            verify(wash.z > rows[0].z, "highlight above the rows, was " + wash.z)
        }

        function test_focusHighlightStillGlidesAndSnaps() {
            // The launcher's contract, minus the border: only y is animated, and
            // the highlight is bounded by the row.
            var frame = findByName(live(), "windowHintFocusFrame")
            var rows = findAllByName(live(), "windowHintWindowRow")
            compare(frame.enabled, false, "inert, so it cannot swallow a row tap")
            // Bounded by the row, not inset: the highlight has to cover exactly
            // the row it marks, and the row spans its column's full width. The
            // rows sit inside their column, so the comparison is made there too.
            var rowInStrip = rows[1].mapToItem(strip(), 0, 0)
            compare(frame.height, rows[1].height)
            compare(frame.x, rowInStrip.x, "starts where the row starts")
            compare(frame.x, strip().activeColumnX + body.cellPaddingX,
                "and on the active column, inside its padding")
            compare(frame.width, rows[1].width, "and is exactly as wide")
            compare(frame.radius, rows[1].radius, "corners match the row's")
            // The marker is an outline around the row, not a fill over it: a fill
            // above the row is what veiled its icon and title. 1.5 is the launcher's
            // `selectionFrame` border, stated here rather than read back from the
            // component so the claim is a number this suite owns.
            compare(frame.border.width, 1.5,
                "an outline around it, not a fill over it, was " + frame.border.width)
            compare(frame.color.a, 0, "and it fills nothing, alpha was " + frame.color.a)

            body.hint = root.makeHint({
                windows: [
                    { windowId: "10", title: "kitty", appId: "kitty", icon: "", isFocused: true },
                    { windowId: "11", title: "afloat", appId: "kitty", icon: "", isFocused: false }
                ]
            })
            // Look the rows up again: the Repeater tore the old delegates down
            // when the snapshot was replaced, so a handle taken before the swap
            // reads a destroyed item.
            var after = findAllByName(live(), "windowHintWindowRow")
            wait(Math.round(Lazer.MotionTokens.settingsSidebarCollapse / 2))
            var gliding = findByName(live(), "windowHintFocusFrame")
            // Mid-glide the highlight is between the two rows, which is what
            // makes it read as travelling rather than jumping. A highlight with
            // no Behavior on y would already be at 0 here.
            verify(gliding.y > 0 && gliding.y < after[1].y,
                "in flight between the rows, was " + gliding.y)

            wait(Lazer.MotionTokens.settingsSidebarCollapse + 120)
            var moved = findByName(live(), "windowHintFocusFrame")
            compare(moved.y, 0, "glided to the first row")
            compare(findAllByName(live(), "windowHintFocusFrame").length, 1, "one for the list")
        }

        function test_focusIsOneSharedIndicatorNotAPerRowMarker() {
            // The workspace widget marks its active target with a single
            // travelling bar, and the launcher frames its current row with one
            // shared frame. N per-row markers would read as decoration, so there
            // must be exactly one of each for the whole list.
            compare(findAllByName(live(), "windowHintFocusIndicator").length, 1)
            compare(findAllByName(live(), "windowHintFocusFrame").length, 1)
            verify(findByName(live(), "windowHintFocusedBar") === null)
        }

        function test_indicatorUsesTheWorkspaceIndicatorVocabulary() {
            var bar = findByName(live(), "windowHintFocusIndicator")
            var rows = findAllByName(live(), "windowHintWindowRow")
            // Same bar as the workspace indicator, turned 90 degrees for a list that
            // travels vertically: its thickness is that bar's height and its resting
            // length is that bar's width. Read from the theme rather than restated,
            // because the claim is about being the SAME bar -
            // `Workspaces.indicatorBarWidth` is `barWidgetHeight - 16`, which is 26,
            // and a literal 16 here had the panel carrying a shorter bar than the one
            // above it on screen.
            compare(bar.width, Lazer.LazerTheme.barIndicatorHeight)
            compare(bar.radius, Lazer.LazerTheme.barIndicatorRadius)
            compare(bar.color, Lazer.LazerTheme.osuGreen)
            compare(bar.height, Lazer.LazerTheme.barWidgetHeight - 16,
                "as long as the widget's indicator, was " + bar.height)
            // And it has to fit the row it marks, or it would be clipping or
            // overhanging the card it belongs to.
            verify(bar.height <= rows[0].height,
                "and it fits inside the row, " + bar.height + " in " + rows[0].height)
            verify(bar.visible, "the focused row is on screen, so the bar is")
        }

        function test_indicatorStretchesAlongItsOwnLongAxis() {
            // The reason it is vertical: the workspace bar elongates along its
            // long axis, so this one must too. Stretching the short axis would
            // turn a bar into a rectangle mid-flight.
            var bar = findByName(live(), "windowHintFocusIndicator")
            compare(bar.width, Lazer.LazerTheme.barIndicatorHeight, "stays bar-thin")
            verify(bar.height >= Lazer.LazerTheme.barWidgetHeight - 16,
                "at least its resting length, was " + bar.height)
        }

        function test_indicatorIsCentredOnTheFocusedRow() {
            // The indicator computes its own y from the list pitch instead of
            // tracking a row item, so this is the guard against the two drifting
            // apart: if the row height or the Column spacing changes and the
            // pitch is not updated, the bar would mark thin air.
            var rows = findAllByName(live(), "windowHintWindowRow")
            var wash = findByName(live(), "windowHintFocusFrame")
            var bar = findByName(live(), "windowHintFocusIndicator")
            var rowCentre = rows[1].y + rows[1].height / 2
            compare(bar.y + bar.height / 2, rowCentre, "centred on the row")
            // The same clearance the band's left padding gives the card, and the same
            // one the bar is placed with: 8. Stated rather than read back, so it is a
            // claim about the gap and not a restatement of whatever the inset is.
            compare(wash.x - (bar.x + bar.width), 8,
                "8px clear of the outline's left edge, was "
                    + (wash.x - (bar.x + bar.width)))
            // The bar is a child of the strip and the row is a child of a column of
            // the strip, so the row has to be mapped into the strip's space before the
            // two can be compared - the row's own x is measured from its column.
            var rowInStrip = rows[1].mapToItem(strip(), 0, 0)
            verify(bar.x + bar.width < rowInStrip.x + rows[1].width, "and within the row")
        }

        // Wait out the indicator's dual-speed tracker. The head lands in `medium`, but
        // the tail runs `slow * 2` on OutSine, which starts slowly - so anything
        // that switched an indicator target is still stretched long after the
        // head has arrived, and a position read before then is a frame of the
        // elongation rather than the settled bar.
        function settleIndicator() {
            wait(Lazer.MotionTokens.slow * 2 + 150)
        }

        // Wait out one full crossing. The crossing is two phases on one clock with no
        // stagger behind them, so the declared total is the whole of it - plus room
        // for the animation's `onFinished` to have narrowed the strip to the arriving
        // frame and released the held one.
        function settleSlide() {
            wait(body.slideDuration + 40)
        }

        function test_indicatorFollowsAFocusSwitch() {
            // Switch focus to the first row; the single instance has to travel
            // rather than leave a second one behind.
            body.hint = root.makeHint({
                windows: [
                    { windowId: "10", title: "kitty", appId: "kitty", icon: "", isFocused: true },
                    { windowId: "11", title: "afloat", appId: "kitty", icon: "", isFocused: false }
                ]
            })
            wait(Lazer.MotionTokens.medium + 40)
            // Mid-travel the bar is stretched across the gap between head and
            // tail, which is the workspace indicator's motion: it elongates
            // along its long axis and contracts on arrival.
            var bars = findAllByName(live(), "windowHintFocusIndicator")
            compare(bars.length, 1, "still one instance")
            // Longer than its resting length, which is the widget's own
            // `indicatorBarWidth` - stated from the theme so the claim is "stretched
            // past resting", not "stretched past whatever resting happens to be".
            verify(bars[0].height > Lazer.LazerTheme.barWidgetHeight - 16,
                "stretched while the tail trails, was " + bars[0].height)
            compare(bars[0].width, Lazer.LazerTheme.barIndicatorHeight, "still bar-thin")

            settleIndicator()
            var settled = findByName(live(), "windowHintFocusIndicator")
            var rows = findAllByName(live(), "windowHintWindowRow")
            compare(settled.height, Lazer.LazerTheme.barWidgetHeight - 16,
                "contracted on arrival, back to the widget's own length, was "
                    + settled.height)
            compare(settled.y + settled.height / 2, rows[0].height / 2, "centred on the first row")
        }

        function test_underlineHiddenWhenTheFocusedWindowIsPastTheCap() {
            // The window is real but not on screen, so there is nothing honest
            // to underline.
            var many = []
            for (var i = 0; i < 8; i++)
                many.push({ windowId: String(i), title: "w" + i, icon: "", isFocused: i === 7 })
            body.hint = root.makeHint({ windows: many })
            wait(20)
            verify(!findByName(live(), "windowHintFocusIndicator").visible)
        }

        function test_underlineHiddenWhenNoWindowIsFocused() {
            body.hint = root.makeHint({
                windows: [
                    { windowId: "10", title: "kitty", appId: "kitty", icon: "", isFocused: false },
                    { windowId: "11", title: "afloat", appId: "kitty", icon: "", isFocused: false }
                ]
            })
            wait(20)
            verify(!findByName(live(), "windowHintFocusIndicator").visible)
        }

        // ---- tap --------------------------------------------------------
        function test_tappingAWindowRowReportsItsId() {
            var rows = findAllByName(live(), "windowHintWindowRow")
            mouseClick(rows[1], rows[1].width / 2, rows[1].height / 2, Qt.LeftButton)
            compare(reported.window, "11")
        }

        function test_tappingAnyRowIsLive() {
            // Every row is a target, not only the focused one.
            var rows = findAllByName(live(), "windowHintWindowRow")
            mouseClick(rows[0], rows[0].width / 2, rows[0].height / 2, Qt.LeftButton)
            compare(reported.window, "10")
        }

        function test_rowFlashFollowsTheSharedRecipe() {
            // Asserted as a contract, not by sampling an opacity mid-animation:
            // the duration and easing are the shared tokens, so a deliberate
            // retune of the recipe cannot silently desync this file.
            var rows = findAllByName(live(), "windowHintWindowRow")
            var flash = rows[0].rowFlashAnimation
            compare(flash.property, "opacity")
            compare(flash.from, Lazer.MotionTokens.clickFlashOpacity)
            compare(flash.to, 0)
            compare(flash.duration, Lazer.MotionTokens.clickFlashDuration)
            compare(flash.easing.type, Lazer.MotionTokens.clickFlashEasing)
            compare(flash.target, rows[0].rowFlashOverlay)
            // The overlay takes no input, so a tap cannot be swallowed by it.
            compare(rows[0].rowFlashOverlay.enabled, false)
        }

        function test_pressFlashRunsOnTap() {
            var rows = findAllByName(live(), "windowHintWindowRow")
            var row = rows[0]
            mouseClick(row, row.width / 2, row.height / 2, Qt.LeftButton)
            // The same tap must both start the flash and report the activation.
            // restart() takes effect on the click frame, so this is read inline.
            compare(reported.window, "10", "tap reported")
            compare(row.rowFlashAnimation.running, true, "flash started")
            verify(row.rowFlashOverlay.opacity > 0, "flash is visible")
        }

        // ---- overflow and empty states ----------------------------------
        function test_longWindowListCollapsesToAnOverflowLine() {
            var many = []
            for (var i = 0; i < 8; i++)
                many.push({ windowId: String(i), title: "w" + i, icon: "", isFocused: false })
            body.hint = root.makeHint({ windows: many })
            wait(20)
            compare(findAllByName(live(), "windowHintWindowRow").length, 8 - 3)
            // Every column carries an overflow line instance; only the active
            // column's has anything to say, so the one with text is read rather
            // than the first one found.
            var line = findAllByName(live(), "windowHintOverflow")
                .filter(function(t) { return t.text !== "" })[0]
            verify(line !== undefined, "a column has an overflow line")
            compare(line.text, "+3 more windows")
        }

        function test_onlyTheActiveColumnCarriesAnOverflowLine() {
            // The cap applies to the active column, and it is the only one with a
            // "+N more" line. A neighbour column reporting a cap it does not have
            // would claim windows that are not being shown, and the strip carries
            // neighbour columns that are still travelling through the panel.
            var many = []
            for (var i = 0; i < 8; i++)
                many.push({ windowId: String(i), title: "w" + i, icon: "", isFocused: false })
            body.hint = root.makeHint({ windows: many, previousWindows: many })
            wait(20)
            var lines = findAllByName(live(), "windowHintOverflow")
            var showing = lines.filter(function(l) { return l.visible })
            compare(showing.length, 1, "one overflow line, on the active column")
            compare(showing[0].text, "+3 more windows")
            verify(showing[0].mapToItem(body, 0, 0).x > body.columnPitch * 0.5,
                "and it is in the middle column, was " + showing[0].mapToItem(body, 0, 0).x)
        }

        function test_anEmptyWorkspaceShowsAPlaceholderNotAHole() {
            // An empty workspace is a real state, not a missing snapshot: the bar
            // already names the workspace, so the panel has to say something about
            // it. The placeholder is a rectangle where a window row would be -
            // blank space would read as a layout fault, and a filled card would
            // read as a window that isn't there.
            body.hint = root.makeHint({ windows: [] })
            wait(20)
            compare(findAllByName(live(), "windowHintWindowRow").length, 0)
            var visible = findAllByName(live(), "windowHintColumnEmpty")
                .filter(function(s) { return s.visible })
            compare(visible.length, 1, "one placeholder, in the active column")
            var slot = visible[0]
            verify(Math.abs(slot.mapToItem(body, 0, 0).x
                - (body.columnPitch + body.cellPaddingX)) < 1,
                "and it is the middle column, was " + slot.mapToItem(body, 0, 0).x)
            var frame = findByName(slot, "windowHintEmptySlot")
            // QML hands a transparent colour back as #00000000, so that is what
            // "no fill" reads as here.
            compare(String(frame.color), "#00000000", "outlined, not filled - a fill is what a real row has")
            compare(frame.border.width, 1, "a hairline outline marks the absence")
            compare(String(frame.border.color), String(Lazer.LazerTheme.divider),
                "in the shared divider token, so it tracks the theme")
            compare(frame.enabled, false, "inert, so it cannot swallow a tap")
            // Same footprint as a row, so the three columns stay on one pitch.
            compare(slot.height, body.rowHeight)
        }

        function test_aPlaceholderIsHiddenWhenTheColumnHasWindows() {
            // The other half of the same contract: a column with windows must not
            // also show an empty slot, or every row would be doubled by a ghost. All
            // three columns have a placeholder instance; none may be visible.
            body.hint = root.makeHint()
            wait(20)
            compare(findAllByName(live(), "windowHintColumnEmpty").length, 3,
                "each column has a placeholder instance")
            var showing = findAllByName(live(), "windowHintColumnEmpty")
                .filter(function(s) { return s.visible })
            compare(showing.length, 0, "and none of them is showing")
        }

        function test_coldSnapshotStatesItself() {
            body.hint = null
            wait(20)
            compare(findAllByName(live(), "windowHintWindowRow").length, 0)
            verify(findByName(body, "windowHintEmpty").visible)
        }

        // ---- switching between workspaces --------------------------------
        function test_theStripCarriesBothFramesWhileItTravels() {
            // A workspace switch replaces every row, so the rows of the frame being
            // left have to still be mounted while the strip carries them off -
            // otherwise the panel's contents are simply gone and remade between two
            // frames. One strip, not two objects, so the claim is that its columns
            // cover the union of both frames rather than that a held copy exists.
            compare(body.swapping, false, "settled to begin with")
            compare(body.plan.slots, 3, "and the strip is three columns")

            // Settle on the frame being left, so the crossing below really is
            // position 1 -> 2 and the union is the one under test.
            body.hint = root.framedHint(1, 1)
            wait(20)
            body.hint = root.framedHint(2, 1)
            verify(body.swapping, "crossing")
            // The union of position 0..1 and position 1..2 is 0..2: FOUR slots in the
            // strip (span + 3), of which the panel shows three at a time. The active
            // column is the one the workspace moved to.
            compare(body.plan.slots, 4, "a one-step crossing carries four slots")
            compare(body.plan.activeSlot, 2, "and the arriving one is the last slot")
            // An animation reads its start value on the frame it starts, so the
            // travel has to be sampled after the event loop has turned.
            wait(Math.round(body.slideDuration / 2))
            // Every workspace in the union is on the strip, once, with its own
            // windows: the frame being left (positions 0 and 1) and the one arriving
            // (position 2). Each is titled after its own position, so a title that
            // appears twice would be a workspace shown twice.
            var titles = shownTitles()
            for (var t = 0; t < titles.length; ++t) {
                var pos = titles[t]
                verify(titles.indexOf(pos) === t,
                    "workspace " + pos + " is on the strip once, not twice")
            }
            // The frame being left is still there, as content rather than as a
            // separate object: position 0 is the only column that could be carrying
            // it now.
            verify(titles.indexOf("ws0") >= 0,
                "the frame being left is still on the strip, saw " + titles.join(", "))
            verify(titles.indexOf("ws2") >= 0, "and the arriving frame is in place")
            // Rows travelling are not tap targets: what is under the pointer is
            // leaving, or has not arrived.
            var rows = findAllByName(strip(), "windowHintNeighbourRow")
            verify(rows.length > 0, "the strip has neighbour rows mid-crossing")
            verify(!rows[0].enabled, "a travelling row is not a tap target")

            settleSlide()
            compare(body.swapping, false)
            compare(body.plan.slots, 3, "and the strip is three columns again")
            var after = findAllByName(strip(), "windowHintWindowRow")
            compare(after.length, 1, "the new list has taken over")
            compare(after[0].modelData.title, "ws2")
            verify(after[0].enabled, "rows are tappable once landed")
        }

        function test_thePanelIsNeverLeftUncovered() {
            // The reason the strip carries more columns than the panel shows. A
            // strip exactly as wide as the panel would uncover a band at one end for
            // the length of the crossing, and a hole in a panel reads as a layout
            // fault rather than as motion. The strip is `span + 3` columns and
            // travels `span`, so there is always a full panel's worth of it under
            // the window.
            //
            // The claim is stated as the geometry the user would see: painted rows
            // have to reach the panel's left edge AND its right edge at every
            // sampled progress, in both directions, for every span. Read off the
            // real row rects mapped into the body, so a strip that is the right
            // width in the wrong place fails this rather than passing it.
            for (var span = 1; span <= 3; ++span) {
                for (var direction = 0; direction < 2; ++direction) {
                    var from = direction === 0 ? 1 : 4
                    var to = direction === 0 ? 1 + span : 4 - span
                    // Settle on the frame being LEFT first, so the crossing that
                    // follows really is the span under test. The hint the previous
                    // test left behind has its own active position, and a crossing
                    // measures from whatever was on screen.
                    body.hint = root.framedHint(from, from)
                    wait(20)
                    body.hint = root.framedHint(to, from)
                    compare(body.plan.span, span, "span " + span + " dir " + direction
                        + ": the plan agrees on the span")
                    compare(body.plan.slots, span + 3, "and on the column count")
                    for (var step = 0; step < 4; ++step) {
                        wait(Math.round(body.slideDuration / 4))
                        verify(panelEdgesReached(),
                            "span " + span + " dir " + direction + " step " + step
                                + ": the panel is covered, offset " + body.slideOffset)
                    }
                    settleSlide()
                    verify(panelEdgesReached(),
                        "span " + span + " dir " + direction + ": and once landed")
                }
            }
        }

        function test_theStripTravelsOnePassByExactlyTheSpan() {
            // The distance is the number of columns the workspace moved, in each
            // direction, once, without turning back. Read off the strip's real offset
            // rather than off the plan, so a plan that says one thing and a strip
            // that does another is caught here.
            for (var span = 1; span <= 3; ++span) {
                for (var direction = 0; direction < 2; ++direction) {
                    var from = direction === 0 ? 1 : 6
                    var to = direction === 0 ? 1 + span : 6 - span
                    // Settle on the frame being left, so the crossing is the span
                    // under test rather than whatever the previous test left.
                    body.hint = root.framedHint(from, from)
                    wait(20)
                    compare(strip().x, 0, "span " + span + " dir " + direction
                        + ": the strip rests at home")
                    compare(strip().width, 3 * body.columnPitch - body.columnGutter,
                        "as three columns")

                    body.hint = root.framedHint(to, from)
                    compare(strip().width, (span + 3) * body.columnPitch - body.columnGutter,
                        "span " + span + " dir " + direction
                            + ": and widens to the union while crossing")
                    // Towards a LATER workspace the strip travels left; earlier, it
                    // travels right. Getting this backwards would have the panel turn
                    // away from the direction the workspace went. The last sample is
                    // the landed one, which is at rest by definition - so the
                    // "one way only" claim is over the samples that are still moving.
                    // The distance travelled, in pixels, read off the two offsets the
                    // crossing interpolates between. The strip does not start at zero
                    // in both directions - a backward move starts it left of home, so
                    // that the frame being LEFT is the one under the panel at the
                    // start - so the claim is about the DISTANCE, not the endpoints.
                    compare(Math.abs(body.slideTo - body.slideFrom), span * body.columnPitch,
                        "span " + span + " dir " + direction
                            + ": the crossing travels exactly the span, was "
                            + Math.abs(body.slideTo - body.slideFrom))
                    // One way only, sampled while it is still moving. The last sample
                    // is the landed one, which is at rest by definition.
                    // Sampled only while the crossing is IN FLIGHT. Once it has
                    // landed, the strip narrows back to the arriving frame's three
                    // columns and its offset returns to 0 - so a sample taken after
                    // the landing reads as "it went backwards" when it did not. At
                    // `slideDuration / 5` per step the old loop ran past the end
                    // whenever the clock was short, because a `wait()` overshoots by
                    // however long the delegate rebuild takes.
                    var furthest = strip().x
                    var movingSamples = 0
                    var movedSamples = 0
                    for (var step = 0; step < 40 && body.swapping; ++step) {
                        wait(1)
                        if (!body.swapping)
                            break
                        var here = strip().x
                        // Never the wrong way. Not strictly monotonic per sample: the
                        // first tick can land before the animation has moved at all,
                        // and a sample that has not started yet is not a reversal.
                        verify(direction === 0 ? here <= furthest : here >= furthest,
                            "span " + span + " dir " + direction + " step " + step
                                + ": one way only, was " + here + " from " + furthest)
                        if (direction === 0 ? here < furthest : here > furthest)
                            movedSamples++
                        furthest = here
                        movingSamples++
                    }
                    verify(movedSamples > 0,
                        "span " + span + " dir " + direction
                            + ": and it was seen actually moving, "
                            + movingSamples + " samples")
                    // Landed: back at home, three columns, and the arriving frame's
                    // active column in the middle. The strip's own offset returns to
                    // 0 here because the resting plan says the active column is slot
                    // 1 - the panel's middle - so the travel is a property of the
                    // crossing, not a resting position.
                    settleSlide()
                    compare(strip().x, 0,
                        "span " + span + " dir " + direction + ": and it rests at home, was "
                            + strip().x)
                    compare(strip().width, 3 * body.columnPitch - body.columnGutter,
                        "as the arriving frame's three columns again")
                    compare(body.plan.slots, 3, "and the plan says three slots")
                    compare(body.plan.activeSlot, 1, "with the active column in the middle")
                }
            }
        }

        function test_theActiveWorkspaceHasTheWidgetsSlidingBackground() {
            // The bar's workspace widget draws the active workspace as one surface
            // behind the squares, covering a square exactly, with the square's content
            // inset inside it. This is that surface one size up.
            var band = findByName(body, "windowHintColumnHighlight")
            verify(band !== null, "the strip carries a background surface")
            if (!band)
                return
            compare(findAllByName(body, "windowHintColumnHighlight").length, 1,
                "exactly one, however many columns are on the strip")

            // The widget's own colour, so the panel and the bar agree.
            compare(band.color, Lazer.LazerTheme.activeFill, "in the widget's fill")

            // Square, like both surfaces in the widget: its hover highlight and its
            // active one are `radius: 0`. Stated as a literal rather than read from the
            // card or from the component, because the claim is about matching a
            // reference outside this file - a rounded band was tried and read as a slot
            // floating over the panel rather than as the column itself.
            compare(band.radius, 0,
                "square, like the widget's hover and active highlights, was "
                    + band.radius)

            // A child of the BODY, not of the strip. The strip travels and its active
            // slot moves; the band does not, because the column you are looking at
            // does not. As a strip child it teleported a whole column at the start of
            // a crossing and had to slide back.
            compare(band.parent, body, "anchored to the panel, not to the travelling strip")

            // Behind the cards, so it is a background and never an overlay on a title.
            var stripIndex = body.children.indexOf(findByName(body, "windowHintStrip"))
            verify(body.children.indexOf(band) < stripIndex,
                "and declared before the strip, so it paints behind the cards")

            // Under the pointer means nothing - it is decoration.
            verify(!band.enabled, "and inert to input")

            // The margin is the GAP BETWEEN COLUMNS, not a shrink of the band. The band
            // was inset 8px instead, which is backwards: that leaves the column's own
            // content overhanging the thing that marks it. The widget's highlight covers
            // exactly one square and the margin comes from the spacing between squares.
            verify(body.columnGutter > 0,
                "and the columns are separated, by " + body.columnGutter)
            compare(body.columnPitch, body.columnWidth + body.columnGutter,
                "the pitch is the column plus the gap")

            // A margin on every side, sized from the widget rather than picked.
            //
            // Measured from real cards, not from the focus highlight: that sits on
            // whichever row is current, so its top edge says nothing about the band's
            // margin. Only the ACTIVE column instantiates `windowHintWindowRow` - its
            // neighbours get plain labels - so every row found here belongs to the
            // column the band is on.
            //
            // The expected numbers live HERE, not read back from the component: a test
            // whose expected value is the component's own constant cannot tell "the
            // padding is there" from "the padding is gone" - with the padding at 0 it
            // compared 0 against 0 and passed either way. Stated here they have to be
            // argued with.
            //
            // Vertical is 12, because the widget's square is a fixed `barWidgetHeight`
            // of 42 with an 18px content row centred in it, leaving 12 above and below.
            //
            // Horizontal is 19, and that is NOT the widget's card padding any more: the
            // focus indicator lives in this padding now, so it holds a clearance, the
            // indicator and a clearance again. 8 and 8, so the marker is as far from
            // the band as the card is and as far from the card as the band is - one
            // padding in three places rather than three numbers that merely look close.
            var marginX = 8 + 3 + 8
            var marginY = 12
            var cards = findAllByName(body, "windowHintWindowRow")
            verify(cards.length > 0, "the active column has cards to measure against")
            if (cards.length > 0) {
                var top = cards[0].y
                var bottom = cards[0].y + cards[0].height
                for (var ci = 1; ci < cards.length; ++ci) {
                    if (cards[ci].y < top)
                        top = cards[ci].y
                    if (cards[ci].y + cards[ci].height > bottom)
                        bottom = cards[ci].y + cards[ci].height
                }
                // Both edges measured in the body's space: the cards are in the strip's
                // and the band is in the body's, so comparing a card's own y against the
                // band's would put a strip-relative number next to a body-relative one.
                var box = body
                var topCard = cards[0].mapToItem(box, 0, 0)
                var blockTop = topCard.y + top
                var blockBottom = topCard.y + bottom
                var blockLeft = topCard.x
                var blockRight = blockLeft + cards[0].width
                var bandBox = band.mapToItem(box, 0, 0)
                compare(blockTop - bandBox.y, marginY,
                    "margin above the first card, was " + (blockTop - bandBox.y))
                // The band's own height, not a mapped one: `mapToItem` returns a point.
                // Measured at rest, where the scale is 1, so the untransformed height is
                // the visual one.
                compare(band.height - (blockBottom - bandBox.y), marginY,
                    "and below the last, was " + (band.height - (blockBottom - bandBox.y)))
                compare(blockLeft - bandBox.x, marginX,
                    "and to the left of the cards, was " + (blockLeft - bandBox.x))
                compare(bandBox.x + band.width - blockRight, marginX,
                    "and to the right, was " + (bandBox.x + band.width - blockRight))
            }
        }

        function test_theBandHugsThePanelEdgeTheWayTheWidgetHugsTheBar() {
            // The other half of the widget's arrangement, and the half that was
            // backwards. `Workspaces.activeHighlight` is `barWidgetHeight` tall, and
            // `barWidgetHeight` is `barLiveHeight - barWidgetGutter * 2` - so the band
            // sits `barWidgetGutter` from the BAR's edge while its content sits
            // `cellPadding` inside it. The panel had those the wrong way round: a 2px
            // inner margin and an outer edge 10px in.
            //
            // 3 is `LazerTheme.barWidgetGutter`, read off the theme rather than
            // restated, because the claim is about agreeing with a token.
            var band = findByName(body, "windowHintColumnHighlight")
            if (!band)
                return
            // Declared as the host declares it. Mounted on its own the body has no host
            // inset, and then "near the panel's edge" and "near the body's edge" are the
            // same measurement - and the band's whole point is that the two differ,
            // since it deliberately reaches past the body into the popup's inset.
            body.surfaceInset = 8
            compare(band.y + body.surfaceInset, Lazer.LazerTheme.barWidgetGutter,
                "the band's top edge is the gutter from the panel's, was "
                    + (band.y + body.surfaceInset))
            compare(body.height - (band.y + band.height) + body.surfaceInset,
                Lazer.LazerTheme.barWidgetGutter,
                "and its bottom edge, was "
                    + (body.height - (band.y + band.height) + body.surfaceInset))
            // Which means the band reaches past the body's own edge, into the popup's
            // content inset - otherwise it could not be near the panel's edge at all.
            verify(body.surfaceInset > Lazer.LazerTheme.barWidgetGutter,
                "so the band does reach past the body's edge, inset is "
                    + body.surfaceInset)
            verify(band.y < 0,
                "and it does, band y is " + band.y)
            body.surfaceInset = 0
        }

        function test_theBandDoesNotTeleportAcrossACrossing() {
            // The defect this pins down, measured rather than reasoned about: with the
            // band glued to the strip's active SLOT it sat at 186px at rest and at
            // 347px on the first frame of a crossing - a 161px jump in one frame -
            // then slid the rest of the way back. A test written for the earlier
            // arrangement asserted that jump as the contract.
            //
            // The band is anchored to the panel's middle column, which is where the
            // active column always is, so the claim is simply that it does not move:
            // sampled across a whole crossing, in panel coordinates, in both
            // directions, it must stay put to within a pixel.
            var band = findByName(body, "windowHintColumnHighlight")
            if (!band)
                return
            for (var direction = 0; direction < 2; ++direction) {
                var from = direction === 0 ? 5 : 6
                var to = direction === 0 ? 6 : 5
                body.hint = root.framedHint(from, from)
                wait(60)
                var home = band.mapToItem(body, 0, 0).x
                compare(home, body.columnPitch,
                    "dir " + direction + ": at rest it is the middle column, was " + home)

                // The band's CENTRE, not its left edge: `mapToItem` folds in the
                // scale, and the crossing deliberately pulses the band by 2%, which
                // moves the mapped left edge by about 1.8px without the band going
                // anywhere. A uniform scale cannot move a centre, so this measures
                // translation alone.
                function centreX() {
                    return band.mapToItem(body, band.width / 2, 0).x
                }
                var lowest = centreX()
                var highest = lowest
                body.hint = root.framedHint(to, from)
                for (var step = 0; step < 24; ++step) {
                    wait(8)
                    var here = centreX()
                    lowest = Math.min(lowest, here)
                    highest = Math.max(highest, here)
                }
                settleSlide()
                lowest = Math.min(lowest, centreX())
                highest = Math.max(highest, centreX())
                verify(highest - lowest <= 1,
                    "dir " + direction + ": it never moves, over "
                        + (highest - lowest) + "px")
            }
        }

        function test_theBandPulsesOnTheCrossingsOwnClock() {
            // The scale is a pure function of `slideProgress`, so it cannot drift from
            // the slide: there is one clock and this is read off it. Asserted as an
            // observation of the sampled scale rather than as the recipe, because the
            // recipe is one line and the thing worth protecting is that the pulse
            // actually peaks while the crossing is in flight and is gone afterwards.
            var band = findByName(body, "windowHintColumnHighlight")
            if (!band)
                return
            body.hint = root.framedHint(5, 5)
            wait(80)
            compare(band.scale, 1, "and at rest it is not scaled, was " + band.scale)

            var peak = 1
            body.hint = root.framedHint(6, 5)
            for (var step = 0; step < 20; ++step) {
                wait(8)
                peak = Math.max(peak, band.scale)
            }
            verify(peak > 1,
                "and it swells mid-crossing, peaked at " + peak.toFixed(3))
            // Shallow: 2% of a 180px column is under 4px, which reads as a pulse. A
            // larger factor reads as a zoom, and at a factor big enough to matter it
            // would cross the gutter and touch a neighbour's cards.
            verify(peak <= 1.05, "but only a little, peaked at " + peak.toFixed(3))
            settleSlide()
            compare(band.scale, 1, "and it settles back, was " + band.scale)
        }

        function test_theCrossingRunsOnTheWorkspacesHighlightCurve() {
            // One ease, on the workspace widget's active-highlight recipe.
            //
            // `Workspaces.qml`'s `activeHighlight` slides on `MotionTokens.medium`
            // with `Easing.OutQuad`, and this panel is that widget's run of columns
            // at three times the size - so the list and the highlight it now carries
            // have to arrive together, or they read as two things happening at once.
            // Read off the animation itself rather than off the tokens it was written
            // from: a test that reads `MotionTokens.medium` only proves a number
            // exists somewhere in the file.
            compare(body.slideAnimation.to, 1, "one traverse, start to end")
            compare(body.slideAnimation.duration, Lazer.MotionTokens.medium,
                "on the workspace highlight's clock, was " + body.slideAnimation.duration)
            compare(body.slideAnimation.easing.type, Easing.OutQuad,
                "and the workspace highlight's curve")
            compare(body.slideDuration, body.slideAnimation.duration,
                "with the declared total matching the one animation")

            // ONE phase. This is the assertion that carries the request: the crossing
            // used to be a departure and a settle run in sequence, borrowing the
            // workspace INDICATOR's two-speed shape. That indicator's head and tail
            // are two positions running in PARALLEL, so its shape comes free; a
            // crossing has one position, so the phases had to run one after the
            // other, and the handover between them is a visible change of gear
            // halfway across. That cannot recur while there is no seam to hand over
            // at.
            verify(!body.slideAnimation.hasOwnProperty("animations")
                || body.slideAnimation.animations.length === 0,
                "and no second phase to hand over to")

            // The span must not change the clock: a three-column jump covers the same
            // 160ms and arrives three times as fast, which is what a fixed settle
            // rhythm means.
            compare(body.slideDuration, Lazer.MotionTokens.medium,
                "and the clock is the same whatever the span")
            verify(body.hasOwnProperty("slideDip"), "and it still dims a little in the middle")
        }

        function test_theStripDipsOnceInTheMiddleAndNoFurther() {
            // The softening dim, on the one object that moves. It is shallow on
            // purpose: enough to register as weight, far too little to read as a
            // fade. And it is a property of the progress alone, so the same progress
            // always gives the same value - a dip that varied along the travel would
            // make some parts of the panel dimmer than others for no visible reason.
            compare(strip().opacity, 1, "undimmed at rest")
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 2,
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            // Sampled at the middle, where the dip is deepest. `duration / 2` is
            // only approximate, so this reads the value rather than assuming the
            // sample landed exactly on the peak.
            wait(Math.round(body.slideDuration / 2))
            verify(strip().opacity < 1, "it has dipped, was " + strip().opacity)
            verify(strip().opacity > 0.8, "but only slightly, was " + strip().opacity)
            verify(strip().opacity > 0, "and never to nothing")
            // The same progress must give the same value, so the dim is a function of
            // the clock and not a per-frame decision.
            compare(strip().opacity, 1 - body.slideDip,
                "and it is the clock's own value, not a sampled one")
            settleSlide()
            compare(strip().opacity, 1, "and full again once landed")
        }

        function test_aRefreshWithNoMovementDoesNotCancelTheCrossing() {
            // The regression that made every retune of this traverse invisible.
            //
            // niri sends a second refresh about 40ms after the activation, because
            // the window list changes as the new workspace comes up. The service has
            // already advanced its record of the active workspace by then, so that
            // snapshot carries the SAME position on both sides - it reads as "nothing
            // moved" while a crossing is on screen showing that something very much
            // did. Committing on it ended the crossing a few frames in.
            //
            // It is asserted as a state, not as elapsed time, so it does not depend
            // on how fast the offscreen platform happens to tick.
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 2,
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            verify(body.swapping, "the activation starts a crossing")
            wait(Math.round(body.slideDuration / 4))
            verify(body.slideProgress > 0 && body.slideProgress < 1,
                "which is under way, was " + body.slideProgress)
            var before = body.slideProgress

            // The follow-up publish: same workspace on both sides, fresh content.
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 3,
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            verify(body.slideProgress < 1,
                "and the follow-up refresh does not snap it to the end, was "
                    + body.slideProgress + " from " + before)
            verify(body.swapping, "so it is still crossing")
            // And it carries on rather than restarting: the value moved forward.
            wait(Math.round(body.slideDuration / 8))
            verify(body.slideProgress > before,
                "and keeps going forward, was " + body.slideProgress + " from " + before)
            settleSlide()
            compare(body.slideProgress, 1, "and lands on its own clock")
        }

        function test_aMoveTooWideToDescribeCommitsRatherThanInventingAColumn() {
            // The strip is the ordered union of the two frames' workspaces, and two
            // three-column frames only tile a contiguous run while the move is no
            // wider than the two frames together. Four steps apart they do not: the
            // middle columns belong to neither snapshot.
            //
            // A strip cannot have a column whose contents nothing knows, and filling
            // it with an empty placeholder would report "no windows" about workspaces
            // nobody looked at. So a move that wide is a replacement, not a crossing -
            // and it must commit cleanly, showing the destination's own frame.
            body.hint = root.framedHint(1, 1)
            wait(20)
            body.hint = root.framedHint(5, 1)
            compare(body.swapping, false, "no crossing: the move is too wide to describe")
            compare(body.plan.span, 0, "and the plan is the resting one, was "
                + body.plan.span)
            compare(body.plan.slots, 3, "three columns")
            compare(strip().x, 0, "and the strip is at home")
            // The destination is shown, whole: its own workspace in the middle.
            var landed = shownTitles()
            compare(landed.indexOf("ws5") >= 0, true, "the destination is on screen")
            compare(landed.indexOf("ws4") >= 0, true, "with its previous workspace beside it")
            compare(landed.indexOf("ws6") >= 0, true, "and its next workspace")
            compare(repeatedTitles().length, 0, "and nothing is on screen twice")
            // And the threshold is not arbitrary: the widest move that DOES cross is
            // one column narrower, and it does animate.
            body.hint = root.framedHint(1, 1)
            wait(20)
            body.hint = root.framedHint(4, 1)
            compare(body.swapping, true, "three steps still crosses")
            compare(body.plan.span, 3, "and carries the full union")
            compare(body.plan.slots, 6, "of six slots")
            settleSlide()
        }

        function test_aRefreshWithNoMovementAndNoCrossingStillCommits() {
            // The other half of the same decision, so the guard above cannot be
            // satisfied by never committing anything: a title edit on the workspace
            // already shown is not a page turn, and must not animate.
            body.hint = root.makeHint({
                activeWorkspacePosition: 1,
                previousActiveWorkspacePosition: 1,
                windows: [{ windowId: "21", title: "renamed", appId: "kitty", icon: "", isFocused: true }]
            })
            verify(!body.swapping, "nothing is crossing")
            compare(body.slideProgress, 1, "and it commits straight away")
            compare(body.plan.slots, 3, "with the strip back to three columns")
            compare(body.leavingHint, null, "and nothing held on the way out")
            wait(Math.round(body.slideDuration / 2))
            compare(body.slideProgress, 1, "and never starts one afterwards")
        }

        function test_theSlideIsOnePassAndDoesNotTurnBack() {
            // Progress runs 0 to 1 once. A value that overshot and came back would
            // be a bounce, and the whole point of one strip is that the motion is a
            // single displacement.
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 2,
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            var furthest = 0
            for (var step = 0; step < 5; ++step) {
                wait(Math.round(body.slideDuration / 5))
                // Monotonic: each sample is at least as far along as the last.
                verify(body.slideProgress >= furthest,
                    "step " + step + " went backwards, was " + body.slideProgress)
                furthest = body.slideProgress
            }
            settleSlide()
            compare(body.slideProgress, 1, "and it finishes at rest")
        }

        function test_swapTravelsTheWayTheWorkspaceMoved() {
            // The direction is the workspace move, and the plan's slots follow it: a
            // later workspace's frame sits to the RIGHT of the one being left, so its
            // active column is the LAST slot and the strip travels leftwards to bring
            // it to the middle. Earlier, the mirror - first slot, travel rightwards.
            // Getting this backwards would have the panel turn away from the
            // direction the workspace went.
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 2,
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            // Settle on the frame being left first, or the crossing measures from
            // whatever the previous test left on screen rather than from this move.
            body.hint = root.framedHint(2, 2)
            wait(20)
            body.hint = root.framedHint(3, 2)
            compare(body.swapDirection, 1, "moved later in the list")
            compare(body.plan.activeSlot, 2, "so the arriving frame is the last slot")
            verify(body.plan.endColumn < 0, "and the strip travels leftwards")
            settleSlide()

            body.hint = root.framedHint(3, 3)
            wait(20)
            // A ONE-step move backwards. The two cases are not mirror images in the
            // strip's own slot numbering, and the difference is worth stating rather
            // than glossed: forwards the arriving active column is the strip's LAST
            // slot (span + 1), backwards it is the MIDDLE one. Both end with it in the
            // panel's middle column - the forward case by travelling left to it, the
            // backward one by travelling right - which is the claim that matters.
            body.hint = root.framedHint(2, 3)
            compare(body.swapDirection, -1, "moved earlier in the list")
            compare(body.plan.slots, 4, "a one-step crossing carries four slots")
            compare(body.plan.activeSlot, 1, "the arriving active column is already the middle slot")
            verify(body.plan.startColumn < 0, "and the strip starts left of home")
            verify(body.plan.endColumn > body.plan.startColumn,
                "travelling rightwards to bring it to the middle, was "
                    + body.plan.startColumn + " to " + body.plan.endColumn)
            settleSlide()
            // And the resting panel is whole again whichever way it was left.
            compare(strip().x, 0, "the strip rests at home")
            compare(strip().width, body.width, "and fills the panel")
        }

        // ---- the duplication this crossing used to have --------------------
        function test_noWindowIsPaintedTwiceWhileTheStripTravels() {
            // The regression. A workspace switch used to translate the two copies
            // a whole panel width past each other, which is the right motion for a
            // panel whose pages are disjoint - and this one's are not. The panel is
            // a three-column frame of CONSECUTIVE workspaces, so the frame being
            // left and the frame being arrived at share two of their three
            // columns. A page turn of two overlapping frames therefore puts the
            // shared workspace on screen twice, once as the card column of the
            // frame being left and once as a neighbour column of the frame being
            // arrived at - which the user reads as duplicated window-title cards.
            //
            // Measured with a probe replaying the publishes WindowHintService makes
            // for one activation, sampling every 40ms across the whole crossing
            // which titles were actually inside the panel:
            //
            //   forward  1->2   22 of 24 samples had a title painted twice (41)
            //   backward 2->0   22 of 24 samples had a title painted twice (44)
            //
            // The rule is stated about the panel's contents, not about the arithmetic
            // that produces them: no window title may be inside the panel twice at
            // any point of a crossing. The snapshots below are chosen so the two
            // frames SHARE two workspaces - the resting frame's active workspace is
            // the arriving frame's previous one, which is exactly the pair the old
            // page turn put side by side.
            //
            // Swept over every span and both directions, and with a second switch
            // injected mid-crossing, because the one-off case is not the hard one:
            // a strip that is correct for a single crossing can still duplicate the
            // moment a second one re-aims it, since the held frame is then relative
            // to a different active workspace than the one being left.
            for (var span = 1; span <= 3; ++span) {
                for (var direction = 0; direction < 2; ++direction) {
                    // Every workspace's windows titled after its own position, so a
                    // repeated title names the workspace that repeated.
                    for (var mid = 0; mid < 2; ++mid) {
                        test.crossingIsDuplicateFree(span, direction, mid)
                    }
                }
            }
        }

        // One crossing of the given span and direction, with a second switch injected
        // partway through when `reAim` is set. Asserts the no-duplication rule at
        // eight points across the travel and again once landed.
        function crossingIsDuplicateFree(span, direction, reAim) {
            var from = direction === 0 ? 1 : 6
            var to = direction === 0 ? 1 + span : 6 - span
            var label = "span " + span + " dir " + direction + (reAim ? " re-aim" : "")
            // Settle on the starting frame, with every workspace around it named.
            body.hint = root.framedHint(from, from)
            wait(20)
            compare(shownTitles().length > 0, true, label + ": the starting frame is on screen")

            body.hint = root.framedHint(to, from)
            var destination = to
            if (reAim) {
                // A second switch, a third of the way in, in the SAME direction as
                // the first: the common case, holding mod and arrowing twice.
                wait(Math.round(body.slideDuration / 3))
                destination = to + (direction === 0 ? 1 : -1)
                body.hint = root.framedHint(destination, to)
            }
            var steps = 8
            for (var step = 0; step < steps; ++step) {
                wait(Math.round(body.slideDuration / steps))
                var repeated = repeatedTitles()
                compare(repeated.length, 0, label + " step " + step + " (progress "
                    + body.slideProgress.toFixed(2) + ", offset " + body.slideOffset
                    + "): " + repeated.join(", ") + " on screen more than once")
            }
            settleSlide()
            compare(repeatedTitles().length, 0, label + ": and once landed")
            // And it landed ON the frame the crossing was aimed at - which is what
            // makes "no duplicate" the right answer rather than "no content at all".
            compare(body.plan.activeSlot, 1, label + ": the resting panel's active slot")
            var landed = shownTitles()
            compare(landed.indexOf("ws" + destination) >= 0, true,
                label + ": the destination workspace's own window is on screen")
        }

        function test_onlyTheActiveColumnCarriesTheFocusMarkers() {
            // Focus belongs to the workspace you are moving to, and the markers
            // belong to the ARRIVING frame's active column. There is one strip and
            // one pair of markers, so the claim is that they sit on the column the
            // plan calls active - not on the panel's middle, which is where that
            // column is only at the end of the crossing.
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 2,
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            wait(Math.round(body.slideDuration / 2))
            compare(findAllByName(live(), "windowHintFocusFrame").length, 1,
                "one highlight, mid-crossing")
            compare(findAllByName(live(), "windowHintFocusIndicator").length, 1,
                "and one indicator")
            // Mid-crossing the arriving active column is still off to the side, and
            // the markers are on it rather than pinned to the panel.
            compare(body.plan.activeSlot, 2, "the arriving column is the last slot")
            compare(findByName(live(), "windowHintFocusFrame").x,
                2 * body.columnPitch + body.cellPaddingX,
                "and the markers are placed against it, inside its padding")
            settleSlide()
            // Landed: it is the middle column, which is the same claim the resting
            // panel makes everywhere else.
            compare(body.plan.activeSlot, 1, "at rest the active column is the middle")
            compare(findByName(live(), "windowHintFocusFrame").x,
                body.columnPitch + body.cellPaddingX,
                "at rest, inside the middle column's padding")
        }

        function test_theMarkersTravelWithTheContentTheyMark() {
            // The markers are children of the strip, so they cross with the column
            // they are on. Read in STRIP space, where the marker and the row share a
            // parent chain, so the assertion is about the pairing rather than about
            // an absolute position a translation would have to be added to.
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 2,
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            wait(Math.round(body.slideDuration / 2))
            var wash = findByName(strip(), "windowHintFocusFrame")
            var bar = findByName(strip(), "windowHintFocusIndicator")
            // The row they mark, in the same space.
            var row = findAllByName(strip(), "windowHintWindowRow")[0]
            var rowInStrip = row.mapToItem(strip(), 0, 0)
            compare(wash.x, rowInStrip.x, "the highlight sits on its row mid-crossing")
            compare(wash.x - (bar.x + bar.width), 8,
                "and the indicator keeps its 8px clearance outside the outline")
            settleSlide()
        }

        function test_theWholeStripTravelsNotJustTheActiveColumn() {
            // Every column moves together, so the switch reads as one motion across
            // the panel. If only the active column travelled, the neighbours would
            // sit still while the middle slid and the switch would read as two
            // unrelated changes. There is one strip, so the claim is that its columns
            // keep their slots relative to each other while it is displaced.
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 2,
                previousWindows: [{ windowId: "p1", title: "p1", icon: "", isFocused: false }],
                nextWindows: [{ windowId: "n1", title: "n1", icon: "", isFocused: false }],
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            wait(Math.round(body.slideDuration / 2))
            var columns = columnDelegates()
            compare(columns.length, 4, "a two-step crossing carries four columns")
            for (var i = 0; i < columns.length; ++i) {
                compare(columns[i].x, i * body.columnPitch,
                    "column " + i + " holds its slot mid-crossing")
            }
            settleSlide()
            // Landed: each neighbour slot shows what the new snapshot says for it
            // rather than a stale list.
            var neighbours = findAllByName(live(), "windowHintNeighbourRow")
            compare(neighbours.length, 2)
            compare(neighbours[0].modelData.windowId, "p1")
            compare(neighbours[1].modelData.windowId, "n1")
        }

        // Where each workspace's row sits across the panel, as title -> x. Read from
        // the live rows, so it is what the user would see rather than a number the
        // component computed about itself. Off-panel rows are left out, because a
        // workspace that has not arrived yet has no position to hold.
        function contentPositions() {
            var positions = {}
            // Rooted at the body, so a layout with more than one strip is measured
            // for what it actually shows rather than for one of its parts.
            var rows = findAllByName(body, "windowHintWindowRow")
                .concat(findAllByName(body, "windowHintNeighbourRow"))
            for (var i = 0; i < rows.length; ++i) {
                var row = rows[i]
                if (!row.modelData || row.modelData.title === undefined)
                    continue
                var from = row.mapToItem(body, 0, 0).x
                if (from + row.width <= 0 || from >= body.width)
                    continue
                positions[String(row.modelData.title)] = from
            }
            return positions
        }

        // Every workspace that was on the panel is still within a pixel of where it
        // was. This is the claim that matters for a re-aim: the strip's own offset is
        // ALLOWED to change, because renumbering its slots legitimately moves it, so
        // only the content's position can say whether the user saw a jump.
        function assertContentHeld(before, label) {
            var after = contentPositions()
            for (var title in before) {
                if (!(title in after))
                    continue
                verify(Math.abs(after[title] - before[title]) <= 1,
                    label + ": " + title + " stayed put, was at " + before[title]
                        + " and is at " + after[title])
            }
        }

        function test_aSwitchMidSlideReAimsWithoutMovingWhatIsOnScreen() {
            // Holding mod and arrowing twice quickly lands a second switch while the
            // first is still crossing. This is the case that has to be derived rather
            // than stumbled into, and it has two halves.
            //
            // The MOTION continues from where the strip is, rather than from the new
            // plan's own start offset - a restart would throw the content back to the
            // edge of the panel. And the strip's slots are renumbered, because a move
            // that extends the union at the right adds columns without disturbing the
            // ones already held; where a re-aim does renumber them, the offset is
            // corrected by the same amount - see the reversal test below. Either way
            // the assertion is about the CONTENT, because that is what the user sees,
            // and the strip's own x is an internal number that is allowed to change.
            for (var direction = 0; direction < 2; ++direction) {
                // The second and third destinations. Forward takes 1 -> 2 -> 3;
                // backward 5 -> 4 -> 3, so the two runs finish on the same workspace
                // and a landing in the wrong place cannot pass for the other case.
                var first = direction === 0 ? 1 : 5
                var second = direction === 0 ? 2 : 4
                var third = direction === 0 ? 3 : 3
                body.hint = root.framedHint(first, first)
                wait(20)
                body.hint = root.framedHint(second, first)
                wait(Math.round(body.slideDuration / 2))
                var before = contentPositions()
                var moved = 0
                for (var t in before) {
                    if (Math.abs(before[t]) > 1)
                        moved++
                }
                verify(moved > 0, "direction " + direction
                    + ": the strip is mid-flight, so what follows is about a moving panel")

                // The second switch, in the same direction: the common case.
                body.hint = root.framedHint(third, second)
                // No event-loop turn between the publish and the read, so a strip sent
                // back to its start shows up here rather than a frame later.
                assertContentHeld(before, "direction " + direction + " re-aim")
                verify(body.swapping, "direction " + direction + ": and it is still crossing")
                compare(body.plan.span, 1, "direction " + direction
                    + ": re-aimed at the new one-step move")
                // The arriving column is at the far end of the strip from where the
                // first crossing's arriving column was, because the destination moved
                // a second step in the same direction.
                compare(body.plan.activeSlot, direction === 0 ? 2 : 1,
                    "direction " + direction + ": with the arriving column where the plan says, was "
                        + body.plan.activeSlot)

                settleSlide()
                // It landed on the SECOND destination, and the resting panel is the
                // arriving frame alone.
                compare(body.plan.slots, 3, "direction " + direction + ": three columns at rest")
                compare(body.leavingHint, null, "direction " + direction + ": nothing held")
                var landed = shownTitles()
                compare(landed.indexOf("ws" + third) >= 0, true,
                    "direction " + direction + ": the second destination is the one on screen")
                compare(repeatedTitles().length, 0,
                    "direction " + direction + ": and nothing is on screen twice")
            }
        }

        function test_aSwitchMidSlideReversingDirectionKeepsTheContentStill() {
            // The other direction, and the case that renumbers the strip. Arriving
            // back past where the crossing came from extends the union at the LEFT, so
            // every column the strip already holds moves up a slot - and the strip
            // has to shift left by exactly that much, or the content on screen
            // teleports sideways on the frame the second switch lands.
            //
            // The move chosen is 1 -> 2 then back to 0, because it is the one where
            // the two plans' bases genuinely differ: reversing onto 1 would land on
            // the same run of workspaces and need no correction at all, which is a
            // real case but a vacuous one to assert against.
            body.hint = root.framedHint(1, 1)
            wait(20)
            body.hint = root.framedHint(2, 1)
            wait(Math.round(body.slideDuration / 2))
            var before = contentPositions()
            var held = 0
            for (var t in before)
                held++
            verify(held > 0, "there is content on the panel to hold still")

            // Reverse, past the origin: the opposite direction, and a new base.
            body.hint = root.framedHint(0, 2)
            assertContentHeld(before, "reversal")
            verify(body.swapping, "and it is still crossing")
            verify(body.plan.base !== 0, "and the strip really was renumbered, base is "
                + body.plan.base)
            // Still one column per position, which is what keeps the reversal from
            // being the moment the duplication comes back.
            compare(body.plan.slots, body.plan.span + 3, "one column per position")
            compare(repeatedTitles().length, 0, "and nothing is on screen twice")

            settleSlide()
            compare(body.plan.slots, 3, "three columns at rest")
            compare(shownTitles().indexOf("ws0") >= 0, true, "it landed back at 0")
            compare(repeatedTitles().length, 0, "and nothing is on screen twice")
        }

        function test_sameWorkspaceRefreshCommitsWithoutAnimating() {
            // A window title change republishes the snapshot without moving the
            // workspace. There is no direction to travel, so animating would be
            // motion for its own sake.
            body.hint = root.makeHint({
                activeWorkspacePosition: 1,
                previousActiveWorkspacePosition: 1,
                windows: [
                    { windowId: "10", title: "kitty", appId: "kitty", icon: "", isFocused: true },
                    { windowId: "11", title: "renamed", appId: "kitty", icon: "", isFocused: false }
                ]
            })
            compare(body.swapping, false, "committed straight away")
            compare(body.leavingHint, null, "and held nothing")
            var rows = findAllByName(live(), "windowHintWindowRow")
            compare(rows.length, 2, "already the new list")
            compare(findByName(live(), "windowHintWindowTitle").text, "kitty")
            verify(rows[1].enabled, "and tappable")
        }

        function test_reducedMotionCommitsWithoutSliding() {
            // Reduced motion means the swap is a replacement, not a displacement. The
            // strip is the arriving frame's own three columns from the first frame -
            // a wider strip with no motion would show the leaving columns sitting
            // beside the arriving ones, which is the duplication this whole change is
            // about.
            Lazer.MotionTokens.reducedMotionOverride = true
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 1,
                windows: [
                    { windowId: "a", title: "a", appId: "kitty", icon: "", isFocused: true },
                    { windowId: "b", title: "b", appId: "kitty", icon: "", isFocused: false }
                ]
            })
            compare(body.swapping, false, "no crossing to wait for")
            compare(body.leavingHint, null, "and nothing was held")
            // The strip is three columns, so the leaving workspaces are not sitting
            // beside the arriving one.
            compare(body.plan.slots, 3, "the strip is the arriving frame alone")
            compare(repeatedTitles().length, 0, "and nothing is on screen twice")
            var rows = findAllByName(live(), "windowHintWindowRow")
            compare(rows.length, 2)
            verify(rows[0].opacity > 0.9, "rows are visible, was " + rows[0].opacity)
            verify(rows[1].opacity > 0.9, "all of them, was " + rows[1].opacity)
            verify(rows[0].enabled, "and tappable")
        }

        // ---- switching while held ---------------------------------------
        function test_workspaceSwitchUpdatesTheRowsInPlace() {
            body.hint = root.makeHint({
                workspaceId: "43",
                workspaceIndex: 3,
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            wait(20)
            settleIndicator()
            // The same body instance keeps rendering; nothing is rebuilt around
            // a new popup, which is what keeps the hold from flickering.
            var rows = findAllByName(live(), "windowHintWindowRow")
            compare(rows.length, 1)
            // The list is now a different workspace's single window, so the
            // highlight has to follow rather than stay where the old rows were.
            var frame = findByName(live(), "windowHintFocusFrame")
            compare(frame.y, 0, "highlight sits on the only row")
            compare(frame.height, rows[0].height)
        }
    }
}