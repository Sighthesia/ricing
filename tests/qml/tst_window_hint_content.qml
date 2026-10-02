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
    width: 480
    height: 400

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

    // The body paints two copies of the strip mid-slide - the one leaving and the
    // one arriving - and both use the same objectNames, because they are the same
    // component. So a search rooted at the body would find every row twice, and a
    // count or a position assertion would be about neither copy. Most tests want
    // the content the user is looking at, which is the incoming layer; the slide
    // tests ask for the outgoing one by name.
    //
    // Both helpers root their own search at `body` and must never be rewritten to
    // call each other: `live()` walking itself is the infinite recursion that
    // blows the stack.
    function live() {
        return findByName(body, "windowHintIncomingLayer") || body
    }

    function outgoing() {
        return findByName(body, "windowHintOutgoingLayer")
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
            compare(findAllByName(live(), "windowHintWindowRow").length, 2)
        }

        // ---- the three columns -------------------------------------------
        function test_bodyRendersThreeColumnsPreviousActiveNext() {
            // Left / middle / right are the workspace before, the active one and
            // the workspace after - in that order, so the workspace you are on
            // is always in the same place. The order is asserted by position, not
            // by existence: three sets of rows that exist is not the same claim
            // as three columns that are in the right places.
            var previous = findByName(live(), "windowHintPreviousColumn")
            var active = findByName(live(), "windowHintColumn")
            var next = findByName(live(), "windowHintNextColumn")
            verify(previous && active && next, "all three columns exist")
            verify(previous.x + previous.width <= active.x, "previous is leftmost")
            verify(active.x + active.width <= next.x, "next is rightmost")
            compare(findAllByName(live(), "windowHintPreviousRow").length, 1)
            compare(findAllByName(live(), "windowHintNextRow").length, 1)
            // Each column shows its OWN workspace's window, not a copy of the
            // active one - a neighbour that listed the active workspace's
            // windows would be decoration pretending to be information.
            compare(findByName(live(), "windowHintPreviousRow").modelData.windowId, "20")
            compare(findByName(live(), "windowHintNextRow").modelData.windowId, "30")
        }

        function test_neighbourColumnsCarryNoState() {
            // Only the active column holds focus, so a card, a highlight or an
            // indicator on a neighbour would claim a second selection. The
            // neighbour labels are plain text over the panel's own surface.
            var previous = findAllByName(live(), "windowHintPreviousRow")[0]
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
            var row = findAllByName(live(), "windowHintNextRow")[0]
            mouseClick(row, row.width / 2, row.height / 2, Qt.LeftButton)
            compare(reported.window, "30")
        }

        function test_stateMarkersSitOnTheActiveColumn() {
            // The active column is the MIDDLE slot, so a highlight left at x 0
            // would be drawn under the previous workspace's labels and none of it
            // would be visible over the row it is supposed to mark. The rows are
            // positioned inside their column, so root-space is column.x + row.x.
            var rows = findAllByName(live(), "windowHintWindowRow")
            var active = findByName(live(), "windowHintColumn")
            var wash = findByName(live(), "windowHintFocusFrame")
            var bar = findByName(live(), "windowHintFocusIndicator")
            var previous = findByName(live(), "windowHintPreviousColumn")
            compare(wash.x, active.x + rows[0].x, "the highlight starts where the row starts")
            compare(wash.width, active.width, "and spans the column")
            // The previous column ends exactly where the active one begins, so
            // the check is that the highlight does not reach back over it.
            compare(wash.x, previous.x + previous.width,
                "and starts where the previous column ends")
            verify(bar.x >= wash.x && bar.x < wash.x + wash.width,
                "the indicator is on the highlight")
            // ...and the same on the far side, or the highlight would cover the
            // next workspace's labels.
            var next = findByName(live(), "windowHintNextColumn")
            verify(wash.x + wash.width <= next.x, "and stops before the next column")
        }

