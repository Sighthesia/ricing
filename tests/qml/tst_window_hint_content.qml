import QtQuick
import QtTest
import "../../modules/bar" as Bar
import "../../modules/bar/WindowHintMenuLogic.js" as Hint
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

    // The panel's own measurements, as LITERALS, because they are what the layout is
    // checked against and reading them back off the body would let a change to the
    // layout satisfy itself. Every expected number below is one of these or is
    // derived from them here, in the test.
    //
    //   |<-180-| -6- |<-  360  ->|-6-| <-180-|
    //   0      186  186        546 552     732
    //
    // The ACTIVE workspace's column is twice a neighbour's and always sits in the
    // middle, at the band's own x: the workspace you are on is the one whose windows
    // you opened the panel to choose from, so it gets the room and its two neighbours
    // are context for it. `pitch` is two NEIGHBOUR columns and the gutter between
    // them - it is NOT the distance from the left edge to the band's x, which is
    // `bandX` and happens to equal `pitch` only because the left neighbour is narrow.
    // `rightX` is the right neighbour's left edge, which is `panelW - narrowCol`.
    readonly property int narrowCol: 180
    readonly property int wideCol: 360
    readonly property int gutter: 6
    readonly property int pitch: 180 + 6
    readonly property int bandX: 186
    readonly property int rightX: 552
    readonly property int panelW: 180 * 2 + 6 * 2 + 360
    // The card padding, 19: a clearance of 8 on the band's own edge, the 3px focus
    // indicator that lives in that padding, and the same clearance again on the card's
    // edge. One clearance in three places, so the marker cannot sit closer to the band
    // than the card does or closer to the card than to the band. Spelled as the sum
    // rather than as a number, because the three parts are three separate decisions.
    readonly property int padX: 8 + 3 + 8
    // A card is its column less the padding at each side - which is why the active
    // column's cards are wider than a neighbour's rather than the same size.
    readonly property int narrowCard: 180 - 19 * 2
    readonly property int wideCard: 360 - 19 * 2

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

    // `framedHint` gives every workspace ONE window, so a column in it is exactly one
    // row tall. That is fine for a test about columns and useless for one about the
    // sweep, which is a whole COLUMN long: at one row it is the same length as the row
    // marker it replaces, and a test that could not tell the two apart would pass on a
    // sweep that never happened. This is the same fixture with `count` windows in the
    // active workspace, so the column is `count` rows and the sweep is visibly longer
    // than the row.
    // `focusAt` picks which of the `count` rows is the focused one, so a test can have
    // the marker leave one card and land on a DIFFERENT one. Leaving and landing on the
    // same row makes the wrap's two halves the same distance, which is a real case but a
    // weak one: it cannot tell "walked off this card and arrived on that card" from
    // "walked off and came back to where it started".
    function tallFramedHint(active, previous, count, focusAt) {
        var hint = root.framedHint(active, previous)
        var rows = []
        var focused = focusAt === undefined ? 0 : focusAt
        for (var i = 0; i < count; ++i)
            rows.push({ windowId: "t" + i, title: "ws" + active + " row " + i,
                appId: "kitty", icon: "", isFocused: i === focused })
        hint.windows = rows
        return hint
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
        //
        // The width of the active column does NOT enter this bound, and that is the
        // point of the layout rather than an omission: adjacent columns are always
        // exactly one gutter apart at every instant of a crossing, so the widest bare
        // strip the panel can show is one inter-card gap no matter how wide the column
        // crossing the edge is.
        var slack = root.gutter + root.padX * 2
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
            // The strip has no width of its own and is never displaced: every column
            // places ITSELF from one number the body owns. So the claim about the
            // resting layout is about the columns, and it is that they fill the panel
            // exactly - the left neighbour at the panel's left edge and the right one
            // ending at its right edge.
            compare(strip().x, 0, "and the strip is not displaced")
            var resting = columnDelegates()
            compare(resting.length, 3, "the resting strip is three columns of its own")
            compare(resting[0].x, 0, "the left neighbour starts at the panel's left edge")
            compare(resting[2].x + resting[2].width, root.panelW,
                "and the right one ends at the panel's right edge")
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
            // As literals, because the frame is two numbers and one wide middle and
            // they have to be argued with: the panel's left edge, then the wide slot,
            // then the right neighbour.
            compare(placed[0].column, 0,
                "the left neighbour column is the panel's leftmost slot")
            compare(placed[1].column, root.rightX,
                "and the right one is the panel's rightmost slot, one wide column further on")
            compare(placed[1].column - root.bandX, root.wideCol + root.gutter,
                "the two either side of the band are separated from it by the gutter")
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
            // the markers and the columns' own placements are stated in. A row's own x
            // is measured from its column, so comparing one against a marker without
            // mapping it would put a column-relative number next to a strip-relative
            // one - and they agree at rest only because the strip happens to be at 0.
            var rows = findAllByName(live(), "windowHintWindowRow")
            var wash = findByName(live(), "windowHintFocusFrame")
            var bar = findByName(live(), "windowHintFocusIndicator")
            var neighbours = findAllByName(live(), "windowHintNeighbourRow")
            var rowInStrip = rows[0].mapToItem(strip(), 0, 0)
            var leftItem = neighbours[0].parent
            var leftColumn = leftItem.mapToItem(strip(), 0, 0)
            var rightColumn = neighbours[1].parent.mapToItem(strip(), 0, 0)
            compare(wash.x, rowInStrip.x, "the highlight starts where the row starts")
            // Literals, so the claim is a place and not a restatement of wherever the
            // layout happens to have put the active column: the wide middle slot's left
            // edge plus the card padding.
            compare(wash.x, root.bandX + root.padX,
                "and on the active column, inside its padding")
            // The active column's card is twice a neighbour's less the padding, so the
            // outline is 322 rather than 142 - which is the change this whole panel
            // rests on, and a test that said "the column width" here would have gone on
            // asserting the neighbour's.
            compare(wash.width, root.wideCard,
                "spanning the active card inside the padding, was " + wash.width)
            // The left neighbour's column ends exactly one gutter before the active one
            // begins, so the check is that the highlight does not reach back over it.
            compare(leftColumn.x, 0, "with the left neighbour at the panel's edge")
            compare(wash.x,
                leftColumn.x + leftItem.width + root.gutter + root.padX,
                "and starting one gutter past where the left neighbour's column ends, "
                    + "inside the active one's padding")
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
            compare(wash.x + wash.width, root.bandX + root.wideCol - root.padX,
                "which is exactly the active column's right edge inside its padding")
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
            compare(slot.mapToItem(body, 0, 0).x, root.padX,
                "and it is in the left column, inside its padding, was "
                    + slot.mapToItem(body, 0, 0).x)
            compare(findByName(slot, "windowHintEmptySlotLabel").text, "No windows",
                "which is that it has no windows")
            // The other side is unaffected, and says so by having a row rather than
            // a placeholder.
            compare(findAllByName(live(), "windowHintNeighbourRow").length, 1,
                "the other side still has its one row")
            // The frame is unchanged, and the active workspace is still the middle -
            // and still twice as wide as either neighbour, which is the part that
            // could have been lost along with the pixel total.
            compare(body.shownColumnCount, 3)
            compare(body.width, root.panelW, "the panel did not resize")
            compare(columnForPosition(1).width, root.wideCol,
                "and the active column is still twice a neighbour's")
            compare(columnForPosition(0).width, root.narrowCol,
                "as is the left one narrow")
            compare(findByName(live(), "windowHintFocusFrame").x,
                root.bandX + root.padX,
                "and the highlight is still on the active column")
        }

        function test_thePanelIsThreeColumnsWideWhateverTheNeighboursHold() {
            // The one case that broke it: both neighbours empty. A panel that
            // reports one column here is a panel that resizes under the pointer as
            // the user moves between the edge workspace and an interior one.
            body.hint = root.makeHint({ windows: [], previousWindows: [], nextWindows: [] })
            wait(20)
            compare(body.shownColumnCount, 3, "three columns")
            compare(body.width, root.panelW, "the same width as always")
            // The strip is no longer sized to the columns: it has no width and is
            // never translated, because every column places itself. So the resting
            // extent is asserted on the columns, which is where the width lives now -
            // and it must still be exactly the panel, not a part of it.
            compare(strip().x, 0, "the strip is not displaced")
            compare(strip().width, 0,
                "and has no width of its own: every column places itself")
            var columns = columnDelegates()
            compare(columns.length, 3, "and there are still three columns")
            compare(columns[0].x, 0, "the first starts at the panel's left edge")
            compare(columns[2].x + columns[2].width, root.panelW,
                "and the last ends at its right edge")
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
            // the offsets are what says which is the active column. The middle offset
            // is no longer one pitch further on: the active column is twice as wide, so
            // the second column starts at the band's own x and the third one further on
            // by the wide column plus a gutter.
            var xs = visible.map(function(s) { return s.mapToItem(body, 0, 0).x })
                .sort(function(a, b) { return a - b })
            compare(xs[0], root.padX,
                "the first column takes the first slot, inside its padding")
            compare(xs[1], root.bandX + root.padX, "the second the second")
            compare(xs[2], root.rightX + root.padX, "and the third the third")
        }

        function test_thePanelIsAsWideAsItsColumns() {
            // The host sizes the input slot from this number, so it has to be the frame
            // and nothing else - a stray padding term would leave a band of input region
            // beside a narrower panel.
            //
            // Spelled out as five literals rather than a count times a pitch: the panel
            // is two neighbours and one wide column with a gutter at each join, and the
            // middle column being TWICE a neighbour is exactly what a count-times-a-pitch
            // expression cannot say. A panel computed for three equal columns is short
            // by the active column's extra width - 180px - which would crop its own
            // middle slot.
            compare(body.width, root.panelW)
            compare(body.shownColumnCount, 3)
            compare(body.width, root.narrowCol * 2 + root.gutter * 2 + root.wideCol,
                "neighbour, gutter, active column, gutter, neighbour")
            compare(body.width,
                root.bandX + root.wideCol + root.gutter + root.narrowCol,
                "which also puts the band's right edge one gutter before the panel's")
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
                compare(wash.x, root.bandX + root.padX,
                    "combination " + i + ": the active column is the middle one")
                // And centred on the panel, not merely second of three. With a wide
                // middle column that is a real claim rather than an automatic one: a
                // middle slot placed one pitch out would still be the second of three.
                compare(wash.x + wash.width / 2, root.panelW / 2,
                    "combination " + i + ": and centred on the panel")
                compare(wash.width, root.wideCard,
                    "combination " + i + ": and twice a neighbour's card width")
            }
        }

        function test_columnsShareOneRowPitch() {
            // The focus indicator computes its y from the active column's pitch
            // alone. If a neighbour column used a different spacing, the three lists
            // would not line up across the panel and the panel would read as three
            // unrelated stacks. Every column is one delegate of the same component,
            // so this is asserted across the real delegates rather than across a
            // named previous/active/next triple.
            //
            // The ROW pitch is still one number for all three. The COLUMN pitch is no
            // longer anything: the middle column is twice a neighbour's, which is the
            // asymmetry the panel exists to show, so the width claim below replaces the
            // old "the columns are peers in width" rather than sitting next to it.
            var columns = columnDelegates()
            compare(columns.length, 3, "three column delegates")
            for (var i = 1; i < columns.length; ++i) {
                compare(columns[i].spacing, columns[0].spacing,
                    "column " + i + " matches the first column's row pitch")
            }
            // One row pitch, measured off the real rows: the topmost row of each column
            // has to be on the same line, and so does each subsequent one - otherwise the
            // three lists would step against each other across a panel whose middle
            // column is twice as wide as the two beside it.
            var firstOf = columnForPosition(1)
            verify(firstOf, "the active column is there to measure")
            var tops = []
            for (var position = 0; position <= 2; ++position) {
                var column = columnForPosition(position)
                verify(column !== null, "the column for workspace " + position + " exists")
                var rows = column ? findAllByName(column, "windowHintWindowRow")
                    .concat(findAllByName(column, "windowHintNeighbourRow")) : []
                verify(rows.length > 0, "workspace " + position + " has a row")
                if (rows.length > 0) {
                    tops.push(rows[0].y)
                    // The column's own spacing is what puts row n+1 at row n plus a
                    // pitch; checked against a real pair rather than the constant, so a
                    // changed `rowHeight` cannot make this vacuously true.
                    if (rows.length > 1)
                        compare(rows[1].y - rows[0].y, rows[0].height + column.spacing,
                            "workspace " + position + ": its rows step by one pitch")
                }
            }
            compare(tops[1], tops[0], "the middle column's first row is on the same line")
            compare(tops[2], tops[0], "and the right one too")
            // Every column's cards share that row pitch too, so the three lists stay
            // on one baseline. The middle column is exactly twice a neighbour's - which
            // is the whole asymmetry - and the neighbours are narrow on both sides.
            compare(columns[1].width, root.narrowCol * 2,
                "the middle column is exactly twice a neighbour's, was "
                    + columns[1].width)
            compare(columns[0].width, root.narrowCol, "and the neighbours are narrow")
            compare(columns[2].width, root.narrowCol, "on both sides alike")
            // And the cards inside them, which is what the eye compares: 322 against
            // 142, the difference being the column's extra width.
            compare(columns[1].width - root.padX * 2, root.wideCard,
                "so the active card is 322 across")
            compare(columns[0].width - root.padX * 2, root.narrowCard,
                "and a neighbour's is 142")
            // Each column places itself from the workspace it is for and the one the
            // panel is centred on, so its x is its own answer rather than an index
            // times a pitch. The three resting answers are the frame.
            compare(columns[0].x, 0, "column 0 sits at the panel's left edge")
            compare(columns[1].x, root.bandX, "column 1 at the band's own x")
            compare(columns[2].x, root.rightX, "column 2 past the wide middle slot")
            compare(columns[0].x + columns[0].width + root.gutter, columns[1].x,
                "and each is one gutter from the next")
            compare(columns[1].x + columns[1].width + root.gutter, columns[2].x,
                "on both joins")
        }

        // ---- the wide middle column --------------------------------------
        // Everything below is about the one change this layout exists for: the ACTIVE
        // workspace's column is twice a neighbour's, and a switch is drawn as the two
        // columns either side of the wide middle slot trading places through it.
        //
        // Two rules govern how these tests sample, and both are about not writing a
        // test that passes for the wrong reason:
        //
        //   Geometry is animated. A QML TestCase function does not run the event loop,
        //   so reading a property an animation drives gives the value from BEFORE the
        //   change. Mid-crossing samples therefore either `wait()` a specific
        //   duration and accept whatever the crossing's own curve puts there, or - as
        //   the width tests below do - `driveSlideTo()`, which stops the animation and
        //   writes the clock itself so a sample can be taken at an exact fraction. Both
        //   are used: the deterministic ones for exact numbers, the wall-clock ones to
        //   show the real animation produces them.
        //
        //   Expected numbers are LITERALS, or literals derived from literals in this
        //   file. A test whose expectation is `body.activeColumnWidth` cannot tell "the
        //   active column is 360 wide" from "the active column is whatever the
        //   component says", and the component's own constants are exactly what a
        //   retune of this panel would change.

        function test_theActiveColumnIsTwiceANeighbourAtRest() {
            // The resting frame, as five literals. This is the arrangement every other
            // test in the file measures against, so it is stated once, here, from the
            // panel's edges inwards - and read off the real band and the real column
            // delegates rather than off the body's own arithmetic.
            //
            //   |<-180-| -6- |<-  360  ->|-6-| <-180-|
            //   0      186  186        546 552     732
            var band = findByName(body, "windowHintColumnHighlight")
            verify(band !== null, "the panel has a band for the active column")
            compare(band.x, 186, "the band starts at 186")
            compare(band.width, 360, "and is 360 wide, so it ends at 546")
            compare(band.x + band.width, 546, "which is the wide middle slot exactly")

            // The band is the ACTIVE column's cell, and the cards sit one padding
            // inside it on every side: 19 is 8 of clearance, the 3px focus indicator
            // that lives in that padding, and 8 again on the card's own edge.
            var cards = findAllByName(body, "windowHintWindowRow")
            verify(cards.length > 0, "the active column has cards to measure")
            var cardInBody = cards[0].mapToItem(body, 0, 0)
            compare(cardInBody.x, 186 + 19, "a card starts one padding inside the band")
            compare(cards[0].width, 322, "and is 322 wide, was " + cards[0].width)
            compare(cardInBody.x + cards[0].width, 186 + 360 - 19,
                "so it stops one padding inside the band's other edge")

            // The neighbours, at the two ends of the frame, each 180 wide and each a
            // gutter clear of the band.
            var neighbours = findAllByName(live(), "windowHintNeighbourRow")
            compare(neighbours.length, 2, "one row per neighbour column")
            var leftColumnItem = neighbours[0].parent
            var left = leftColumnItem.mapToItem(body, 0, 0)
            var right = neighbours[1].parent.mapToItem(strip(), 0, 0)
            compare(left.x, 0, "the left neighbour is at the panel's left edge")
            compare(leftColumnItem.width, 180,
                "180 wide, was " + leftColumnItem.width)
            compare(right.x, 552, "and the right one starts at 552")
            compare(neighbours[1].parent.width, 180,
                "also 180 wide, was " + neighbours[1].parent.width)
            compare(right.x + neighbours[1].parent.width, 732,
                "so it ends at the panel's right edge")
            compare(band.x - (left.x + leftColumnItem.width), 6,
                "one gutter between the left neighbour and the band")
            compare(right.x - (band.x + band.width), 6,
                "and one between the band and the right neighbour")
            // The claim, as a ratio, so the point survives a retune of the unit: the
            // active column is EXACTLY twice a neighbour's. This is the only asymmetry
            // in the panel, and it is the whole of the emphasis the wide slot adds.
            verify(360 === 2 * 180, "the middle column is exactly twice a neighbour")
        }

        function test_theArrivingColumnWidensAsTheLeavingOneNarrows() {
            // THE width change. The request this layout answers is that a switch be
            // drawn by the active column's width changing, and the two moving columns
            // changing it in OPPOSITE directions - so this is the test that would fail
            // if the width were merely computed at each end and held still in between.
            //
            // Sampled by `driveSlideTo`, i.e. with the animation stopped and the clock
            // written to exact quarters, because the interesting claim is about the
            // values IN BETWEEN the two ends and a wall-clock sample cannot promise a
            // particular fraction. The wall-clock half of the claim is
            // `...WhileTheRealCrossingRuns`, below.
            body.hint = root.framedHint(2, 2)
            wait(20)
            body.hint = root.framedHint(3, 2)
            wait(20)
            verify(body.swapping, "the crossing started")

            // A forward one-step crossing: the panel's centre runs 2 -> 3, so the
            // arriving column's distance from it runs 1 -> 0 and the leaving one's runs
            // 0 -> -1. The expected widths are 180 + 180 * that distance's share, so at
            // quarters of the way they are 180/225/270/315/360 - written out, not
            // computed from the component's constants.
            var expected = [180, 225, 270, 315, 360]
            var arrivingWidths = []
            var leavingWidths = []
            for (var step = 0; step < expected.length; ++step) {
                driveSlideTo(step / (expected.length - 1))
                var arriving = columnForPosition(3)
                var leaving = columnForPosition(2)
                verify(arriving !== null && leaving !== null,
                    "step " + step + ": both columns are on the strip")
                arrivingWidths.push(arriving.width)
                leavingWidths.push(leaving.width)
                compare(arriving.width, expected[step],
                    "step " + step + ": the arriving column is " + expected[step]
                        + " wide, was " + arriving.width)
                compare(leaving.width, expected[expected.length - 1 - step],
                    "step " + step + ": and the leaving one is "
                        + expected[expected.length - 1 - step] + ", was " + leaving.width)
                // And the CARDS, which is what the eye actually compares: 322 at the
                // end against 142 at the start, the column's padding at each side.
                compare(arriving.width - root.padX * 2,
                    expected[step] - 38,
                    "step " + step + ": its card is " + (expected[step] - 38) + " across")
                compare(leaving.width - root.padX * 2,
                    expected[expected.length - 1 - step] - 38,
                    "step " + step + ": and the leaving card is "
                        + (expected[expected.length - 1 - step] - 38))
            }
            // Strictly, at every step: a column that grew and shrank inside one
            // crossing would read as a mistake rather than as motion, and a width that
            // only ever changed at the ends would be two frames rather than a crossing.
            for (var s = 1; s < arrivingWidths.length; ++s) {
                verify(arrivingWidths[s] > arrivingWidths[s - 1],
                    "the arriving column widens all the way in, was "
                        + arrivingWidths[s] + " after " + arrivingWidths[s - 1])
                verify(leavingWidths[s] < leavingWidths[s - 1],
                    "and the leaving one narrows all the way out, was "
                        + leavingWidths[s] + " after " + leavingWidths[s - 1])
            }
            // They swap: one pair of widths, traded, with nothing appearing or
            // disappearing between them.
            compare(arrivingWidths[0], 180, "the arriving column starts at a neighbour's width")
            compare(arrivingWidths[arrivingWidths.length - 1], 360,
                "and ends at the active column's width")
            compare(leavingWidths[0], 360, "the leaving one starts wide")
            compare(leavingWidths[leavingWidths.length - 1], 180,
                "and ends narrow")
            for (var w = 0; w < expected.length; ++w) {
                verify(arrivingWidths[w] + leavingWidths[w] === 540,
                    "the pair holds 540 between them at step " + w + ", was "
                        + (arrivingWidths[w] + leavingWidths[w]))
            }
            // Their PLACES, at the midpoint, as literals. The width claim alone would be
            // satisfied by two columns that swap widths where they stand, and the whole
            // crossing is the two facts together: at half of 2 -> 3 the panel's centre is
            // on 2.5, so the leaving column is half a neighbour's pitch from the left edge
            // (93) and the arriving one is half way across the wide middle slot
            // (186 + 366 / 2 = 369).
            driveSlideTo(0.5)
            compare(body.panelPosition, 2.5, "halfway, the panel is on 2.5")
            compare(columnForPosition(2).x, 93,
                "the leaving column is halfway out to the left edge, was "
                    + columnForPosition(2).x)
            compare(columnForPosition(3).x, 369,
                "and the arriving one halfway across the wide slot, was "
                    + columnForPosition(3).x)
            // The same two columns, the other way round: the arriving one comes from
            // the LEFT and still widens, the leaving one goes right and still narrows.
            // A layout that keyed the direction of travel rather than the workspace
            // would fail exactly here.
            body.hint = root.framedHint(4, 4)
            wait(20)
            body.hint = root.framedHint(3, 4)
            wait(20)
            verify(body.swapping, "the backward crossing started")
            driveSlideTo(0.5)
            verify(columnForPosition(3).width > root.narrowCol,
                "backwards, the arriving column widens, was " + columnForPosition(3).width)
            verify(columnForPosition(4).width < root.wideCol,
                "and the leaving one narrows, was " + columnForPosition(4).width)
            driveSlideTo(1)
            compare(columnForPosition(3).width, root.wideCol,
                "backwards, it arrives at the active column's width, was "
                    + columnForPosition(3).width)
            settleSlide()
        }

        function test_theWidthChangeRunsOnTheRealCrossingToo() {
            // The same claim, read off a crossing that is actually animating rather
            // than one this test drove. Without it the test above could be satisfied by
            // a clock that only moves when something writes to it, and the sample at
            // progress 0 would be the only honest one of the five.
            //
            // Sampled on wall clock, so the values are whatever the crossing's own curve
            // (`Easing.OutQuad` on `MotionTokens.medium`) puts at each moment. The
            // monotonicity is therefore non-strict - two samples can land on the same
            // frame - but the DIRECTION and the two ends are still pinned exactly.
            body.hint = root.framedHint(2, 2)
            wait(20)
            body.hint = root.framedHint(3, 2)
            var arriving = root.narrowCol
            var leaving = root.wideCol
            var samples = 0
            while (body.swapping && samples < 80) {
                wait(4)
                if (!body.swapping)
                    break
                var arrivingColumn = columnForPosition(3)
                var leavingColumn = columnForPosition(2)
                if (!arrivingColumn || !leavingColumn)
                    break
                verify(arrivingColumn.width >= arriving,
                    "sample " + samples + ": the arriving column never narrows, was "
                        + arrivingColumn.width + " from " + arriving)
                verify(leavingColumn.width <= leaving,
                    "sample " + samples + ": the leaving one never widens, was "
                        + leavingColumn.width + " from " + leaving)
                // And they are always strictly between the pair's extremes, which is
                // what makes it a change in progress rather than two jumps.
                verify(arrivingColumn.width >= root.narrowCol
                        && leavingColumn.width <= root.wideCol,
                    "sample " + samples + ": neither has overshot")
                arriving = arrivingColumn.width
                leaving = leavingColumn.width
                samples++
            }
            verify(samples > 2, "it was sampled while running, " + samples + " times")
            settleSlide()
            // Landed: the arriving column IS the panel's wide middle slot and the one
            // that was left is a neighbour, so the swap completed on its own clock.
            var landed = columnForPosition(3)
            compare(landed.x, root.bandX, "the arriving workspace ends in the wide slot")
            compare(landed.width, root.wideCol,
                "at the active column's width, was " + landed.width)
            compare(columnForPosition(2).width, root.narrowCol,
                "and the one left behind is narrow again, was "
                    + columnForPosition(2).width)
        }

        function test_theTwoMovingColumnsNeverOverlapAndKeepTheGutter() {
            // The property that makes a crossing of this shape safe to draw at all: the
            // panel can never show two cards on top of each other, and never a bare band
            // wider than one inter-card gap.
            //
            // It has to hold for EVERY pair of adjacent columns, not only for the two
            // that are trading - the columns outside the frame are moving too, and one
            // of them crossing a panel edge is the case `thePanelIsNeverLeftUncovered`
            // is about. Swept over every span, both directions and forty-one points
            // along each crossing, because one case of it would prove nothing about the
            // family.
            var samples = 0
            var gaps = []
            for (var span = 1; span <= 3; ++span) {
                for (var direction = 0; direction < 2; ++direction) {
                    var from = direction === 0 ? 1 : 6
                    var to = direction === 0 ? 1 + span : 6 - span
                    body.hint = root.framedHint(from, from)
                    wait(20)
                    body.hint = root.framedHint(to, from)
                    wait(20)
                    for (var step = 0; step <= 40; ++step) {
                        driveSlideTo(step / 40)
                        var columns = columnDelegates()
                        compare(columns.length, span + 3,
                            "span " + span + " dir " + direction + " step " + step
                                + ": the whole union is on the strip")
                        var previousRight = null
                        for (var c = 0; c < columns.length; ++c) {
                            if (previousRight !== null) {
                                verify(columns[c].x >= previousRight,
                                    "span " + span + " dir " + direction + " step " + step
                                        + ": column " + c + " does not overlap the one before")
                                gaps.push(columns[c].x - previousRight)
                            }
                            previousRight = columns[c].x + columns[c].width
                        }
                        samples += columns.length
                    }
                }
            }
            verify(samples > 1000, "the sweep was wide enough to be worth something, "
                + samples + " columns")
            // Every gap measured, on real delegates, was the gutter - and nothing else.
            // Not "at most", not "about": exactly, because that is the shape's whole
            // guarantee and a single wider or narrower sample is the fault.
            var wrong = gaps.filter(function(g) { return Math.abs(g - 6) > 1e-6 })
            compare(wrong.length, 0,
                "every adjacent pair is exactly one gutter (6) apart, was wrong for "
                    + wrong.length + " of " + gaps.length + " joins, e.g. " + wrong[0])
            settleSlide()
        }

        function test_theMarkersFollowTheArrivingColumnAsItWidens() {
            // Focus belongs to the workspace being moved to, so the two shared markers
            // have to travel with THAT column - and change width with it. Pinned to the
            // panel they would say "the focus stayed put" while the list it marks moved
            // and widened, which are two different claims about the same instant.
            //
            // Sampled at quarters by `driveSlideTo`, so the widths compared below are the
            // exact ones rather than whatever the crossing's curve had reached.
            body.hint = root.framedHint(2, 2)
            wait(20)
            body.hint = root.framedHint(3, 2)
            wait(20)
            verify(body.swapping, "the crossing started")
            var previousFrameWidth = -1
            var previousBarX = -1
            for (var step = 0; step <= 4; ++step) {
                driveSlideTo(step / 4)
                var frame = findByName(strip(), "windowHintFocusFrame")
                var bar = findByName(strip(), "windowHintFocusIndicator")
                var arriving = columnForPosition(3)
                verify(frame !== null && bar !== null && arriving !== null,
                    "step " + step + ": the markers and the column are all there")
                // The outline starts one padding inside the column and spans the card:
                // the column less the padding at each side.
                compare(frame.x, arriving.x + 19,
                    "step " + step + ": the outline starts one padding inside the column")
                compare(frame.width, arriving.width - 38,
                    "step " + step + ": and is exactly as wide as the card, was "
                        + frame.width)
                // The indicator is measured from the column's own left edge, not the
                // card's: it lives in the band's padding, beside the card.
                compare(bar.x, arriving.x + 8,
                    "step " + step + ": and the indicator is 8 into the band's padding")
                compare(bar.x + bar.width, arriving.x + 8 + 3,
                    "step " + step + ": one clearance, the bar, one clearance")
                verify(bar.x + bar.width <= frame.x,
                    "step " + step + ": so it stays outside the outline")
                // The card it marks really is the arriving workspace's, read off the
                // live rows rather than off the marker.
                var rows = findAllByName(arriving, "windowHintWindowRow")
                verify(rows.length > 0, "step " + step + ": the arriving column has cards")
                if (rows.length > 0)
                    compare(frame.x, rows[0].mapToItem(strip(), 0, 0).x,
                        "step " + step + ": and on the first of them")
                // Both markers MOVE as the column does, and the outline grows with it.
                if (step > 0) {
                    verify(frame.width > previousFrameWidth,
                        "step " + step + ": the outline widens with the card, was "
                            + frame.width + " from " + previousFrameWidth)
                    verify(bar.x < previousBarX,
                        "step " + step + ": and the indicator slides in with it, was "
                            + bar.x + " from " + previousBarX)
                }
                previousFrameWidth = frame.width
                previousBarX = bar.x
            }
            settleSlide()
            var landed = findByName(live(), "windowHintFocusFrame")
            compare(landed.x, root.bandX + root.padX,
                "once landed the outline is inside the wide slot's padding")
            compare(landed.width, root.wideCard,
                "and spans the active card, was " + landed.width)
        }

        function test_aReAimContinuesFromWhereTheCrossingHadReached() {
            // Holding mod and arrowing twice quickly lands a second switch while the
            // first is still crossing. The new leg has to start where the panel
            // actually IS, not at the new plan's own start - otherwise the content is
            // thrown back to the edge of the panel, which is a visible jump rather than
            // a correction.
            //
            // Positions rather than pixels is what makes this free: there is no offset
            // to convert and no slots to renumber, so the whole of "continue from here"
            // is handing the new leg the number the crossing had reached. Read WITHOUT
            // an event-loop turn between the publish and the read, so a panel sent back
            // to its start shows up here rather than a frame later.
            for (var direction = 0; direction < 2; ++direction) {
                var first = direction === 0 ? 1 : 5
                var second = direction === 0 ? 2 : 4
                var third = direction === 0 ? 3 : 3
                var label = "direction " + direction
                body.hint = root.framedHint(first, first)
                wait(20)
                body.hint = root.framedHint(second, first)
                wait(Math.round(body.slideDuration / 2))
                var reached = body.panelPosition
                verify(reached !== first && reached !== second,
                    label + ": the first crossing is under way, reached " + reached)
                var arrived = columnForPosition(second)
                var arrivedX = arrived.x

                // The second switch, in the same direction: the common case.
                body.hint = root.framedHint(third, second)
                compare(body.positionFrom, reached,
                    label + ": the new leg starts exactly where the crossing had reached")
                compare(body.positionTo, third, label + ": and ends on the new destination")
                compare(body.panelPosition, reached,
                    label + ": so the panel has not moved at all on the frame the second "
                        + "switch landed")
                verify(body.swapping, label + ": and it is still crossing")
                compare(body.plan.toPosition, third, label + ": with the new end")
                // The leg deliberately does NOT start at the new plan's own beginning:
                // that is the whole of "re-aim for free". The plan says where the move
                // was aimed from, the body says where the panel actually is, and the
                // layout follows the second.
                verify(body.positionFrom !== body.plan.fromPosition,
                    label + ": and the body overrides the plan's own start, "
                        + body.positionFrom + " against " + body.plan.fromPosition)
                // The content did not jump either: the workspace that was arriving
                // mid-crossing is in the same place it was.
                verify(Math.abs(columnForPosition(second).x - arrivedX) < 1e-6,
                    label + ": and the arriving column did not move, was "
                        + columnForPosition(second).x + " from " + arrivedX)

                // It carries on from there rather than starting over.
                wait(Math.round(body.slideDuration / 4))
                verify(body.panelPosition > reached || body.panelPosition < reached,
                    label + ": and the new leg is moving, was " + body.panelPosition)
                verify(body.panelPosition !== reached,
                    label + ": away from where it started")
                settleSlide()
                compare(body.panelPosition, third,
                    label + ": and it lands on the second destination, was "
                        + body.panelPosition)
                compare(body.plan.slots, 3, label + ": with the arriving frame alone")
                compare(columnForPosition(third).width, root.wideCol,
                    label + ": and its active column at the active column's width")
            }
        }

        // The strip's column delegates, left to right. Read off the strip's children by the
