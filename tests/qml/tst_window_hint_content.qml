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
            windows: [
                { windowId: "10", title: "kitty", appId: "kitty", icon: "", isFocused: false },
                { windowId: "11", title: "afloat", appId: "kitty", icon: "", isFocused: true }
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
        width: 360
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

        function test_focusHighlightStillGlidesAndSnaps() {
            // The launcher's contract, minus the border: only y is animated, and
            // the highlight is bounded by the row.
            var frame = findByName(body, "windowHintFocusFrame")
            var rows = findAllByName(body, "windowHintWindowRow")
            compare(frame.enabled, false, "inert, so it cannot swallow a row tap")
            // Bounded by the row, not inset: the highlight has to cover exactly
            // the row it marks, and the row spans the full content width.
            compare(frame.height, rows[1].height)
            compare(frame.x, rows[1].x, "starts where the row starts")
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
            // The underline computes its own y from the list pitch instead of
            // tracking a row item, so this is the guard against the two drifting
            // apart: if the row height or the Column spacing changes and the
            // pitch is not updated, the bar would mark thin air.
            var rows = findAllByName(body, "windowHintWindowRow")
            var bar = findByName(body, "windowHintFocusIndicator")
            var rowCentre = rows[1].y + rows[1].height / 2
            compare(bar.y + bar.height / 2, rowCentre, "centred on the row")
            compare(bar.x, 4, "sits inside the row's left edge")
            verify(bar.x + bar.width < rows[1].x + rows[1].width, "and within the row")
        }

        // Wait out the indicator's dual-speed tracker. The head lands in `medium`, but
        // the tail runs `slow * 2` on OutSine, which starts slowly - so anything
        // that switched an indicator target is still stretched long after the
        // head has arrived, and a position read before then is a frame of the
        // elongation rather than the settled bar.
        function settleIndicator() {
            wait(Lazer.MotionTokens.slow * 2 + 150)
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