function test_anEmptyNeighbourKeepsItsSlotAndSaysSo() {
            // An empty neighbour workspace must not shrink the panel. It used to:
            // the column took no slot, the panel narrowed, and the active workspace
            // moved out of the middle - so the same three workspaces read as a
            // different panel depending on what the neighbours were running. Now
            // the slot stays and the column states the fact itself, because a blank
            // column would read as a layout fault rather than as "nothing here".
            body.hint = root.makeHint({ previousWindows: [] })
            wait(20)
            verify(findByName(live(), "windowHintPreviousColumn"), "the column is still there")
            compare(findAllByName(live(), "windowHintPreviousRow").length, 0, "and holds no row")
            var empty = findByName(live(), "windowHintPreviousEmpty")
            verify(empty !== null, "the empty neighbour shows something")
            verify(empty.visible, "and it is visible")
            compare(findByName(empty, "windowHintEmptySlotLabel").text, "No windows",
                "which is that it has no windows")
            compare(findAllByName(live(), "windowHintNextRow").length, 1, "the other side is unaffected")
            verify(!findByName(live(), "windowHintNextEmpty").visible,
                "and does not claim to be empty when it is not")
            // The frame is unchanged, and the active workspace is still the middle.
            compare(body.shownColumnCount, 3)
            compare(body.width, 3 * body.columnWidth, "the panel did not resize")
            var active = findByName(live(), "windowHintColumn")
            var next = findByName(live(), "windowHintNextColumn")
            compare(active.x, body.columnWidth, "active is still the middle column")
            compare(next.x, body.columnWidth * 2, "and next is still the last")
            compare(findByName(live(), "windowHintFocusFrame").x, active.x,
                "and the highlight is still on the active column")
        }

        function test_thePanelIsThreeColumnsWideWhateverTheNeighboursHold() {
            // The one case that broke it: both neighbours empty. A panel that
            // reports one column here is a panel that resizes under the pointer as
            // the user moves between the edge workspace and an interior one.
            body.hint = root.makeHint({ windows: [], previousWindows: [], nextWindows: [] })
            wait(20)
            compare(body.shownColumnCount, 3, "three columns")
            compare(body.width, 3 * body.columnWidth, "the same width as always")
            // All three columns say they are empty, each in its own slot.
            // All three, each in its own slot - the middle one is not a special
            // case, because an empty workspace is the same fact wherever it is.
            verify(findByName(live(), "windowHintPreviousEmpty").visible)
            verify(findByName(live(), "windowHintActiveEmpty").visible,
                "and the active column uses the same placeholder")
            verify(findByName(live(), "windowHintNextEmpty").visible)
            compare(findByName(live(), "windowHintActiveEmpty").height, body.rowHeight,
                "each standing where a row would")
            // Three columns at three distinct offsets - the frame is intact.
            compare(findByName(live(), "windowHintPreviousColumn").x, 0)
            compare(findByName(live(), "windowHintColumn").x, body.columnWidth)
            compare(findByName(live(), "windowHintNextColumn").x, body.columnWidth * 2)
        }

        function test_thePanelIsAsWideAsItsColumns() {
            // The host sizes the input slot from this number, so it has to be the
            // count times the column width and nothing else - a stray padding term
            // would leave a band of input region beside a narrower panel.
            compare(body.width, body.shownColumnCount * body.columnWidth)
            compare(body.shownColumnCount, 3)
            compare(body.width, 3 * body.columnWidth)
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
                var active = findByName(live(), "windowHintColumn")
                compare(active.x, body.columnWidth,
                    "combination " + i + ": active is the middle column")
                // And centred on the panel, not merely second of three.
                compare(active.x + active.width / 2, body.width / 2,
                    "combination " + i + ": and centred on the panel")
            }
        }

        function test_columnsShareOneRowPitch() {
            // The focus indicator computes its y from the active column's pitch
            // alone. If a neighbour column used a different spacing, the three
            // lists would not line up across the panel and the panel would read
            // as three unrelated stacks.
            var previous = findByName(live(), "windowHintPreviousColumn")
            var active = findByName(live(), "windowHintColumn")
            var next = findByName(live(), "windowHintNextColumn")
            compare(previous.spacing, active.spacing, "previous matches the active pitch")
            compare(next.spacing, active.spacing, "next matches it too")
            compare(previous.width, active.width, "and the columns are peers in width")
            compare(next.width, active.width)
            // The slots are derived from the panel width, not accumulated by a
            // layout pass, so each column knows where it belongs.
            compare(previous.x, 0, "previous takes the first slot")
            compare(active.x, body.columnWidth, "active the second")
            compare(next.x, body.columnWidth * 2, "next the third")
        }

        function test_theWholePanelArrivesInOnePiece() {
            // No row is left behind and none arrives on its own. A switch used to
            // stagger the three columns in row by row, which meant the panel was
            // briefly three different heights' worth of half-drawn content; now it
            // is displaced as one object, so every row of every column crosses at
            // the same time and none of them is ever partially faded in.
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
            // Sampled DURING the slide, which is the only time the two layers are
            // both on screen.
            wait(Math.round(body.slideDuration / 2))
            verify(body.swapping, "still crossing")
            var previous = findAllByName(live(), "windowHintPreviousRow")
            var active = findAllByName(live(), "windowHintWindowRow")
            var next = findAllByName(live(), "windowHintNextRow")
            compare(previous.length, 3, "every neighbour row is there")
            compare(active.length, 3, "and every active one")
            compare(next.length, 3, "and the far side too")
            // All opaque: a row that faded in on its own would be a hole in the
            // displacement, and the point of the two layers is that there is none.
            for (var r = 0; r < 3; ++r) {
                verify(active[r].opacity > 0.9, "active row " + r + " is solid")
                verify(previous[r].opacity > 0.9, "previous row " + r + " is solid")
                verify(next[r].opacity > 0.9, "next row " + r + " is solid")
            }
            // And the outgoing copy is solid too, since it is a rigid body sliding
            // off rather than a list dissolving.
            // The copy that is leaving is the PREVIOUS content - the two windows
            // the init snapshot installed. It has to be whole and opaque, because
            // it is a rigid body sliding off rather than a list dissolving, and it
            // must not already have become the new list.
            var leaving = findAllByName(outgoing(), "windowHintWindowRow")
            compare(leaving.length, 2, "the copy that is leaving is whole")
            compare(leaving[0].modelData.windowId, "10", "and is the OLD content")
            verify(leaving[0].opacity > 0.9, "and opaque")
            settleSlide()
        }

        function test_bodyShowsNothingButTheList() {
            // The panel is body-only: no workspace strip, no header, no
            // divider. Anything here is a copy of what the bar already shows or
            // of what the rows themselves say.
            verify(findByName(live(), "windowHintWorkspaceChip") === null)
            verify(findByName(live(), "windowHintDivider") === null)
            verify(findByName(live(), "windowHintStrip") === null)
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
        function test_rowsDoNotPaintTheirOwnFocusFill() {
            // The focus highlight is the one shared element that glides. A row
            // that also tinted itself would put two fills on screen and read as
            // two different states - and during the glide neither row is focused
            // anyway, so the per-row fill would simply be gone.
            var rows = findAllByName(live(), "windowHintWindowRow")
            compare(rows[0].color, Lazer.LazerTheme.settingsCard)
            compare(rows[1].color, Lazer.LazerTheme.settingsCard,
                "the focused row paints no fill of its own")
            // A Rectangle borders itself by default; the shared highlight is the
            // only focus signal here.
            compare(rows[0].border.width, 0)
        }

        function test_focusHighlightIsTheOnlyFocusFill() {
            // Exactly one element carries the focus fill for the whole list.
            var wash = Lazer.LazerTheme.settingsSelected
            var rows = findAllByName(live(), "windowHintWindowRow")
            var filled = rows.filter(function(r) { return r.color === wash })
            compare(filled.length, 0, "no row carries it")
            compare(findByName(live(), "windowHintFocusFrame").color, wash, "the shared one does")
        }

        function test_indicatorClearsTheGlyph() {
            // The indicator sits at the highlight's own left edge, so the row
            // needs a real left margin or the bar ends a pixel before the icon
            // begins. The gutter is derived, not a literal, so moving either the
            // marker or the glyph cannot silently close it up again. Measured
            // from the ACTIVE column's edge, which is now the middle one.
            var rows = findAllByName(live(), "windowHintWindowRow")
            var wash = findByName(live(), "windowHintFocusFrame")
            var bar = findByName(live(), "windowHintFocusIndicator")
            var icon = findByName(live(), "windowHintWindowIcon")
            compare(icon.x, rows[0].children[0].x, "glyphs share one inset")
            var gap = icon.x - (bar.x - wash.x + bar.width)
            compare(gap, 12, "and keep a 12px gutter clear of the marker")
            verify(gap >= 8, "a gutter, not a hairline")
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
            var active = findByName(live(), "windowHintColumn")
            compare(frame.height, rows[1].height)
            compare(frame.x, active.x + rows[1].x, "starts where the row starts")
            compare(frame.width, rows[1].width, "and is exactly as wide")
            compare(frame.radius, rows[1].radius, "corners match the row's")
            compare(frame.border.width, 0, "a fill, not an outline")

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
            // Same tokens as the workspace indicator, turned 90 degrees for a
            // list that travels vertically: its thickness is that bar's height,
            // and its resting length is that bar's width.
            compare(bar.width, Lazer.LazerTheme.barIndicatorHeight)
            compare(bar.radius, Lazer.LazerTheme.barIndicatorRadius)
            compare(bar.color, Lazer.LazerTheme.osuGreen)
            compare(bar.height, 16)
            verify(bar.visible, "the focused row is on screen, so the bar is")
        }

        function test_indicatorStretchesAlongItsOwnLongAxis() {
            // The reason it is vertical: the workspace bar elongates along its
            // long axis, so this one must too. Stretching the short axis would
            // turn a bar into a rectangle mid-flight.
            var bar = findByName(live(), "windowHintFocusIndicator")
            compare(bar.width, Lazer.LazerTheme.barIndicatorHeight, "stays bar-thin")
            verify(bar.height >= 16, "at least its resting length")
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
            compare(bar.x - wash.x, 4, "sits inside the active column's left edge")
            // Root space: the bar is a child of the panel, the row of its column.
            var active = findByName(live(), "windowHintColumn")
            verify(bar.x + bar.width < active.x + rows[1].x + rows[1].width,
                "and within the row")
        }

        // Wait out the indicator's dual-speed tracker. The head lands in `medium`, but
        // the tail runs `slow * 2` on OutSine, which starts slowly - so anything
        // that switched an indicator target is still stretched long after the
        // head has arrived, and a position read before then is a frame of the
        // elongation rather than the settled bar.
        function settleIndicator() {
            wait(Lazer.MotionTokens.slow * 2 + 150)
        }

        // Wait out one full crossing. The slide is two phases on one clock with
        // no stagger behind them, so the declared total is the whole of it - plus
        // room for the animation's `onFinished` to have released the held copy.
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
            verify(bars[0].height > 16, "stretched while the tail trails")
            compare(bars[0].width, Lazer.LazerTheme.barIndicatorHeight, "still bar-thin")

            settleIndicator()
            var settled = findByName(live(), "windowHintFocusIndicator")
            var rows = findAllByName(live(), "windowHintWindowRow")
            compare(settled.height, 16, "contracted on arrival")
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
            compare(findByName(live(), "windowHintOverflow").text, "+3 more windows")
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
            var slot = findByName(live(), "windowHintActiveEmpty")
            verify(slot.visible, "the active column shows its placeholder")
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
            var rows = findAllByName(live(), "windowHintWindowRow")
            verify(rows.length > 0 || slot.height > 0, "a row-height placeholder")
        }

        function test_aPlaceholderIsHiddenWhenTheColumnHasWindows() {
            // The other half of the same contract: a column with windows must not
            // also show an empty slot, or every row would be doubled by a ghost.
            body.hint = root.makeHint()
            wait(20)
            verify(!findByName(live(), "windowHintPreviousEmpty").visible)
            verify(!findByName(live(), "windowHintActiveEmpty").visible)
            verify(!findByName(live(), "windowHintNextEmpty").visible)
        }

        function test_coldSnapshotStatesItself() {
            body.hint = null
            wait(20)
            compare(findAllByName(live(), "windowHintWindowRow").length, 0)
            verify(findByName(body, "windowHintEmpty").visible)
        }

        // ---- switching between workspaces --------------------------------
        function test_workspaceSwitchHoldsTheOutgoingRowsWhileTheyLeave() {
            // A workspace switch replaces every row, so the outgoing ones have to
            // still be mounted while they travel off - otherwise the panel's
            // contents are simply gone and remade between two frames. This is the
            // part a depth-1 hold buys.
            compare(body.swapping, false, "settled to begin with")
            compare(outgoing().visible, false, "and nothing is held")

            body.hint = root.makeHint({
                workspaceId: "43",
                workspaceIndex: 3,
                activeWorkspacePosition: 2,
                previousActiveWorkspacePosition: 1,
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            verify(body.swapping, "sliding")
            verify(outgoing().visible, "the outgoing layer is mounted")
            // An animation reads its start value on the frame it starts, so the
            // travel has to be sampled after the event loop has turned.
            wait(Math.round(body.slideDuration / 2))
            var leaving = findAllByName(outgoing(), "windowHintWindowRow")
            compare(leaving.length, 2, "the outgoing rows are still mounted")
            compare(leaving[0].modelData.windowId, "10", "and are the OLD ones")
            var arriving = findAllByName(live(), "windowHintWindowRow")
            compare(arriving.length, 1, "while the new one is already in place")
            compare(arriving[0].modelData.windowId, "20")

            // Rows mid-slide are not tap targets on either side: what is under the
            // pointer is leaving, or has not arrived.
            verify(!leaving[0].enabled, "a row on the way out is not a tap target")
            verify(!arriving[0].enabled, "nor is the one on its way in")

            settleSlide()
            compare(body.swapping, false)
            compare(outgoing().visible, false, "the held copy is released")
            compare(findAllByName(outgoing(), "windowHintWindowRow").length, 0,
                "and its rows are gone with it")
            var after = findAllByName(live(), "windowHintWindowRow")
            compare(after.length, 1, "the new list has taken over")
            compare(after[0].modelData.windowId, "20")
            verify(after[0].enabled, "rows are tappable once landed")
        }

        function test_thePanelIsNeverLeftUncovered() {
            // The reason there are two layers. A single layer sliding out leaves a
            // band of empty panel on one side for the length of the travel, and a
            // hole in a panel reads as a layout fault rather than as motion. So the
            // two layers have to cover each other's vacated ground at every point
            // of the slide - which is a claim about the whole travel, not about
            // either end of it.
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 2,
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            var panelWidth = body.width
            for (var step = 0; step < 4; ++step) {
                wait(Math.round(body.slideDuration / 4))
                var out = outgoing()
                var inn = live()
                // The whole claim: the pair covers the panel from 0 to its width.
                // The outgoing copy's right edge and the arriving copy's left edge
                // meeting at one seam is what makes that true, so that identity is
                // asserted directly rather than inferred from the end positions.
                var seam = out.x + out.width
                compare(seam, inn.x, "step " + step + ": the two layers meet at one seam")
                verify(seam >= 0 && seam <= panelWidth,
                    "step " + step + ": and the seam is inside the panel, was " + seam)
                verify(out.x <= 0, "step " + step + ": the leaving copy has not uncovered the left")
                verify(inn.x + inn.width >= panelWidth,
                    "step " + step + ": nor the right")
            }
            settleSlide()
        }

        function test_bothLayersMoveTheSameWayAndTheSameDistance() {
            // One traverse, not a round trip, and the two layers exactly one panel
            // width apart in opposite directions. That identity is what keeps the
            // panel covered: the outgoing copy's right edge and the arriving copy's
            // left edge have to be the same number at every point of the slide, or
            // they open a gap or overlap and double-draw the rows.
            compare(live().x, 0, "the arriving layer rests at home")
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 2,
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            wait(Math.round(body.slideDuration / 2))
            var out = outgoing()
            var inn = live()
            // Moving to a LATER workspace takes the content LEFT, because the new
            // workspace was sitting to the right of the old one and has to cross to
            // reach the middle. Getting this backwards would have the panel turn
            // away from the direction the workspace went.
            verify(out.x < 0, "the outgoing copy has set off leftwards, was " + out.x)
            verify(inn.x > 0, "while the arriving one comes from the right, was " + inn.x)
            // One panel width apart, which is the number that makes the pair cover
            // the panel: the outgoing copy's right edge and the arriving copy's
            // left edge are then the same point, and the seam sweeps across.
            compare(inn.x - out.x, body.width, "exactly one panel width apart")
            compare(out.x + out.width, inn.x, "so the two layers meet at one seam")

            settleSlide()
            compare(live().x, 0, "the arriving layer landed at home")
            compare(outgoing().visible, false, "and the other one is gone")
        }

        function test_theCrossingUsesTheIndicatorsCurve() {
            // The contract, asserted as a recipe rather than by sampling: the
            // crossing borrows the focus indicator's two-speed motion, because that
            // is what reads as weight being carried. A head that commits fast and
            // a tail that lingers cannot be expressed as one ease - a symmetric
            // one leaves and arrives at the same rate, which is the shove.
            var phases = body.slideAnimation.animations
            compare(phases.length, 2, "the crossing is two phases, not one ease")
            compare(phases[0].to, body.slideHeadShare, "the head hands over at the share")

            // The SHAPE is the indicator's, checked against the indicator's own live
            // Behaviors rather than against `MotionTokens`: the same two curves, in
            // the same order. The CLOCKS deliberately differ - see the lunge bound
            // below - so comparing durations here would be asserting the bug.
            compare(phases[0].easing.type, body.indicatorHeadMotion.easing.type,
                "the departure runs on the indicator's head curve")
            compare(phases[1].easing.type, body.indicatorTailMotion.easing.type,
                "the settle runs on the indicator's tail curve")

            // The indicator's proportions: the tail is three times the head's flight,
            // which is what keeps the arrival lingering after the departure is done.
            verify(phases[1].duration >= 2 * phases[0].duration,
                "and the tail is the long half, was "
                    + phases[0].duration + " then " + phases[1].duration)
            verify(body.slideDuration >= phases[0].duration + phases[1].duration,
                "and the declared total covers both phases")

            // THE LUNGE BOUND. This is the assertion that replaces the duration
            // equality, and it is what the indicator's literal clocks cannot satisfy
            // on a panel-width travel: the indicator has 16px to cross and can put
            // its bar there in `medium`, but the same head clock throws most of a
            // panel's content across the screen before the settle starts. Measured
            // as average pixels-of-progress per millisecond over each phase, the
            // departure may be faster than the settle but must not be a bolt -
            // "70% in 160ms, then 30% over 480ms" is a throw followed by a crawl,
            // which is what the crossing was reported as feeling like.
            //
            // The ratio is computed HERE, from the component's own declared numbers
            // and its own width. The component states no speed and asserts nothing
            // about one, so this is a design rule stated independently of the
            // numbers it judges rather than a restatement of them.
            // Stated as a ratio with a float tolerance, not as a product: a bound
            // that the numbers can land exactly on must not fail on the rounding.
            var bound = 2.0
            var ratio = (body.slideHeadShare / phases[0].duration)
                / ((1 - body.slideHeadShare) / phases[1].duration)
            verify(ratio <= bound + 1e-6,
                "the departure is a departure and not a throw, ratio "
                    + ratio.toFixed(2) + "x the settle")
            verify(body.slideHeadShare < 0.5,
                "and it does not carry most of the crossing, was "
                    + body.slideHeadShare)

            // The panel's crossing gets more time than the indicator's own settle,
            // because it has the panel's width to cover rather than a bar's length.
            verify(body.slideDuration > body.indicatorTailMotion.duration,
                "and the whole crossing outlasts the indicator settling, was "
                    + body.slideDuration + " against " + body.indicatorTailMotion.duration)
            verify(body.hasOwnProperty("slideDip"), "and it dims a little in the middle")
        }

        function test_bothLayersDipTogetherSoTheSeamNeverShows() {
            // The softening dim is only safe because both layers take the SAME
            // value at the same moment. If they dipped independently the seam would
            // show one through the other, which is worse than no dim at all.
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 2,
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            var out = outgoing()
            var inn = live()
            compare(out.opacity, inn.opacity, "the same value")
            compare(out.opacity, 1, "and undimmed at rest")
            // Sampled at the middle, where the dip is deepest. `page / 2` is only
            // approximate, so this reads the peak rather than assuming it landed
            // exactly there.
            wait(Math.round(body.slideDuration / 2))
            out = outgoing()
            inn = live()
            compare(out.opacity, inn.opacity, "still the same value in flight")
            verify(out.opacity < 1, "and both have dipped, was " + out.opacity)
            // Shallow: enough to register as weight, not enough to read as a fade
            // - a fade at the seam is what the two layers exist to prevent.
            verify(out.opacity > 0.8, "but only slightly, was " + out.opacity)
            verify(out.opacity > 0, "and never to nothing")
            settleSlide()
            compare(live().opacity, 1, "and full again once landed")
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
            compare(outgoing().visible, false, "with nothing held on the way out")
            compare(findAllByName(outgoing(), "windowHintWindowRow").length, 0,
                "and the held copy released")
            wait(Math.round(body.slideDuration / 2))
            compare(body.slideProgress, 1, "and never starts one afterwards")
        }

        function test_theSlideIsOnePassAndDoesNotTurnBack() {
            // Progress runs 0 to 1 once. A value that overshot and came back would
            // be a bounce, and the whole point of the two layers is that the motion
            // is a single displacement.
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
            // The sign of the displacement follows the workspace move, mirrored:
            // the content moves the way a page does when you turn forward.
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 2,
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            compare(body.swapDirection, 1, "moved later in the list")
            wait(Math.round(body.slideDuration / 2))
            verify(outgoing().x < 0, "and the content went left")
            settleSlide()

            body.hint = root.makeHint({
                activeWorkspacePosition: 1,
                previousActiveWorkspacePosition: 3,
                windows: [{ windowId: "21", title: "term2", appId: "kitty", icon: "", isFocused: true }]
            })
            compare(body.swapDirection, -1, "moved earlier in the list")
            wait(Math.round(body.slideDuration / 2))
            verify(outgoing().x > 0, "and the content went right")
            settleSlide()
        }

        function test_onlyTheArrivingLayerCarriesTheFocusMarkers() {
            // Focus belongs to the workspace you are moving to. A marker on the
            // outgoing copy would blink a second time for a workspace you have
            // already left, and the two copies would disagree about which row is
            // current while both are on screen.
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 2,
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            wait(Math.round(body.slideDuration / 2))
            compare(findAllByName(outgoing(), "windowHintFocusFrame").length, 0,
                "no highlight on the copy that is leaving")
            compare(findAllByName(outgoing(), "windowHintFocusIndicator").length, 0,
                "and no indicator")
            compare(findAllByName(live(), "windowHintFocusFrame").length, 1,
                "the arriving one carries the highlight")
            compare(findAllByName(live(), "windowHintFocusIndicator").length, 1,
                "and the indicator")
            settleSlide()
        }

        function test_theMarkersCrossWithTheContentTheyMark() {
            // The highlight is a child of the arriving layer, so it travels with
            // the column it is on. A highlight pinned to the panel while the column
            // slid out from under it would read as the focus staying put while the
            // window list moved - two different claims about where the current
            // window is.
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 2,
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            wait(Math.round(body.slideDuration / 2))
            var inn = live()
            var wash = findByName(inn, "windowHintFocusFrame")
            var bar = findByName(inn, "windowHintFocusIndicator")
            var active = findByName(inn, "windowHintColumn")
            verify(inn.x > 0, "the layer is mid-flight, was " + inn.x)
            // Layer-local: the markers are children of the layer, so their own x is
            // the same number whether or not the layer is moving. What has to hold
            // is that they sit on the column, not that they are at some absolute
            // position that a slide would have to be added to.
            compare(wash.x, active.x, "the highlight sits on its column mid-slide")
            compare(bar.x - wash.x, 4, "and the indicator keeps its inset")
            settleSlide()
        }

        function test_theWholeStripTravelsNotJustTheActiveColumn() {
            // Every column moves together, so the switch reads as one motion across
            // the panel. If only the active column travelled, the neighbours would
            // sit still while the middle slid and the switch would read as two
            // unrelated changes.
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 2,
                previousWindows: [{ windowId: "p1", title: "p1", icon: "", isFocused: false }],
                nextWindows: [{ windowId: "n1", title: "n1", icon: "", isFocused: false }],
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            wait(Math.round(body.slideDuration / 2))
            var inn = live()
            var active = findByName(inn, "windowHintColumn")
            var next = findByName(inn, "windowHintNextColumn")
            var previous = findByName(inn, "windowHintPreviousColumn")
            // The columns keep their slots relative to each other; the LAYER is
            // what is displaced, so all three move as one object.
            compare(active.x, body.columnWidth, "active holds its slot")
            compare(previous.x, 0, "previous holds the first slot")
            compare(next.x - active.x, body.columnWidth, "and next is one column along")
            settleSlide()
            // Landed: each neighbour slot shows what the new snapshot says for it
            // rather than a stale list.
            compare(findByName(live(), "windowHintPreviousRow").modelData.windowId, "p1")
            compare(findByName(live(), "windowHintNextRow").modelData.windowId, "n1")
        }

        function test_aSwitchMidSlideDoesNotRestartIt() {
            // Holding mod and arrowing twice quickly lands a second switch while
            // the first is still crossing. Re-holding the outgoing copy there would
            // snap the arriving layer back to its starting offset - a visible jump
            // backwards - which is worse than the outgoing copy briefly naming a
            // workspace one step behind.
            body.hint = root.makeHint({
                activeWorkspacePosition: 2,
                previousActiveWorkspacePosition: 1,
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            wait(Math.round(body.slideDuration / 2))
            var beforeX = live().x
            verify(beforeX > 0, "mid-flight, was " + beforeX)
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 2,
                windows: [{ windowId: "21", title: "term2", appId: "kitty", icon: "", isFocused: true }]
            })
            // No frame turn between the assignment and the read: the layer must not
            // have been sent back to its start.
            compare(live().x, beforeX, "the arriving layer did not jump back")
            verify(body.slideProgress < 1, "and the slide is still running")
            settleSlide()
            // The Repeater has to have rebuilt its delegates for the second
            // snapshot by now, so this is about which content landed, not about
            // timing.
            var landed = findAllByName(live(), "windowHintWindowRow")
            compare(landed.length, 1, "one row on the arriving layer")
            compare(landed[0].modelData.windowId, "21",
                "the newer snapshot is the one that landed")
            compare(outgoing().visible, false, "and the held copy was released")
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
            compare(outgoing().visible, false, "and held nothing")
            var rows = findAllByName(live(), "windowHintWindowRow")
            compare(rows.length, 2, "already the new list")
            compare(findByName(live(), "windowHintWindowTitle").text, "kitty")
            verify(rows[1].enabled, "and tappable")
        }

        function test_reducedMotionCommitsWithoutSliding() {
            // Reduced motion means the swap is a replacement, not a displacement.
            // Only the arriving layer ends up visible - two copies at the same
            // offset would double every row's text.
            Lazer.MotionTokens.reducedMotionOverride = true
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 1,
                windows: [
                    { windowId: "a", title: "a", appId: "kitty", icon: "", isFocused: true },
                    { windowId: "b", title: "b", appId: "kitty", icon: "", isFocused: false }
                ]
            })
            compare(body.swapping, false, "no slide to wait for")
            compare(outgoing().visible, false, "and nothing was held")
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