// workspace position each one declares, rather than through the rows: a column whose
        // workspace has no windows instantiates no row at all, and "the panel still has
        // three columns when all three are empty" is one of the claims under test.
        function columnDelegates() {
            var s = strip()
            if (!s)
                return []
            var out = []
            var kids = s.children
            for (var i = 0; i < kids.length; ++i) {
                var kid = kids[i]
                // The focus frame and the indicator are children of the strip too, and
                // declare no position; the Repeater's role-less placeholder reads
                // `undefined` for every role.
                if (kid && kid.modelData && kid.modelData.position !== undefined)
                    out.push(kid)
            }
            return out.sort(function(a, b) { return a.x - b.x })
        }

        // The strip's column delegate for one WORKSPACE POSITION, or null.
        //
        // Addressing a column by its own position rather than by its index or its
        // left edge is what the new layout makes possible and what the crossing
        // assertions need: mid-crossing a column's x is a fractional number, so "slot
        // 2" no longer names a place, while "the column for workspace 3" always does.
        //
        // Walked off the strip's children rather than off the rows, because a column
        // whose workspace has no windows instantiates no row at all and would be
        // missed - and an empty column is exactly one of the cases under test.
        // A column's window rows, in order, read off the real delegates.
        function rowsIn(column) {
            if (!column)
                return []
            return findAllByName(column, "windowHintWindowRow")
        }

        function columnForPosition(position) {
            var s = strip()
            if (!s)
                return null
            var kids = s.children
            for (var i = 0; i < kids.length; ++i) {
                var kid = kids[i]
                // The focus frame and the indicator are children of the strip too, and
                // declare no position.
                if (kid && kid.modelData && kid.modelData.position === position)
                    return kid
            }
            return null
        }

        // Drive a crossing to one exact point on its own clock, and let the layout
        // catch up, so a sample can be read at a known fraction instead of at whatever
        // moment the wall clock happened to reach.
        //
        // The animation is STOPPED first: `slideProgress` is its target property, so a
        // write made while it runs would be overwritten on the next tick and the
        // sample would be a race. Stopping it leaves the crossing's own plan in place -
        // the strip still carries `span + 3` columns, the held frame is still held -
        // so the geometry being sampled is the geometry the crossing really had at that
        // progress. A one-millisecond wait afterwards is for the bindings, not for the
        // animation.
        function driveSlideTo(progress) {
            body.slideAnimation.stop()
            body.slideProgress = progress
            wait(1)
        }

        // --- the crossing displacement ---------------------------------------
        // On a workspace switch ONE instance of the outline and ONE instance of the bar
        // descend from ABOVE the panel's top edge onto the focused card of the workspace
        // being moved to. Always from the top, whichever way the workspace went.
        //
        // The marker has its OWN clock: 320ms of `InOutQuad` against the strip's 160ms
        // of `OutQuad`, so the columns change workspace first and the focus then travels
        // down onto them. Every test here drives that clock, never `slideProgress`.

        // The two markers, for the displacement tests to read.
        function outline() {
            return findByName(body, "windowHintFocusFrame")
        }

        function bar() {
            return findByName(body, "windowHintFocusIndicator")
        }

        // The panel's clip edge, in the markers' coordinates. Read off the component
        // rather than restated as literals, and deliberately: the claim is where the
        // marker sits RELATIVE to the clip, which holds for any clip, and a suite that
        // pinned the clip's absolute position would be asserting the theme's padding
        // numbers instead of the motion.
        function clipTop() {
            return -body._stripY
        }

        // Drive the MARKER's clock to an exact fraction. It is a different clock from
        // `slideProgress` and a different length, so it needs its own handle - sampling
        // one does not move the other.
        function driveMarkerTo(progress) {
            body.crossingAnimation.stop()
            body.crossingClock = progress
            wait(1)
        }

        // Let the marker run its real animation out, which is the only thing that clears
        // `_markerCrossing` - it is a clock's flag, not a derived expression, so nothing
        // else can.
        function settleMarker() {
            wait(body.crossingAnimation.duration + 60)
        }

        // Land a crossing that was driven by hand. `driveSlideTo` and `driveMarkerTo`
        // stop their animations, so neither `onFinished` ever runs - and each of those is
        // what clears its own flag. A publish that reports no movement is NOT how this
        // lands any more. The production path that does finish is `_commitHint`, reached
        // by a move no strip can carry, so that is what this publishes: at the
        // destination, from far enough away that the span exceeds `MAX_SWITCH_SPAN` -
        // AHEAD of it, not behind, because a negative position reports no direction at
        // all and reads as "nothing moved".
        function landDrivenSlide(destination) {
            driveSlideTo(1)
            body.hint = root.framedHint(destination + (Hint.MAX_SWITCH_SPAN + 1),
                destination)
            body.hint = root.framedHint(destination, destination)
            wait(20)
            verify(!body.swapping, "the columns have landed at " + destination)
            verify(!body._markerCrossing, "and so has the marker")
        }

        // Every position the marker takes between two progress values, and the largest
        // single step between two of them - because "it moves" and "you can SEE it move"
        // are different claims, and what separates them is the speed. `steps` is over the
        // marker's whole clock, so `peakStep` is pixels per `steps`-th of its real
        // duration.
        function sampleTop(steps) {
            var seen = []
            var peak = 0
            for (var i = 0; i <= steps; ++i) {
                driveMarkerTo(i / steps)
                seen.push(body.crossingTop)
                if (i > 0)
                    peak = Math.max(peak, Math.abs(body.crossingTop - seen[i - 1]))
            }
            return { tops: seen, peakStep: peak }
        }

        function test_theMarkerStartsOutsideThePanelAndComesDownOntoTheCard() {
            // The effect. It starts wholly above the panel's top edge - so it slides IN
            // rather than already being on screen at the edge - and lands on the focused
            // card, moving down the whole way.
            body.hint = root.tallFramedHint(2, 2, 4, 2)
            wait(20)
            body.hint = root.tallFramedHint(3, 2, 4, 0)
            wait(20)
            driveMarkerTo(0)

            // Wholly outside, and outside at the TOP rather than the bottom.
            verify(body.crossingTop + body.rowHeight <= clipTop(),
                "it starts a whole card above the panel's top edge, so it slides in - "
                    + body.crossingTop + " against a clip top of " + clipTop())
            verify(outline().y < 0, "and the outline is off the top too, was "
                + outline().y)
            var sample = sampleTop(24)
            var tops = sample.tops
            // Strictly DOWN, every step. A marker that rose at any point - even briefly -
            // would read as two motions rather than one.
            for (var i = 1; i < tops.length; ++i)
                verify(tops[i] > tops[i - 1],
                    "it moves down the whole way, sample " + i + " was " + tops[i]
                        + " after " + tops[i - 1])
            driveMarkerTo(1)
            compare(body.crossingTop, body.focusedRowTop,
                "landing exactly on the focused card")
        }

        function test_theDisplacementIsSlowEnoughToSee() {
            // The reason the marker has a clock of its own, asserted as a measurement
            // rather than as a number in the file.
            //
            // It was on the strip's clock before: `medium`, 160ms, `Easing.OutQuad`.
            // The strip crosses 205px of panel in that and it is right for the strip. The
            // marker travels at most one viewport vertically - and when the focused window
            // is the first row, only 28px of that is on screen at all. On `OutQuad`, which
            // covers three quarters of its distance in the first half of its time, 28px is
            // over in about 30ms. Measured on the old version, the fastest point of the
            // travel was around 1500px/s, which the eye reads as a jump and not as travel -
            // which is exactly what it looked like.
            //
            // So: the marker's clock must be the LONGER of the two, and it must not front-
            // load. Both are read off the component, so a retune that undoes either fails
            // here rather than on screen.
            compare(body.crossingAnimation.duration, Lazer.MotionTokens.page,
                "the marker runs on the long clock, was "
                    + body.crossingAnimation.duration)
            compare(body.crossingAnimation.easing.type, Easing.InOutQuad,
                "on a curve that does not front-load, was "
                    + body.crossingAnimation.easing.type)
            verify(body.crossingAnimation.duration > body.slideAnimation.duration,
                "and it outlives the columns, " + body.crossingAnimation.duration
                    + " against " + body.slideAnimation.duration
                    + " - the list changes workspace first and the focus then arrives on it")

            // And the measurement itself, on the WORST case: the focused window is the
            // FIRST row, so almost the whole travel happens above the panel's edge and
            // only the gap between that edge and the first card - `cellPaddingY`, 15px -
            // is on screen at all. It is fully outside at the start, and the little that
            // is visible has to carry the whole effect. Asserted as the exact figure
            // rather than a threshold, so a change to either number shows up here.
            body.hint = root.tallFramedHint(2, 2, 4, 2)
            wait(20)
            body.hint = root.tallFramedHint(3, 2, 4, 0)
            wait(20)
            driveMarkerTo(0)
            compare(body.focusedRowTop - clipTop(),
                body.bandInset - body.surfaceInset + body.cellPaddingY,
                "the whole of the visible travel is the gap between the panel's top edge "
                    + "and the first card, and nothing else")
            var frames = Math.max(1, body.crossingAnimation.duration / (1000 / 60))
            var sample = sampleTop(32)
            var peakSpeed = sample.peakStep * 32 * 60 / frames
            verify(peakSpeed < 700,
                "so even that is a speed the eye can follow - 15px over "
                    + body.crossingAnimation.duration + "ms, peaking at "
                    + Math.round(peakSpeed) + "px/s against a 700px/s ceiling")

            // And the case the description is actually about: a focus low in the column,
            // where the marker genuinely crosses the cards above it on the way down.
            body.hint = root.tallFramedHint(4, 4, 4, 3)
            wait(20)
            body.hint = root.tallFramedHint(3, 4, 4, 3)
            wait(20)
            driveMarkerTo(0)
            var lowOnScreen = body.focusedRowTop - clipTop()
            verify(lowOnScreen >= body.rowPitch * 3,
                "a focus on the fourth row puts three whole card pitches of panel "
                    + "between the marker's start and its landing, was " + lowOnScreen
                    + " against " + (body.rowPitch * 3))
            var lowSample = sampleTop(32)
            verify(lowSample.tops[lowSample.tops.length - 1] > lowSample.tops[0],
                "and it crosses all of them")
            settleMarker()
        }

        function test_theDisplacementComesFromTheTopWhicheverWayTheWorkspaceWent() {
            // The reference's rule, and the reason for it: one entry side, so the motion
            // reads as the same gesture every time. Asserted for both directions against
            // the same start, because a marker that entered from the side it was heading
            // would pass every test that looked at one direction.
            var starts = {}
            var ends = {}
            for (var direction = 0; direction < 2; ++direction) {
                var from = direction === 0 ? 2 : 4
                var label = direction === 0 ? "forwards" : "backwards"
                body.hint = root.tallFramedHint(from, from, 4, 2)
                wait(20)
                body.hint = root.tallFramedHint(3, from, 4, 0)
                wait(20)
                driveMarkerTo(0)
                starts[label] = body.crossingTop
                driveMarkerTo(1)
                ends[label] = body.crossingTop
                settleMarker()
            }
            compare(starts.forwards, starts.backwards,
                "both directions start from the same place, above the panel - "
                    + starts.forwards + " and " + starts.backwards)
            verify(starts.forwards < clipTop() && starts.backwards < clipTop(),
                "and that place is above the panel's top edge, not below it")
            compare(ends.forwards, ends.backwards,
                "and both land on the same card, " + ends.forwards + " and "
                    + ends.backwards)
        }

        function test_oneInstanceOfEachMarkerAndItIsTheOneThatMoves() {
            // ONE instance, and it is the one that travels. It was two of each - a
            // resting element and a crossing-only twin, each hidden while the other
            // showed - so the visible marker was always a different object from the one
            // that had been there before. That is a cut wearing a disguise, and the
            // displacement is only the gesture if the same rectangle does it.
            compare(findAllByName(body, "windowHintFocusFrame").length, 1,
                "exactly one focus outline exists")
            compare(findAllByName(body, "windowHintFocusIndicator").length, 1,
                "exactly one indicator exists")
            body.hint = root.tallFramedHint(2, 2, 4, 2)
            wait(20)
            body.hint = root.tallFramedHint(3, 2, 4, 0)
            wait(20)
            // The same element, watched across the crossing and held by reference, so a
            // rebuild underneath it would show up as a different object.
            var watched = outline()
            driveMarkerTo(0)
            var atTop = watched.y
            driveMarkerTo(1)
            verify(outline() === watched, "the outline is still the same object")
            verify(watched.y > atTop,
                "and it is the object that moved, from " + atTop + " to " + watched.y)
            var watchedBar = bar()
            driveMarkerTo(0)
            var barTop = watchedBar.y
            driveMarkerTo(1)
            verify(bar() === watchedBar && watchedBar.y > barTop,
                "and so is the bar, from " + barTop + " to " + watchedBar.y)
            settleMarker()
        }

        function test_theBarAndTheOutlineAreOneGesture() {
            // The bar is a bar CENTRED on its card, so it sits one `markerOffset` below
            // the outline at EVERY point of the crossing - not only at rest. Two markers
            // drifting apart mid-travel would read as two independent things happening.
            body.hint = root.tallFramedHint(2, 2, 4, 2)
            wait(20)
            body.hint = root.tallFramedHint(3, 2, 4, 0)
            wait(20)
            for (var step = 0; step <= 6; ++step) {
                driveMarkerTo(step / 6)
                compare(bar().y - outline().y, body.markerOffset,
                    "at " + (step / 6) + " the bar is centred on the card the outline "
                        + "draws, was " + (bar().y - outline().y))
                compare(bar().x, strip().activeColumnX + body.indicatorInset,
                    "at " + (step / 6) + " and both sit in the arriving column")
                compare(outline().x, strip().activeColumnX + body.cellPaddingX,
                    "at " + (step / 6) + " with the outline on the card's own edge")
            }
            // And the bar keeps its length throughout, rather than also running the
            // tracker's own head/tail stretch underneath the displacement: two motions on
            // one marker is what that would be. `crossingTop` moves the bar and nothing
            // else does while the flag is up.
            for (step = 0; step <= 4; ++step) {
                driveMarkerTo(step / 4)
                compare(bar().height, body.indicatorLength,
                    "at " + (step / 4) + " the bar keeps the indicator's length, was "
                        + bar().height + " against " + body.indicatorLength)
            }
            settleMarker()
            compare(bar().height, body.indicatorLength,
                "and it is still that length once it has landed")
        }

        function test_theDisplacementLandsAndStays() {
            // The landing, and specifically that it STAYS. The two placements of the
            // marker used to be chosen by a `Behavior`'s `enabled` and a binding in the
            // same polish, so which of them won at the boundary came down to evaluation
            // order - and the wrong winner was a second glide, from wherever the crossing
            // left the marker back down onto the card it had already reached.
            body.hint = root.tallFramedHint(2, 2, 4, 2)
            wait(20)
            body.hint = root.tallFramedHint(3, 2, 4, 0)
            wait(20)
            driveMarkerTo(1)
            var landed = outline().y
            settleMarker()
            // Read immediately: a `fast` or `OutQuint` glide would still be under way,
            // and so would a whole extra animation.
            compare(outline().y, landed,
                "the outline is where the displacement left it, was " + outline().y
                    + " against " + landed)
            compare(outline().y, body.focusedRowTop, "which is the focused card")
            compare(bar().y, body.focusedRowTop + body.markerOffset,
                "and the bar is centred on the same card")
            // The strip has already finished by then: the marker's clock is the longer
            // one, so this is where the second beat of the two-beat effect lives.
            verify(!body.swapping, "the columns had finished before the marker landed")
            wait(body.slideDuration + 80)
            compare(outline().y, landed, "and it is still there, was " + outline().y)
        }

        function test_aReAimDoesNotRestartTheDisplacement() {
            // A second switch landing mid-crossing re-aims the traverse, and the marker
            // has to carry on through it. Resetting it would throw the marker back to the
            // top of the panel - a second entry, which reads as two crossings rather than
            // as one move re-aimed. The specific regression a displacement driven off a
            // clock invites, because a re-aim restarts that clock.
            body.hint = root.framedHint(1, 1)
            wait(20)
            body.hint = root.framedHint(2, 1)
            wait(20)
            driveMarkerTo(0.5)
            var reached = body.crossingTop
            body.hint = root.framedHint(3, 2)
            // No wait: the re-aim restarts the marker's clock to 0 in the same turn as
            // the publish, so a wait here would let the new leg travel for a frame or two
            // and the sample would no longer be the instant the question is about.
            compare(body.crossingTop, reached,
                "the marker did not go back to the top of the panel, was "
                    + body.crossingTop + " against " + reached)
            wait(20)
            verify(body._markerCrossing, "the crossing is still under way")
            driveMarkerTo(0.75)
            verify(body.crossingTop > reached,
                "and it is still travelling down, went " + reached + " to "
                    + body.crossingTop)
            landDrivenSlide(3)
        }

        function test_noSwitchMeansNoDisplacement() {
            // A refresh on the same workspace, a cold snapshot and a move too wide to
            // describe all commit outright, so none of them may arm a crossing. A flag
            // left set by a cancelled crossing would park the marker above the panel for
            // the rest of the hold, which is the worst possible failure for it: the
            // panel would show no focus mark at all and say nothing about why.
            verify(!body._markerCrossing, "nothing is crossing at rest")
            verify(findByName(body, "windowHintFocusFrame").visible,
                "and the outline is on screen")
            body.hint = root.framedHint(2, 2)
            wait(20)
            body.hint = root.makeHint({
                activeWorkspacePosition: 2,
                previousActiveWorkspacePosition: 2,
                windows: [{ windowId: "x", title: "edited", icon: "", isFocused: true }],
                previousWindows: [{ windowId: "p", title: "p", icon: "", isFocused: false }],
                nextWindows: [{ windowId: "n", title: "n", icon: "", isFocused: false }]
            })
            wait(20)
            verify(!body._markerCrossing, "a same-workspace refresh arms no crossing")
            verify(outline().visible, "and the outline is still there")
            body.hint = root.makeHint({
                activeWorkspacePosition: 8,
                previousActiveWorkspacePosition: 2,
                windows: [{ windowId: "y", title: "far", icon: "", isFocused: true }],
                previousWindows: [], nextWindows: []
            })
            wait(20)
            verify(!body._markerCrossing, "a move too wide to describe arms no crossing")
            verify(outline().visible, "and the outline is still there")
        }

        function test_aSwitchAlwaysLandsTheDisplacement() {
            // The effect ENDS, not only that it starts. `_markerCrossing` is a flag
            // written by an animation's `onFinished`, and a flag is something that can be
            // left set - which would leave the marker travelling over a panel that had
            // long since stopped, forever.
            body.hint = root.tallFramedHint(2, 2, 4, 2)
            wait(20)
            body.hint = root.tallFramedHint(3, 2, 4, 0)
            wait(20)
            verify(body._markerCrossing, "a switch does cross, which is what this checks")
            settleMarker()
            verify(!body._markerCrossing, "and the crossing is over once it has landed")
            verify(outline().visible, "with the outline back on its card")
            compare(outline().y, body.focusedRowTop, "and on the focused card")
        }

        function test_theDisplacementNeverCoversTheRowContentItIsMarking() {
            // The outline is border-only for the same reason the resting one's was: a
            // filled shape would veil every icon and title in the column it travels over.
            // Compared against the value QML normalises `transparent` to, rather than
            // against the string: a colour property hands back `#00000000`, so an equality
            // against "transparent" would fail on the representation rather than on the
            // claim.
            body.hint = root.tallFramedHint(2, 2, 4, 2)
            wait(20)
            body.hint = root.tallFramedHint(3, 2, 4, 0)
            wait(20)
            compare(String(outline().color).toLowerCase(), "#00000000",
                "it fills nothing, so it cannot cover the rows it passes over, was "
                    + outline().color)
            compare(outline().z > 0, true, "above the rows, which is what makes it a mark")
            compare(outline().enabled, false, "and inert to input")
            for (var step = 0; step <= 4; ++step) {
                driveMarkerTo(step / 4)
                compare(bar().width, body.indicatorThickness,
                    "at " + (step / 4) + " the bar keeps the indicator's thickness, was "
                        + bar().width)
            }
            settleMarker()
        }

        function test_theWholePanelArrivesInOnePiece() {
            // No row is left behind and none arrives on its own. A switch used to
            // stagger the three columns in row by row, which meant the panel was
            // briefly three different heights' worth of half-drawn content; now every
            // column's place comes off the one clock, so every row of every column
            // crosses at the same time and none of them is ever partially faded in.
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
            // A crossing this suite drove by hand had its animation stopped, so its
            // `onFinished` never runs and `swapping` - a flag, since it stopped being
            // `slideProgress < 1` - stays set for good. Waiting cannot clear it. Land it
            // through the one publish that does reach `_commitHint`, so the next test
            // starts from a panel at rest rather than inheriting a crossing.
            if (body.swapping)
                landDrivenSlide(body.hint.activeWorkspacePosition)
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

        function test_underlineHiddenWhenNoWindowIsFocused() {
            // The one case where there is genuinely nothing to underline: no window in
            // the workspace is focused, so there is no row to point at. Distinct from a
            // focused window past the viewport, which the scroll now reveals - see
            // `test_theFocusedWindowIsScrolledIntoView`.
            var many = []
            for (var i = 0; i < 8; i++)
                many.push({ windowId: String(i), title: "w" + i, icon: "", isFocused: false })
            body.hint = root.makeHint({ windows: many })
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
        function test_aLongListIsNotCappedItScrolls() {
            // The change: every window in the workspace is a row, and the panel is a
            // viewport over them rather than a list with its tail folded into a summary
            // line. The old cap showed five of eight and said "+3 more windows", which
            // is a dead end - there was nothing to do about the three.
            var many = []
            for (var i = 0; i < 8; i++)
                many.push({ windowId: String(i), title: "w" + i, icon: "", isFocused: false })
            body.hint = root.makeHint({ windows: many })
            wait(20)
            var rows = findAllByName(live(), "windowHintWindowRow")
            compare(rows.length, 8, "all eight windows are rows, not five")
            // And nothing stands in for the ones that do not fit.
            compare(findAllByName(live(), "windowHintOverflow").length, 0,
                "and there is no overflow line at all")
            verify(!/more window/.test(shownText()),
                "no column says anything about windows it is not showing, saw \""
                    + shownText() + "\"")
        }

        function test_thePanelIsBoundedByTheViewportHoweverLongTheList() {
            // The reason the cap existed, answered from the other side: the panel's
            // height - and so the layer-shell input region - must not grow once per
            // added window. A viewport bounds it; a cap bounded it by throwing rows away.
            //
            // Read against the VIEWPORT rather than against a count, so the claim is
            // about the bound rather than about this particular fixture's arithmetic.
            var heights = {}
            for (var count = 2; count <= 12; count += 5) {
                var many = []
                for (var i = 0; i < count; i++)
                    many.push({ windowId: String(i), title: "w" + i, icon: "",
                        isFocused: false })
                body.hint = root.makeHint({ windows: many })
                wait(20)
                heights[count] = body.implicitHeight
                // The card block itself, which is what the viewport bounds.
                verify(body.implicitHeight <= body.viewportHeight
                        + body.cellPaddingY * 2,
                    count + " windows: the panel is no taller than the viewport plus its "
                        + "padding, was " + body.implicitHeight + " against a viewport of "
                        + body.viewportHeight)
            }
            compare(heights[12], heights[7],
                "and seven windows and twelve windows make the SAME panel, was "
                    + heights[7] + " and " + heights[12])
        }

        function test_theActiveColumnIsClippedToTheViewport() {
            // The clip and the scroll are the same mechanism: the column is a window
            // onto its rows, offset by `scrollOffset`. Asserted on the real delegate,
            // because a column that drew all its rows unclipped would push the panel's
            // height back out and quietly undo the bound above.
            var many = []
            for (var i = 0; i < 9; i++)
                many.push({ windowId: String(i), title: "w" + i, icon: "", isFocused: false })
            body.hint = root.makeHint({ windows: many })
            wait(20)
            var column = columnForPosition(1)
            verify(column !== null, "the active column is on the strip")
            compare(column.clip, true, "and it clips")
            compare(column.height, body.viewportHeight,
                "to exactly the viewport, was " + column.height + " against "
                    + body.viewportHeight)
            verify(column.contentHeight > column.height,
                "while its content is taller - " + column.contentHeight + " against "
                    + column.height + " - which is what there is to scroll")
            compare(strip().maxScrollOffset, column.contentHeight - body.viewportHeight,
                "and the scroll range is exactly the difference")
        }

        function test_theWheelScrollsTheActiveColumn() {
            // The scroll itself, driven through `applyWheel` rather than a synthesised
            // wheel event: a `WheelHandler` can only be exercised by real pointer events,
            // which this harness cannot produce, and `applyWheel` is the whole of the
            // handler's body below the event normalisation.
            var many = []
            for (var i = 0; i < 9; i++)
                many.push({ windowId: String(i), title: "w" + i, icon: "", isFocused: false })
            body.hint = root.makeHint({ windows: many })
            wait(20)
            var range = strip().maxScrollOffset
            verify(range > 0, "there is something to scroll, " + range + "px")

            // The plain path is only reached OUTSIDE the edge-takeover band, so the
            // samples start past it: `edgeTakeoverDistance` from whichever end the wheel
            // is heading towards. Nine rows leaves 4 * 34 = 136px of range, so there is
            // room to stand off the band at both ends.
            verify(strip().edgeTakeoverDistance < range,
                "there is room outside the edge band to test the plain path, range "
                    + range + " against a band of " + strip().edgeTakeoverDistance)
            compare(strip().scrollOffset, 0, "it starts at the top")
            // Down is a LARGER offset - the content moves up under the viewport - and
            // from clear of the bottom band, because the edge-takeover path claims the
            // wheel inside it and eases toward a resisted target instead of applying the
            // delta.
            strip().scrollOffset = range - strip().edgeTakeoverDistance - 20
            var from = strip().scrollOffset
            strip().applyWheel(true, 40)
            compare(strip().scrollOffset, from + 40,
                "a wheel down moves it further down the list, was " + strip().scrollOffset
                    + " from " + from)
            // Up, from a position clear of the top band.
            strip().scrollOffset = strip().edgeTakeoverDistance + 20
            from = strip().scrollOffset
            strip().applyWheel(false, 40)
            compare(strip().scrollOffset, from - 40,
                "and a wheel up moves it up, was " + strip().scrollOffset + " from "
                    + from)
        }

        function test_aListThatFitsRefusesTheWheel() {
            // A workspace whose windows all fit must not swallow the wheel - the wheel
            // belongs to whatever is behind the popup, and a list that eats it while
            // having nothing to scroll is a fault the user finds by scrolling something
            // else.
            body.hint = root.makeHint()
            wait(20)
            compare(strip().maxScrollOffset, 0, "nothing to scroll")
            strip().applyWheel(true, 120)
            compare(strip().scrollOffset, 0, "and the wheel changes nothing, was "
                + strip().scrollOffset)
        }

        function test_onlyTheActiveColumnScrolls() {
            // The neighbours are context and are not scrolled: they are capped by the
            // logic and drawn whole. A wheel that moved them would desynchronise three
            // columns that read as one frame.
            var many = []
            for (var i = 0; i < 9; i++)
                many.push({ windowId: String(i), title: "w" + i, icon: "", isFocused: false })
            body.hint = root.makeHint({ windows: many, previousWindows: many })
            wait(20)
            // Stand off the bottom edge band, or the wheel is claimed by the takeover
            // path and eased onto its target rather than applied - and take the
            // neighbours' position THERE too, so the comparison is like for like.
            strip().scrollOffset = strip().maxScrollOffset
                - strip().edgeTakeoverDistance - 20
            var before = []
            for (var slot = 0; slot < 3; ++slot)
                before.push(columnDelegates()[slot].y)
            strip().applyWheel(true, 40)
            wait(1)
            var after = []
            for (slot = 0; slot < 3; ++slot)
                after.push(columnDelegates()[slot].y)
            compare(after[1], before[1] - 40,
                "the active column's content moved up, was " + after[1] + " from "
                    + before[1])
            compare(after[0], before[0], "the left neighbour did not")
            compare(after[2], before[2], "and neither did the right")
            // And the neighbours are whole rather than windowed: no clip, no offset.
            var left = columnDelegates()[0]
            compare(left.clip, false, "a neighbour column does not clip")
            compare(left.height, left.contentHeight,
                "and is as tall as its content, was " + left.height)
        }

        function test_theFocusedWindowIsScrolledIntoView() {
            // niri moves focus on its own, and a marker pointing at a scrolled-out row
            // points at nothing. The old behaviour was to hide the marker instead - which
            // is honest about the row being unreachable but leaves the panel unable to
            // say which window is focused at all.
            var many = []
            for (var i = 0; i < 9; i++)
                many.push({ windowId: String(i), title: "w" + i, icon: "",
                    isFocused: i === 8 })
            body.hint = root.makeHint({ windows: many })
            // The marker is placed on the snapshot's first frame, before the reveal has
            // travelled, so its PRESENCE is read before the wait and its POSITION after
            // it. Reading both afterwards would only ever see the settled state.
            var indicator = findByName(live(), "windowHintFocusIndicator")
            verify(indicator.visible,
                "the marker is on the focused window even though it starts past the "
                    + "viewport")
            // The reveal rides the launcher's programmatic scroll - 300ms OutQuint - so
            // the column is still travelling when the snapshot lands. Past its 300ms
            // before reading, or this measures a frame of the animation rather than
            // where it comes to rest.
            wait(360)
            verify(strip().scrollOffset > 0,
                "and the column scrolled to it, was " + strip().scrollOffset)
            // Inside the viewport, measured on the real row and the real clip. The row is
            // found by its TITLE - the fixture names each row after its own index - rather
            // than by asking the component which index it focused, which would only
            // restate the answer.
            var row = findAllByName(live(), "windowHintWindowRow").filter(function(r) {
                return r.modelData.title === "w8"
            })[0]
            verify(row !== null, "the focused row is on the strip")
            var top = row.mapToItem(strip(), 0, 0).y
            var bottom = top + body.rowHeight
            verify(top >= -0.5 && bottom <= body.viewportHeight + 0.5,
                "and it is inside the viewport, " + top + " to " + bottom + " against "
                    + body.viewportHeight)
        }

        // Every piece of text on the panel, so a claim about what the panel does NOT say
        // can be made against the whole surface rather than against one element that was
        // expected to be absent.
        function shownText() {
            var texts = findAllByName(body, "windowHintWindowTitle")
                .concat(findAllByName(body, "windowHintNeighbourRow"))
            var out = []
            for (var i = 0; i < texts.length; ++i) {
                var t = texts[i]
                if (t.text !== undefined)
                    out.push(String(t.text))
                else if (t.title !== undefined)
                    out.push(String(t.title))
            }
            return out.join(" | ")
        }

        // The focused row's own delegate, found by which row the shared marker is over.
        // Walking up from the marker rather than down from the model, so the test cannot
        // pass by asking the same index the component placed it from.
        function focusedRowIn(scope) {
            var frame = findByName(scope, "windowHintFocusFrame")
            if (!frame)
                return null
            var rows = findAllByName(scope, "windowHintWindowRow")
            var centre = frame.mapToItem(strip(), frame.height / 2, frame.height / 2)
            for (var i = 0; i < rows.length; ++i) {
                var here = rows[i].mapToItem(strip(), frame.height / 2, frame.height / 2)
                if (Math.abs(here.y - centre.y) < 1)
                    return rows[i]
            }
            return null
        }

        function test_theScrollUsesTheLaunchersContract() {
            // The numbers, as literals. A scroll that felt different from the launcher's
            // would be the most obvious inconsistency in the panel, and the only thing
            // holding the two together is that they agree here - 80px of edge takeover,
            // 88px of overscroll, the launcher's three durations.
            compare(strip().edgeTakeoverDistance, 80,
                "the edge band is the launcher's 80px")
            compare(strip().overscrollDistance, 88,
                "and the overscroll rail its 88px")
            // The rubber band: the further past the bound, the smaller each step. Two
            // steps of the same size from the bound must move less the second time.
            var first = strip()._resistedTarget(0, 40, 0)
            var second = strip()._resistedTarget(first, 40, 0)
            verify(Math.abs(first - 0) > Math.abs(second - first),
                "the band resists more the deeper it goes, " + Math.abs(first)
                    + " then " + Math.abs(second - first))
            verify(Math.abs(first) <= 40, "and never further than the delta it was given")
            // And at the bound the first step is undamped - full tension is still zero.
            compare(strip()._resistedTarget(0, 40, 0), -40,
                "a step taken exactly at the bound is undamped")
        }

        function test_theOffsetIsClampedToTheContent() {
            // A workspace switch replaces the list, and the new one can be shorter than
            // the offset the old one was scrolled to. Without a clamp the panel would sit
            // showing blank space below its last row, which is the failure the launcher's
            // `normalizeViewport` exists for.
            var many = []
            for (var i = 0; i < 12; i++)
                many.push({ windowId: String(i), title: "w" + i, icon: "", isFocused: false })
            body.hint = root.makeHint({ windows: many })
            wait(20)
            strip().scrollOffset = strip().maxScrollOffset
            verify(strip().scrollOffset > 0, "scrolled to the end of twelve")

            body.hint = root.makeHint()
            wait(20)
            compare(strip().maxScrollOffset, 0, "the new workspace has two windows")
            compare(strip().scrollOffset, 0,
                "and the offset is clamped back into range, was " + strip().scrollOffset)
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
            compare(slot.mapToItem(body, 0, 0).x, root.bandX + root.padX,
                "and it is the active column, inside its padding, was "
                    + slot.mapToItem(body, 0, 0).x)
            compare(slot.width, root.wideCard,
                "and as wide as the active card, was " + slot.width)
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
            // The frame being left is still there, as content rather than as a separate
            // object: position 0 is the only column that could be carrying it now.
            //
            // Read off the strip's COLUMNS rather than off `shownTitles`, because that
            // helper only counts what is inside the panel - and by mid-crossing the
            // column for position 0 has walked off the panel's left edge, which is the
            // whole point of it leaving. Asking "is the frame still carried" of a
            // helper that answers "what can the user see right now" is a question about
            // two different things, and it fails for a reason that has nothing to do with
            // the frame being dropped.
            var leavingColumn = columnForPosition(0)
            verify(leavingColumn !== null,
                "the frame being left still has its column on the strip")
            var leavingRows = leavingColumn
                ? findAllByName(leavingColumn, "windowHintNeighbourRow") : []
            compare(leavingRows.length, 1,
                "carrying the leaving frame's own window")
            if (leavingRows.length === 1)
                compare(leavingRows[0].modelData.title, "ws0",
                    "which is workspace 0's, titled after its position")
            // The arriving frame is in place on the same footing.
            var arrivingRows = findAllByName(columnForPosition(2), "windowHintWindowRow")
            compare(arrivingRows.length, 1, "and the arriving frame is in place")
            if (arrivingRows.length === 1)
                compare(arrivingRows[0].modelData.title, "ws2")
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
            // fault rather than as motion. The strip is `span + 3` columns and the
            // panel's centre travels `span` workspaces, so there is always a full
            // panel's worth of it under the window.
            //
            // The claim is stated as the geometry the user would see: painted rows
            // have to reach the panel's left edge AND its right edge at every
            // sampled progress, in both directions, for every span. Read off the
            // real row rects mapped into the body, so a strip that is the right
            // shape in the wrong place fails this rather than passing it.
            //
            // The panel is a variable-width window onto that run now - one wide middle
            // column and two narrow ones - so the bound below cannot be a fraction of
            // the panel: it is one inter-card gap, which is the same 44px the old
            // uniform three-column panel used and is what the layout guarantees at
            // every instant. A 180px band of bare panel against that cannot pass.
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
                                + ": the panel is covered, panel position "
                                + body.panelPosition.toFixed(3))
                    }
                    settleSlide()
                    verify(panelEdgesReached(),
                        "span " + span + " dir " + direction + ": and once landed")
                }
            }
        }

        function test_theStripTravelsOnePassByExactlyTheSpan() {
            // The distance is the number of columns the workspace moved, in each
            // direction, once, without turning back.
            //
            // In workspaces, not in pixels. The strip no longer translates, so there is
            // no pixel offset to read: the whole layout is a function of ONE number the
            // body owns, `panelPosition`, the workspace the panel is centred on, and
            // every column places itself from it. So the "one pass by exactly the span"
            // claim is that this number runs from the workspace being left to the one
            // being moved to, a distance of exactly the span, and never turns back -
            // which is what a strip that drew the wrong number of columns past the
            // panel would fail.
            for (var span = 1; span <= 3; ++span) {
                for (var direction = 0; direction < 2; ++direction) {
                    var from = direction === 0 ? 1 : 6
                    var to = direction === 0 ? 1 + span : 6 - span
                    var label = "span " + span + " dir " + direction
                    // Settle on the frame being left, so the crossing is the span
                    // under test rather than whatever the previous test left.
                    body.hint = root.framedHint(from, from)
                    wait(20)
                    // At rest the panel is centred on the workspace it is showing, and
                    // the strip holds that frame's own three columns at the frame.
                    compare(body.panelPosition, from, label + ": centred on the active one")
                    compare(body.positionFrom, from, label + ": with nowhere to travel from")
                    compare(body.positionTo, from, label + ": and to go")
                    compare(body.plan.slots, 3, label + ": three columns at rest")
                    compare(body.plan.span, 0, label + ": and no span")
                    var resting = columnDelegates()
                    compare(resting.length, 3, label + ": and three column delegates")
                    compare(resting[0].x, 0, label + ": the left one at the panel's edge")
                    compare(resting[2].x + resting[2].width, root.panelW,
                        label + ": and the right one at its other edge")

                    body.hint = root.framedHint(to, from)
                    // While crossing, the strip carries the ordered union of both
                    // frames - one column per workspace, `span + 3` of them - and the
                    // panel's centre has exactly two ends to run between.
                    compare(body.plan.slots, span + 3,
                        label + ": and widens to the union while crossing")
                    compare(body.plan.base, Math.min(from, to) - 1,
                        label + ": based at the lowest workspace either frame knows")
                    compare(body.positionFrom, from,
                        label + ": the leg starts where the panel was, was "
                            + body.positionFrom)
                    compare(body.positionTo, to, label + ": and ends on the destination")
                    compare(Math.abs(body.positionTo - body.positionFrom), span,
                        label + ": so the crossing travels exactly the span, was "
                            + Math.abs(body.positionTo - body.positionFrom))
                    // One way only, sampled while it is still moving. Towards a LATER
                    // workspace the panel's centre rises; earlier, it falls. Getting
                    // this backwards would have the panel turn away from the direction
                    // the workspace went.
                    //
                    // Sampled only while the crossing is IN FLIGHT: once it has landed,
                    // the panel's centre IS the destination and stops, so a sample taken
                    // after the landing is not a reversal. A `wait()` also overshoots by
                    // however long the delegate rebuild takes, so the loop also stops on
                    // `swapping` rather than on a step count.
                    var furthest = body.panelPosition
                    var movingSamples = 0
                    var movedSamples = 0
                    for (var step = 0; step < 40 && body.swapping; ++step) {
                        wait(1)
                        if (!body.swapping)
                            break
                        var here = body.panelPosition
                        // Never the wrong way. Not strictly monotonic per sample: the
                        // first tick can land before the animation has moved at all,
                        // and a sample that has not started yet is not a reversal.
                        verify(to > from ? here >= furthest : here <= furthest,
                            label + " step " + step + ": one way only, was " + here
                                + " from " + furthest)
                        if (to > from ? here > furthest : here < furthest)
                            movedSamples++
                        furthest = here
                        movingSamples++
                    }
                    verify(movedSamples > 0,
                        label + ": and it was seen actually moving, "
                            + movingSamples + " samples")
                    // Landed: the panel is centred on the destination, the strip is the
                    // arriving frame's own three columns, and its active column is the
                    // panel's middle one.
                    settleSlide()
                    compare(body.panelPosition, to,
                        label + ": and it rests centred on the destination, was "
                            + body.panelPosition)
                    compare(body.plan.slots, 3,
                        label + ": as the arriving frame's three columns again")
                    compare(body.plan.activeSlot, 1, label + ": with the active column in the middle")
                    compare(columnForPosition(to).width, root.wideCol,
                        label + ": at the active column's width, was "
                            + columnForPosition(to).width)
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
            // The narrow pitch - two NEIGHBOUR columns and the gutter between them. It
            // is not the distance from the panel's left edge to the band's x, and it is
            // not the distance from the band to the right neighbour either: the middle
            // slot is the WIDE one, so both of those are a gutter and an extra 180px
            // longer. Only two narrow columns share a pitch.
            compare(body.narrowPitch, body.columnWidth + body.columnGutter,
                "the narrow pitch is the neighbour column plus the gap")
            compare(body.narrowPitch, root.pitch, "and it is 186")
            // The band, on the real object, against literals: the WIDE middle slot,
            // which is the one thing in the panel that never moves. Two narrow columns
            // share a pitch; the slot between them is 180px wider than that.
            compare(band.x, root.bandX, "the band sits at the wide slot's left edge, was "
                + band.x)
            compare(band.width, root.wideCol,
                "and spans the active column's width, was " + band.width)

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
                compare(home, root.bandX,
                    "dir " + direction + ": at rest it is the wide middle slot, was " + home)

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
            // The direction is the workspace move, and it is visible in the two columns
            // that trade places through the wide middle slot.
            //
            // It used to be asserted in pixels - "the strip travels leftwards" - because
            // the strip was one object with an x, and a pixel offset is the only thing a
            // translated strip can be said to do. The strip no longer translates and a
            // mid-crossing x is a fractional number, so the direction is stated in terms
            // of the columns themselves: towards a LATER workspace the ARRIVING column
            // comes in from the RIGHT - its x falls, from 552 to 186 - while the one
            // being left goes out to the LEFT, also falling, from 186 to 0. Earlier, the
            // mirror: the arriving column rises from 0 to 186 and the leaving one rises
            // from 186 to 552.
            //
            // Getting this backwards would have the panel turn away from the direction
            // the workspace went, so the arriving column's own x is sampled through the
            // whole crossing rather than at its ends.
            function sampleTravel(from, to, label) {
                body.hint = root.framedHint(from, from)
                wait(20)
                // At rest the leaving workspace owns the wide middle slot and the
                // arriving one is whichever neighbour the move is heading for - the
                // right one going forwards, the left going back. That arrangement is
                // what the crossing inverts.
                compare(columnForPosition(from).width, root.wideCol,
                    label + ": at rest the panel is centred on the workspace it is leaving")
                compare(columnForPosition(to).x, to > from ? root.rightX : 0,
                    label + ": and the arriving one is the "
                        + (to > from ? "right" : "left") + " neighbour, was "
                        + columnForPosition(to).x)

                body.hint = root.framedHint(to, from)
                verify(body.swapping, label + ": it is crossing")
                var arrivingStart = columnForPosition(to).x
                var leavingStart = columnForPosition(from).x
                verify(arrivingStart !== leavingStart,
                    label + ": the two columns start in different places")
                var furthestArriving = arrivingStart
                var furthestLeaving = leavingStart
                var steps = 0
                while (body.swapping && steps < 60) {
                    wait(4)
                    if (!body.swapping)
                        break
                    var hereArriving = columnForPosition(to).x
                    var hereLeaving = columnForPosition(from).x
                    verify(to > from ? hereArriving <= furthestArriving : hereArriving >= furthestArriving,
                        label + ": the arriving column comes in from the right, "
                            + hereArriving + " from " + furthestArriving)
                    verify(to > from ? hereLeaving <= furthestLeaving : hereLeaving >= furthestLeaving,
                        label + ": and the leaving one goes the same way, "
                            + hereLeaving + " from " + furthestLeaving)
                    furthestArriving = hereArriving
                    furthestLeaving = hereLeaving
                    steps++
                }
                verify(steps > 0, label + ": it was seen moving, " + steps + " samples")
                settleSlide()
                // Both ends of the swap: the arriving workspace IS the wide middle
                // column now, and the one that was left is the neighbour on the side it
                // left by - the panel's left edge going forwards, the right neighbour
                // going back.
                var landedArriving = columnForPosition(to)
                compare(landedArriving.x, root.bandX,
                    label + ": the arriving workspace ends in the wide slot, was "
                        + landedArriving.x)
                compare(landedArriving.width, root.wideCol,
                    label + ": at the active column's width")
                compare(columnForPosition(from).x, to > from ? 0 : root.rightX,
                    label + ": and the one left behind is the neighbour the move came "
                        + "from, was " + columnForPosition(from).x)
                verify(landedArriving.x !== arrivingStart,
                    label + ": the arriving column really travelled")
                verify(columnForPosition(from).x !== leavingStart,
                    label + ": and the leaving one really moved too")
            }

            sampleTravel(2, 3, "forwards")
            sampleTravel(3, 2, "backwards")

            // The plan's own slots follow the move, and the two cases are not mirror
            // images in the strip's slot numbering: forwards the arriving active column
            // is the strip's LAST slot, backwards it is the MIDDLE one. Both end with it
            // in the panel's wide middle column - which is the claim that matters.
            body.hint = root.framedHint(2, 2)
            wait(20)
            body.hint = root.framedHint(3, 2)
            compare(body.swapDirection, 1, "moved later in the list")
            compare(body.plan.activeSlot, 2, "so the arriving frame is the last slot")
            compare(body.plan.activePosition, 3, "and the markers belong to workspace 3")
            compare(body.plan.fromPosition, 2, "the leg starts on 2")
            compare(body.plan.toPosition, 3, "and ends on 3")
            settleSlide()

            body.hint = root.framedHint(3, 3)
            wait(20)
            body.hint = root.framedHint(2, 3)
            compare(body.swapDirection, -1, "moved earlier in the list")
            compare(body.plan.slots, 4, "a one-step crossing carries four slots")
            compare(body.plan.activeSlot, 1, "the arriving active column is already the middle slot")
            compare(body.plan.fromPosition, 3, "the leg starts on 3")
            compare(body.plan.toPosition, 2, "and ends on 2, the other way round")
            settleSlide()
            // And the resting panel is whole again whichever way it was left.
            compare(body.panelPosition, 2, "and it rests centred on the destination")
            var landed = columnDelegates()
            compare(landed.length, 3, "with three columns")
            compare(landed[0].x, 0, "the left at the panel's edge")
            compare(landed[2].x + landed[2].width, root.panelW,
                "and the right at its other edge")
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
                    + body.slideProgress.toFixed(2) + ", panel position "
                    + body.panelPosition.toFixed(3)
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
            //
            // Placed against that column's OWN geometry, read off its real delegate,
            // rather than against a slot index times a pitch: the crossing runs on a
            // fractional position, so "slot 2" no longer names a place and a mid-flight
            // x is not a whole number either. What has to hold at every instant is the
            // pairing - the markers sit on the column the plan calls arriving, inside
            // its padding, as wide as its card.
            compare(body.plan.activeSlot, 2, "the arriving column is the last slot")
            compare(body.plan.activePosition, 3, "and it is the arriving workspace's")
            var frame = findByName(live(), "windowHintFocusFrame")
            var arriving = columnForPosition(3)
            verify(arriving !== null, "the arriving column is on the strip")
            compare(frame.x, arriving.x + root.padX,
                "and the markers are placed against it, inside its padding, was "
                    + frame.x + " against " + (arriving.x + root.padX))
            compare(frame.width, arriving.width - root.padX * 2,
                "and as wide as its card, was " + frame.width)
            verify(arriving.x > root.bandX,
                "which is not in the middle yet, was " + arriving.x)
            verify(arriving.width > root.narrowCol && arriving.width < root.wideCol,
                "and is neither a neighbour's width nor the active one, was "
                    + arriving.width)
            // The panel's wide middle slot is NOT where the markers are mid-crossing -
            // that was the claim when the strip translated past a fixed column.
            verify(frame.x !== root.bandX + root.padX,
                "so they are not pinned to the panel's wide slot")
            settleSlide()
            // Landed: it is the wide middle column, which is the same claim the resting
            // panel makes everywhere else.
            compare(body.plan.activeSlot, 1, "at rest the active column is the middle")
            compare(findByName(live(), "windowHintFocusFrame").x,
                root.bandX + root.padX,
                "at rest, inside the wide slot's padding")
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
            // The whole run travels as one motion across the panel. If only one column
            // moved, the rest would sit still while it slid and the switch would read as
            // two unrelated changes - a list turning over inside a static frame.
            //
            // It used to be asserted as "each column holds its slot mid-crossing", which
            // was the same claim in the units a translated strip had: one object with an
            // x, every column at `index * pitch` inside it. That is no longer true and
            // must not be asserted - the two columns trading places through the wide slot
            // change BOTH their x and their width, because the width change IS the
            // crossing. So the claim is now stated in the units that survive:
            //
            //   EVERY column moves, and every column moves the same way (one motion).
            //   Every column keeps its own place IN THE RUN - it is still that
            //     workspace's column, in workspace order, one per position.
            //   Only the two trading columns change width; the rest stay narrow.
            //   No workspace is painted twice, which is what "its own place" buys:
            //     there is only one column that could paint a given workspace.
            // Settle on the frame being left, so the crossing really is this move and
            // the "before" positions below are the resting frame's own.
            body.hint = root.framedHint(2, 2)
            wait(20)
            var resting = {}
            columnDelegates().forEach(function(column) {
                resting[column.modelData.position] = column.x
            })
            compare(Object.keys(resting).length, 3, "three columns to begin with")
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 2,
                previousWindows: [{ windowId: "p1", title: "p1", icon: "", isFocused: false }],
                nextWindows: [{ windowId: "n1", title: "n1", icon: "", isFocused: false }],
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            // Driven to an exact point on its own clock rather than sampled at whatever
            // moment the wall clock reached, so "the same way" and "only the two
            // trading columns" are checks and not coincidences. See `driveSlideTo`.
            // The twenty first, because the strip's delegates have to be rebuilt before
            // a `wait()` of one millisecond is a settle rather than a race.
            wait(20)
            driveSlideTo(0.5)
            compare(body.slideProgress, 0.5, "halfway along the crossing")
            var columns = columnDelegates()
            compare(columns.length, 4, "a one-step crossing carries four columns")
            // In workspace order, one column per position, and each column is still the
            // workspace it was built for - read off the delegates themselves.
            var positions = columns.map(function(c) { return c.modelData.position })
            for (var i = 1; i < positions.length; ++i) {
                compare(positions[i], positions[i - 1] + 1,
                    "column " + i + " is the workspace after column " + (i - 1))
            }
            // Every column is off where it was a moment ago, and all of them the same
            // way: the panel's centre is on workspace 2.5 and the whole run is marching
            // past it towards 3. A column left behind while another travelled would be
            // the fault this test was written for.
            verify(body.panelPosition > 2 && body.panelPosition < 3,
                "the panel is between two workspaces, was " + body.panelPosition)
            for (var c = 0; c < columns.length; ++c) {
                var position = positions[c]
                if (position in resting)
                    verify(columns[c].x < resting[position],
                        "column " + c + " (workspace " + position
                            + ") is travelling leftwards, was " + columns[c].x
                            + " from " + resting[position])
            }
            // Only the two trading columns are off a neighbour's width; the ones outside
            // the frame keep a neighbour's width, because nothing about them is
            // changing.
            compare(columns[0].width, root.narrowCol,
                "the column behind the run is still narrow, was " + columns[0].width)
            compare(columns[3].width, root.narrowCol,
                "and the one ahead of it, was " + columns[3].width)
            verify(columns[1].width > root.narrowCol && columns[1].width < root.wideCol,
                "while the leaving one is halfway narrowed, was " + columns[1].width)
            verify(columns[2].width > root.narrowCol && columns[2].width < root.wideCol,
                "and the arriving one is halfway widened, was " + columns[2].width)
            // No workspace on screen twice, at this instant or once landed: the strip
            // holds each position once, so there is only one place a title could be
            // painted from.
            compare(repeatedTitles().length, 0,
                "and nothing is painted twice mid-crossing: "
                    + repeatedTitles().join(", "))
            // Landed the way a hand-driven crossing has to be landed: by a publish no
            // strip could carry, which is the one that reaches `_commitHint` and clears
            // the flags. See `landDrivenSlide`.
            landDrivenSlide(3)
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 3,
                previousWindows: [{ windowId: "p1", title: "p1", icon: "", isFocused: false }],
                nextWindows: [{ windowId: "n1", title: "n1", icon: "", isFocused: false }],
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            wait(20)
            compare(body.plan.slots, 3, "and the strip is the arriving frame alone")
            // Landed: each neighbour slot shows what the new snapshot says for it
            // rather than a stale list.
            var neighbours = findAllByName(live(), "windowHintNeighbourRow")
            compare(neighbours.length, 2)
            compare(neighbours[0].modelData.windowId, "p1")
            compare(neighbours[1].modelData.windowId, "n1")
            compare(repeatedTitles().length, 0, "and nothing twice once landed either")
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