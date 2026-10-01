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

    // The last activation the body reported. The body owns no niri call, so
    // this is the only place the tap route can be observed.
    QtObject {
        id: reported
        property string window: ""
    }

    Bar.BarWindowHintContent {
        id: body
        objectName: "hintBody"
        width: 540
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
            compare(findAllByName(body, "windowHintWindowRow").length, 2)
        }

        // ---- the three columns -------------------------------------------
        function test_bodyRendersThreeColumnsPreviousActiveNext() {
            // Left / middle / right are the workspace before, the active one and
            // the workspace after - in that order, so the workspace you are on
            // is always in the same place. The order is asserted by position, not
            // by existence: three sets of rows that exist is not the same claim
            // as three columns that are in the right places.
            var previous = findByName(body, "windowHintPreviousColumn")
            var active = findByName(body, "windowHintColumn")
            var next = findByName(body, "windowHintNextColumn")
            verify(previous && active && next, "all three columns exist")
            verify(previous.x + previous.width <= active.x, "previous is leftmost")
            verify(active.x + active.width <= next.x, "next is rightmost")
            compare(findAllByName(body, "windowHintPreviousRow").length, 1)
            compare(findAllByName(body, "windowHintNextRow").length, 1)
            // Each column shows its OWN workspace's window, not a copy of the
            // active one - a neighbour that listed the active workspace's
            // windows would be decoration pretending to be information.
            compare(findByName(body, "windowHintPreviousRow").modelData.windowId, "20")
            compare(findByName(body, "windowHintNextRow").modelData.windowId, "30")
        }

        function test_neighbourColumnsCarryNoState() {
            // Only the active column holds focus, so a card, a highlight or an
            // indicator on a neighbour would claim a second selection. The
            // neighbour labels are plain text over the panel's own surface.
            var previous = findAllByName(body, "windowHintPreviousRow")[0]
            var active = findAllByName(body, "windowHintWindowRow")[0]
            // The active row is a card; a neighbour is not.
            verify(active.color !== undefined, "the active row is a filled card")
            verify(previous.color === undefined, "a neighbour label paints no fill")
            compare(findAllByName(body, "windowHintFocusFrame").length, 1,
                "one highlight, for the whole panel")
            compare(findAllByName(body, "windowHintFocusIndicator").length, 1,
                "and one indicator")
            // A neighbour row is still a tap target: focusing a window in another
            // workspace is the one thing that makes the neighbours worth showing,
            // and niri moves the view to that window's workspace.
            verify(previous.activated !== undefined, "neighbour rows report an activation")
        }

        function test_tappingANeighbourRowReportsItsId() {
            var row = findAllByName(body, "windowHintNextRow")[0]
            mouseClick(row, row.width / 2, row.height / 2, Qt.LeftButton)
            compare(reported.window, "30")
        }

        function test_stateMarkersSitOnTheActiveColumn() {
            // The active column is the MIDDLE slot, so a highlight left at x 0
            // would be drawn under the previous workspace's labels and none of it
            // would be visible over the row it is supposed to mark. The rows are
            // positioned inside their column, so root-space is column.x + row.x.
            var rows = findAllByName(body, "windowHintWindowRow")
            var active = findByName(body, "windowHintColumn")
            var wash = findByName(body, "windowHintFocusFrame")
            var bar = findByName(body, "windowHintFocusIndicator")
            var previous = findByName(body, "windowHintPreviousColumn")
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
            var next = findByName(body, "windowHintNextColumn")
            verify(wash.x + wash.width <= next.x, "and stops before the next column")
        }

        function test_aMissingNeighbourIsAnEmptyColumn() {
            // At either end of the workspace list there is no workspace there.
            // The honest answer is a blank column; wrapping around to a real
            // neighbour would label it with a workspace the user cannot see.
            body.hint = root.makeHint({ previousWindows: [] })
            wait(20)
            verify(findByName(body, "windowHintPreviousColumn"), "the column is still there")
            compare(findAllByName(body, "windowHintPreviousRow").length, 0, "and holds no row")
            compare(findAllByName(body, "windowHintNextRow").length, 1, "the other side is unaffected")
            // The active column's markers must not drift into the empty space,
            // and the columns must not re-settle around the hole. An empty column
            // still occupies its slot: taking it out would make the panel jump
            // sideways on every switch to the first or last workspace.
            var active = findByName(body, "windowHintColumn")
            compare(findByName(body, "windowHintFocusFrame").x, active.x,
                "the highlight follows the active column")
            compare(findByName(body, "windowHintPreviousColumn").x, 0, "previous keeps the first slot")
            compare(active.x, body.columnWidth, "active keeps the second")
            compare(findByName(body, "windowHintNextColumn").x, body.columnWidth * 2, "and next the third")
        }

        function test_columnsShareOneRowPitch() {
            // The focus indicator computes its y from the active column's pitch
            // alone. If a neighbour column used a different spacing, the three
            // lists would not line up across the panel and the panel would read
            // as three unrelated stacks.
            var previous = findByName(body, "windowHintPreviousColumn")
            var active = findByName(body, "windowHintColumn")
            var next = findByName(body, "windowHintNextColumn")
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

        function test_neighbourRowsArriveOnTheSameStagger() {
            // A workspace switch replaces all three columns at once, so the
            // arrival has to cover the neighbours too - otherwise the panel
            // would drop its outer columns instantly and stagger only the middle.
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
            // Sampled DURING the stagger: waiting it out first is what makes a
            // stagger unverifiable.
            wait(Lazer.MotionTokens.fast + Lazer.MotionTokens.dropdownItem + 40)
            verify(body.entrancePending, "rows are still arriving")
            var previous = findAllByName(body, "windowHintPreviousRow")
            var next = findAllByName(body, "windowHintNextRow")
            compare(previous.length, 3)
            compare(next.length, 3)
            verify(previous[0].opacity > 0.9, "neighbour's first row landed, was " + previous[0].opacity)
            verify(previous[2].opacity < 0.1, "and its last has not, was " + previous[2].opacity)
            verify(next[0].opacity > 0.9, "same on the far side, was " + next[0].opacity)
            verify(next[2].opacity < 0.1, "and its last has not, was " + next[2].opacity)

            // The flag has to stand down on the LONGEST of the three staggers.
            // Standing it down on the active column's last row would leave a
            // taller neighbour column pinned at the hidden value for good.
            wait(Lazer.MotionTokens.dropdownItem * 2 + Lazer.MotionTokens.medium + 80)
            compare(body.entrancePending, false)
            verify(findAllByName(body, "windowHintPreviousRow")[2].opacity > 0.9)
            verify(findAllByName(body, "windowHintNextRow")[2].opacity > 0.9)
        }

        function test_neighbourColumnsTravelWithTheSwap() {
            // The list replacement is one motion across the panel: if only the
            // active column travelled, the neighbours would jump while the middle
            // slid and the swap would read as two unrelated changes.
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 2,
                previousWindows: [{ windowId: "p1", title: "p1", icon: "", isFocused: false }],
                nextWindows: [{ windowId: "n1", title: "n1", icon: "", isFocused: false }],
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            wait(Math.round(Lazer.MotionTokens.fast / 2))
            var previous = findAllByName(body, "windowHintPreviousRow")[0]
            var active = findAllByName(body, "windowHintWindowRow")[0]
            var next = findAllByName(body, "windowHintNextRow")[0]
            verify(previous.transform[0].y > 0, "previous leaves downwards, was " + previous.transform[0].y)
            verify(active.transform[0].y > 0, "active too, was " + active.transform[0].y)
            verify(next.transform[0].y > 0, "and next, was " + next.transform[0].y)
            settleSwap(1)
        }

        function test_bodyShowsNothingButTheList() {
            // The panel is body-only: no workspace strip, no header, no
            // divider. Anything here is a copy of what the bar already shows or
            // of what the rows themselves say.
            verify(findByName(body, "windowHintWorkspaceChip") === null)
            verify(findByName(body, "windowHintDivider") === null)
            verify(findByName(body, "windowHintStrip") === null)
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
            var rows = findAllByName(body, "windowHintWindowRow")
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
            var rows = findAllByName(body, "windowHintWindowRow")
            var filled = rows.filter(function(r) { return r.color === wash })
            compare(filled.length, 0, "no row carries it")
            compare(findByName(body, "windowHintFocusFrame").color, wash, "the shared one does")
        }

        function test_indicatorClearsTheGlyph() {
            // The indicator sits at the highlight's own left edge, so the row
            // needs a real left margin or the bar ends a pixel before the icon
            // begins. The gutter is derived, not a literal, so moving either the
            // marker or the glyph cannot silently close it up again. Measured
            // from the ACTIVE column's edge, which is now the middle one.
            var rows = findAllByName(body, "windowHintWindowRow")
            var wash = findByName(body, "windowHintFocusFrame")
            var bar = findByName(body, "windowHintFocusIndicator")
            var icon = findByName(body, "windowHintWindowIcon")
            compare(icon.x, rows[0].children[0].x, "glyphs share one inset")
            var gap = icon.x - (bar.x - wash.x + bar.width)
            compare(gap, 12, "and keep a 12px gutter clear of the marker")
            verify(gap >= 8, "a gutter, not a hairline")
            // The title follows the glyph, so the whole row shifts with it.
            var title = findByName(body, "windowHintWindowTitle")
            compare(title.anchors.leftMargin, 8)
        }

        function test_indicatorStacksAboveTheFocusHighlight() {
            // The indicator is a mark ON the highlight. Siblings that share a z
            // fall back to declaration order, so the stacking has to be stated:
            // rows at the default 0, the highlight at 5, the indicator at 6. With
            // the highlight on top the bar would be painted over and the current
            // window would lose its indicator entirely.
            var rows = findAllByName(body, "windowHintWindowRow")
            var wash = findByName(body, "windowHintFocusFrame")
            var bar = findByName(body, "windowHintFocusIndicator")
            verify(bar.z > wash.z, "indicator above the highlight, was " + bar.z)
            verify(wash.z > rows[0].z, "highlight above the rows, was " + wash.z)
        }

        function test_focusHighlightStillGlidesAndSnaps() {
            // The launcher's contract, minus the border: only y is animated, and
            // the highlight is bounded by the row.
            var frame = findByName(body, "windowHintFocusFrame")
            var rows = findAllByName(body, "windowHintWindowRow")
            compare(frame.enabled, false, "inert, so it cannot swallow a row tap")
            // Bounded by the row, not inset: the highlight has to cover exactly
            // the row it marks, and the row spans its column's full width. The
            // rows sit inside their column, so the comparison is made there too.
            var active = findByName(body, "windowHintColumn")
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
            var after = findAllByName(body, "windowHintWindowRow")
            wait(Math.round(Lazer.MotionTokens.settingsSidebarCollapse / 2))
            var gliding = findByName(body, "windowHintFocusFrame")
            // Mid-glide the highlight is between the two rows, which is what
            // makes it read as travelling rather than jumping. A highlight with
            // no Behavior on y would already be at 0 here.
            verify(gliding.y > 0 && gliding.y < after[1].y,
                "in flight between the rows, was " + gliding.y)

            wait(Lazer.MotionTokens.settingsSidebarCollapse + 120)
            var moved = findByName(body, "windowHintFocusFrame")
            compare(moved.y, 0, "glided to the first row")
            compare(findAllByName(body, "windowHintFocusFrame").length, 1, "one for the list")
        }

        function test_focusIsOneSharedIndicatorNotAPerRowMarker() {
            // The workspace widget marks its active target with a single
            // travelling bar, and the launcher frames its current row with one
            // shared frame. N per-row markers would read as decoration, so there
            // must be exactly one of each for the whole list.
            compare(findAllByName(body, "windowHintFocusIndicator").length, 1)
            compare(findAllByName(body, "windowHintFocusFrame").length, 1)
            verify(findByName(body, "windowHintFocusedBar") === null)
        }

        function test_indicatorUsesTheWorkspaceIndicatorVocabulary() {
            var bar = findByName(body, "windowHintFocusIndicator")
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
            var bar = findByName(body, "windowHintFocusIndicator")
            compare(bar.width, Lazer.LazerTheme.barIndicatorHeight, "stays bar-thin")
            verify(bar.height >= 16, "at least its resting length")
        }

        function test_indicatorIsCentredOnTheFocusedRow() {
            // The indicator computes its own y from the list pitch instead of
            // tracking a row item, so this is the guard against the two drifting
            // apart: if the row height or the Column spacing changes and the
            // pitch is not updated, the bar would mark thin air.
            var rows = findAllByName(body, "windowHintWindowRow")
            var wash = findByName(body, "windowHintFocusFrame")
            var bar = findByName(body, "windowHintFocusIndicator")
            var rowCentre = rows[1].y + rows[1].height / 2
            compare(bar.y + bar.height / 2, rowCentre, "centred on the row")
            compare(bar.x - wash.x, 4, "sits inside the active column's left edge")
            // Root space: the bar is a child of the panel, the row of its column.
            var active = findByName(body, "windowHintColumn")
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

        // A full list swap: the exit, then the stagger, whose last row starts
        // `rowCount - 1` steps in and takes `medium` to land.
        function settleSwap(rowCount) {
            wait(Lazer.MotionTokens.fast + 20)
            var rows = Math.max(1, rowCount || findAllByName(body, "windowHintWindowRow").length)
            wait((rows - 1) * Lazer.MotionTokens.dropdownItem + Lazer.MotionTokens.medium + 60)
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
            var bars = findAllByName(body, "windowHintFocusIndicator")
            compare(bars.length, 1, "still one instance")
            verify(bars[0].height > 16, "stretched while the tail trails")
            compare(bars[0].width, Lazer.LazerTheme.barIndicatorHeight, "still bar-thin")

            settleIndicator()
            var settled = findByName(body, "windowHintFocusIndicator")
            var rows = findAllByName(body, "windowHintWindowRow")
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
            verify(!findByName(body, "windowHintFocusIndicator").visible)
        }

        function test_underlineHiddenWhenNoWindowIsFocused() {
            body.hint = root.makeHint({
                windows: [
                    { windowId: "10", title: "kitty", appId: "kitty", icon: "", isFocused: false },
                    { windowId: "11", title: "afloat", appId: "kitty", icon: "", isFocused: false }
                ]
            })
            wait(20)
            verify(!findByName(body, "windowHintFocusIndicator").visible)
        }

        // ---- tap --------------------------------------------------------
        function test_tappingAWindowRowReportsItsId() {
            var rows = findAllByName(body, "windowHintWindowRow")
            mouseClick(rows[1], rows[1].width / 2, rows[1].height / 2, Qt.LeftButton)
            compare(reported.window, "11")
        }

        function test_tappingAnyRowIsLive() {
            // Every row is a target, not only the focused one.
            var rows = findAllByName(body, "windowHintWindowRow")
            mouseClick(rows[0], rows[0].width / 2, rows[0].height / 2, Qt.LeftButton)
            compare(reported.window, "10")
        }

        function test_rowFlashFollowsTheSharedRecipe() {
            // Asserted as a contract, not by sampling an opacity mid-animation:
            // the duration and easing are the shared tokens, so a deliberate
            // retune of the recipe cannot silently desync this file.
            var rows = findAllByName(body, "windowHintWindowRow")
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
            var rows = findAllByName(body, "windowHintWindowRow")
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
            compare(findAllByName(body, "windowHintWindowRow").length, 8 - 3)
            compare(findByName(body, "windowHintOverflow").text, "+3 more windows")
        }

        function test_emptyWorkspaceSaysSoInsteadOfABarePanel() {
            body.hint = root.makeHint({ windows: [] })
            wait(20)
            // An empty workspace is a real state: the bar names the workspace,
            // so the body has to explain the bare list.
            verify(findByName(body, "windowHintNoWindows").visible)
            compare(findAllByName(body, "windowHintWindowRow").length, 0)
        }

        function test_coldSnapshotStatesItself() {
            body.hint = null
            wait(20)
            compare(findAllByName(body, "windowHintWindowRow").length, 0)
            verify(findByName(body, "windowHintEmpty").visible)
        }

        // ---- swapping the list between workspaces ------------------------
        function test_workspaceSwitchAnimatesTheListOutThenIn() {
            // A workspace switch replaces every row, so the list has to be seen
            // leaving before the new one arrives - otherwise it is simply gone
            // and remade between two frames. The fade is on the body, the row
            // that holds all three columns: fading the active column alone would
            // leave the neighbours opaque through the exit.
            var list = findByName(body, "windowHintBody")
            compare(body.swapping, false, "settled to begin with")
            compare(list.opacity, 1)

            body.hint = root.makeHint({
                workspaceId: "43",
                workspaceIndex: 3,
                activeWorkspacePosition: 2,
                previousActiveWorkspacePosition: 1,
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            // Mid-exit: the OLD rows are still the ones on screen, and the list
            // is on its way out. This is the part a display pool of depth 1 buys.
            verify(body.swapping, "swapping")
            // An animation reads its start value on the frame it starts, so the
            // travel has to be sampled after the event loop has turned.
            wait(Math.round(Lazer.MotionTokens.fast / 2))
            var during = findAllByName(body, "windowHintWindowRow")
            compare(during.length, 2, "the outgoing rows are still mounted")
            verify(list.opacity < 1, "and fading, was " + list.opacity)
            verify(during[0].transform[0].y !== 0, "and travelling")

            // Rows mid-flight must not be tappable: what is under the pointer is
            // about to be discarded.
            verify(!during[0].enabled, "a row mid-swap is not a tap target")

            settleSwap()
            var after = findAllByName(body, "windowHintWindowRow")
            compare(after.length, 1, "the new list has taken over")
            compare(after[0].modelData.windowId, "20")
            compare(body.swapping, false)
            compare(list.opacity, 1, "and the list is opaque again")
            verify(after[0].enabled, "rows are tappable once landed")
        }

        function test_swapTravelsTheWayTheWorkspaceMoved() {
            // The list replacement and the focus indicator both travel with the
            // switch, so the panel reads as one surface turning.
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 2,
                windows: [{ windowId: "20", title: "term", appId: "kitty", icon: "", isFocused: true }]
            })
            compare(body.swapDirection, 1, "downwards")
            wait(Math.round(Lazer.MotionTokens.fast / 2))
            var rows = findAllByName(body, "windowHintWindowRow")
            verify(rows[0].transform[0].y > 0,
                "the outgoing list leaves downwards, was " + rows[0].transform[0].y)
            settleSwap(1)

            body.hint = root.makeHint({
                activeWorkspacePosition: 1,
                previousActiveWorkspacePosition: 3,
                windows: [{ windowId: "21", title: "term2", appId: "kitty", icon: "", isFocused: true }]
            })
            compare(body.swapDirection, -1, "upwards")
            wait(Math.round(Lazer.MotionTokens.fast / 2))
            var back = findAllByName(body, "windowHintWindowRow")
            verify(back[0].transform[0].y < 0,
                "and upwards, was " + back[0].transform[0].y)
            settleSwap(1)
        }

        function test_rowsArriveOnAStaggerNotAllAtOnce() {
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 1,
                windows: [
                    { windowId: "a", title: "a", appId: "kitty", icon: "", isFocused: true },
                    { windowId: "b", title: "b", appId: "kitty", icon: "", isFocused: false },
                    { windowId: "c", title: "c", appId: "kitty", icon: "", isFocused: false }
                ]
            })
            // Sample DURING the stagger, not after it: waiting the whole thing
            // out first is what makes a stagger unverifiable.
            wait(Lazer.MotionTokens.fast + Lazer.MotionTokens.dropdownItem + 40)
            verify(body.entrancePending, "rows are still arriving")

            // Just after the first row's fade: it is up, the last is not. That
            // gap IS the stagger; a single group fade would land them together.
            var rows = findAllByName(body, "windowHintWindowRow")
            compare(rows.length, 3)
            verify(rows[0].opacity > 0.9, "first row landed, was " + rows[0].opacity)
            verify(rows[2].opacity < 0.1, "last row has not, was " + rows[2].opacity)

            // The flag stands down when the last row lands, or the rows would
            // stay bound to the hidden value for the next swap.
            wait(Lazer.MotionTokens.dropdownItem * 2 + Lazer.MotionTokens.medium + 80)
            compare(body.entrancePending, false)
            var landed = findAllByName(body, "windowHintWindowRow")
            verify(landed[2].opacity > 0.9, "last row landed, was " + landed[2].opacity)
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
            var rows = findAllByName(body, "windowHintWindowRow")
            compare(rows.length, 2, "already the new list")
            compare(findByName(body, "windowHintWindowTitle").text, "kitty")
            verify(rows[1].opacity > 0.9, "and visible, was " + rows[1].opacity)
        }

        function test_reducedMotionCommitsWithoutHidingTheList() {
            // The rows start hidden so the stagger can raise them; under reduced
            // motion nothing raises them, so they must not be left that way.
            Lazer.MotionTokens.reducedMotionOverride = true
            body.hint = root.makeHint({
                activeWorkspacePosition: 3,
                previousActiveWorkspacePosition: 1,
                windows: [
                    { windowId: "a", title: "a", appId: "kitty", icon: "", isFocused: true },
                    { windowId: "b", title: "b", appId: "kitty", icon: "", isFocused: false }
                ]
            })
            settleSwap()
            compare(body.swapping, false)
            compare(body.entrancePending, false, "no arrival to wait for")
            var rows = findAllByName(body, "windowHintWindowRow")
            compare(rows.length, 2)
            verify(rows[0].opacity > 0.9, "rows are visible, was " + rows[0].opacity)
            verify(rows[1].opacity > 0.9, "all of them, was " + rows[1].opacity)
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
            var rows = findAllByName(body, "windowHintWindowRow")
            compare(rows.length, 1)
            // The list is now a different workspace's single window, so the
            // highlight has to follow rather than stay where the old rows were.
            var frame = findByName(body, "windowHintFocusFrame")
            compare(frame.y, 0, "highlight sits on the only row")
            compare(frame.height, rows[0].height)
        }
    }
}