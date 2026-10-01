import QtQuick
import "../lazerbar"
import "./WindowHintMenuLogic.js" as HintLogic

// Body of the mod-key window hint: three columns of window labels, each row
// clickable to focus it. Rendered inside the bar's popup, so it reuses the
// popup's surface colors, section fill and shared reveal instead of owning a
// surface of its own.
//
// The three columns are the workspaces either side of the active one plus the
// active one itself, in that order - so the workspace you are on is always in
// the same place and the neighbours read as what is either side of it. Only the
// active column carries state: the neighbour columns are plain muted labels with
// no card, no highlight and no indicator, because a third fill competing with
// the active one would say three things are selected.
//
// There is deliberately no header and no workspace strip. The bar already shows
// which workspace is active, and the hint is driven by a key rather than a
// pointer, so either would be a second copy of a fact already on screen. What is
// left is what the bar cannot show: the windows here, and the windows either
// side of here.
Item {
    id: root

    // The live snapshot from WindowHintService, replaced wholesale on every
    // refresh, so each binding below re-evaluates on a workspace switch.
    property var hint: null
    signal windowActivated(string windowId)

    // What is currently painted, as the three columns. This LAGS `hint` while a
    // swap animation plays: showing the outgoing list leave needs both lists
    // alive at once, and a Repeater only ever holds one. A depth-1 hold is the
    // whole of it - the launcher's display pool solves the same problem for a
    // list that refills on every keystroke, which is not what a hold-to-see
    // popup does.
    property var columns: HintLogic.cappedColumns(null)
    property bool shownReady: false
    // +1 when the workspace moved later in the list, -1 earlier, 0 unknown.
    property int swapDirection: 0
    property bool swapping: false
    // True only between a swap committing and its staggered arrival finishing.
    // It is what makes a freshly created row start hidden - a binding rather
    // than a constant, or reduced motion would leave every row invisible.
    property bool entrancePending: false
    // The list's own opacity, animated only while a swap leaves. Kept off the
    // Column so that restoring it after a commit cannot take the exit animation
    // off its target.
    property real listFade: 1
    // The active column, kept as its own name because the focus marker, the
    // overflow line and the indicator are all about this column alone.
    readonly property var windowPage: columns.current
    readonly property bool ready: root.shownReady
    readonly property string overflowText: HintLogic.overflowLabel(columns.current.hidden)
    readonly property bool hasWindows: columns.current.rows.length > 0
    readonly property int shownRowCount: columns.current.rows.length
    // The furthest any column's last row has to wait: its arrival starts one
    // stagger step before the last row, so the delay is the largest row count
    // across the three, not the active column's.
    readonly property int _longestArrival: Math.max(
        columns.previous.rows.length,
        columns.current.rows.length,
        columns.next.rows.length) * MotionTokens.dropdownItem
    // The three columns are peers, so they share one width and the middle one -
    // the active workspace - sits at the second slot. Its left edge is the
    // origin for the focus highlight and the indicator, stated once here rather
    // than repeated as a literal offset in each marker.
    readonly property int columnCount: 3
    readonly property int columnWidth: Math.floor(width / columnCount)
    readonly property int activeColumnX: columnWidth
    // How far the list travels while swapping. `overlayFromY` is the existing
    // offset token for an overlay arriving from off its resting place.
    readonly property int swapTravel: MotionTokens.overlayFromY
    readonly property int rowHeight: 28
    // The one row the focus indicator belongs to, or -1. Read from the SHOWN
    // column, not from `hint`, so it cannot point past what is on screen while
    // the outgoing list is still playing.
    readonly property int focusedRowIndex: HintLogic.focusedIndexIn(columns.current.rows)
    // Left inset of a row's glyph, shared by the icon and the title so both
    // start on the same x - and derived from the indicator rather than a literal,
    // so the gutter between the marker and the glyph cannot drift when either
    // moves. The indicator sits at the wash's own edge, so the row needs a real
    // left margin: without it the bar ends 1px before the icon begins.
    readonly property int indicatorInset: 4
    readonly property int indicatorThickness: LazerTheme.barIndicatorHeight
    readonly property int indicatorGutter: 12
    readonly property int glyphInset: indicatorInset + indicatorThickness + indicatorGutter
    readonly property int glyphWidth: 16
    // Vertical pitch of the list: a row plus the Column's gap. The underline
    // is positioned from this, so it has to agree with the Column's own
    // spacing exactly - asserted against a real row's bottom edge in the suite.
    readonly property int rowPitch: rowHeight + listSpacing
    readonly property int listSpacing: 6
    // Top edge of the focused row, 0 when there is none. One source of truth
    // for both markers below, so the frame and the underline can never
    // disagree about which row is current.
    readonly property real focusedRowTop: focusedRowIndex < 0 ? 0
        : focusedRowIndex * rowPitch

    // --- indicator: the workspace widget's dual-speed edge tracker, rotated ---
    // The workspace indicator is a 16x3 bar travelling sideways, so its
    // head/tail stretch lengthens it along its own long axis and it stays a bar.
    // This list travels vertically, so the indicator is a 3x16 bar travelling
    // downward: same tokens, same tracker, same formula, rotated 90 degrees.
    // Stretching the WRONG axis would have turned a 3px bar into a tall
    // rectangle mid-flight, which is a shape change rather than a bar growing.
    readonly property int indicatorLength: 16

    property real _headY: 0
    property real _tailY: 0
    property bool _snapping: false
    // Committed target, never animated. Dedupe and same-anchor drift read this,
    // because _headY is the Behavior's in-flight frame and is numerically equal
    // to _tailY until the first tick, which would make a same-frame switch look
    // settled and teleport the bar.
    property real _anchorY: 0
    property bool _placed: false
    // Same-anchor drift arriving while a trail is in flight; applied as one
    // snap once the tail catches up, so a trail is never cut short.
    property real _pendingTop: -1
    property string _targetKey: ""

    // Left edge of the drawn bar, and the head/tail target, both derived the
    // same way the workspace widget derives them: the target is the row's centre
    // minus half the bar's resting length, so at rest the bar sits centred.
    // A function, not just a binding, because the change handlers below must be
    // able to ask for a target from the index that just changed - see
    // _syncIndicator.
    function _targetYFor(index) {
        return index * rowPitch + rowHeight / 2 - indicatorLength / 2
    }

    // --- list swap choreography ---------------------------------------
    // A workspace switch replaces every row, so without this the list is simply
    // gone and remade between two frames. The swap travels the way the workspace
    // moved - the same direction the focus indicator travels - so the panel reads
    // as one surface turning rather than as its contents blinking.
    //
    // Reduced motion, a first snapshot, and a change with no knowable direction
    // (a window title edit on the same workspace) all commit straight away: an
    // un-aimed animation would be motion for its own sake.
    function _onHintChanged() {
        if (MotionTokens.reducedMotion || !root.shownReady) {
            root._commitHint(false)
            return
        }
        const direction = HintLogic.switchDirection(root.hint)
        if (direction === 0) {
            root._commitHint(false)
            return
        }
        root.swapDirection = direction
        root.swapping = true
        swapExit.restart()
    }

    // Swap in the new list and, for a swap that travelled, hand the rows their
    // staggered entrance.
    //
    // `animate` is false for a refresh that did not move the workspace - a title
    // changing, a window closing. Those still replace rows, but they have no
    // direction and no page turn to play, and a stagger on every such change
    // would make an edit to one window's title look like a page turn.
    function _commitHint(animate) {
        swapExit.stop()
        root.swapping = false
        root.columns = HintLogic.cappedColumns(root.hint)
        root.shownReady = HintLogic.ready(root.hint)
        // Outgoing list opacity is restored here, from the animation's own
        // `to` value. Writing the property the animation targets would take it
        // off the animation, and the next `restart()` would seek back to `from`
        // - which is how the exit ends up pinned at full opacity forever.
        root.listFade = 1
        // The Column carries no fade of its own on the way in: it would multiply
        // the rows' opacity and flatten their stagger back into one frame. The
        // rows carry the arrival on their own.
        // Reduced motion has no entrance to play, so the rows must not be left
        // at the hidden value the animation would have raised.
        root.entrancePending = animate === true && !MotionTokens.reducedMotion
                && root.shownReady
        if (!root.entrancePending)
            return
        // One turn later, because the Repeaters insert the new delegates when they
        // process the model change, which is after this function returns.
        // Reaching into `column.children` here finds only the Repeater and the
        // overflow line - the rows do not exist yet, and their animations would
        // never be started, leaving every row at the hidden value forever.
        Qt.callLater(function () {
            if (!root.entrancePending)
                return
            root._startArrivals(column.children, "rowEntranceAnimation")
            root._startArrivals(previousColumn.children, "arrivalTimer")
            root._startArrivals(nextColumn.children, "arrivalTimer")
            // The flag comes down on a timer sized to the LONGEST stagger of the
            // three columns, not from a row announcing itself. With three lists
            // the last row of one column is not the end of the stagger for the
            // other two, and a column can be empty while its neighbours are not -
            // so no single row's arrival is the moment the whole panel is up.
            entranceSettle.restart()
        })
    }

    // Start each delegate's own arrival. The animation id is passed in because
    // the two row kinds spell it differently - the active row animates a property
    // directly, the neighbour label fires a Timer first - and neither is reachable
    // from here without a handle the Repeater owns.
    function _startArrivals(children, animationProperty) {
        for (let i = 0; i < children.length; ++i) {
            const child = children[i]
            if (child[animationProperty] !== undefined)
                child[animationProperty].start()
        }
    }

    // Long enough for the furthest row of any column to have landed, so the flag
    // comes down only once the whole panel is up.
    Timer {
        id: entranceSettle
        interval: root._longestArrival + MotionTokens.medium + 20
        repeat: false
        onTriggered: root.entrancePending = false
    }

    onHintChanged: _onHintChanged()

    readonly property real _barTop: Math.min(_headY, _tailY)
    readonly property real _barLength: indicatorLength + Math.abs(_headY - _tailY)
    readonly property real _indicatorTargetY: _targetYFor(focusedRowIndex)
    readonly property bool hasTarget: focusedRowIndex >= 0
            && focusedRowIndex < windowPage.rows.length

    Behavior on _headY {
        enabled: root._placed && !MotionTokens.reducedMotion && !root._snapping
        NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.OutQuad }
    }
    Behavior on _tailY {
        enabled: root._placed && !MotionTokens.reducedMotion && !root._snapping
        // 3x the head's flight: the tail lingers long after the head lands,
        // which is what keeps the stretch readable.
        NumberAnimation { duration: MotionTokens.slow * 2; easing.type: Easing.OutSine }
    }

    // Commit head and tail together with the Behaviors suppressed. Both writes
    // use a precomputed target: reading _headY back would return the animation
    // frame, not the committed value.
    function _snapIndicator(top) {
        _snapping = true
        _anchorY = top
        _headY = top
        _tailY = top
        _snapping = false
    }

    // Route every re-anchor through here. A genuine target switch desyncs head
    // and tail into the trail and blinks once; same-target layout drift snaps
    // both so content churn never stretches the bar; the first placement snaps
    // so it never slides in from zero.
    function _retargetIndicator(top, key) {
        if (!isFinite(top))
            return
        if (key !== _targetKey && _placed) {
            _pendingTop = -1
            _targetKey = key
            _anchorY = top
            _headY = top
            _tailY = top
            _flashIndicator.restart()
            return
        }
        if (Math.abs(top - _anchorY) < 0.5)
            return
        if (Math.abs(_headY - _tailY) > 0.5) {
            _pendingTop = top
            return
        }
        _snapIndicator(top)
    }

    // Apply a drift that landed mid-trail, once the tail has caught up.
    Timer {
        interval: 16
        repeat: true
        running: root._pendingTop >= 0
        onTriggered: {
            if (Math.abs(root._headY - root._tailY) >= 0.5)
                return
            var pending = root._pendingTop
            root._pendingTop = -1
            root._snapIndicator(pending)
        }
    }

    // The outgoing list leaving: a quick fade plus the same travel the entrance
    // uses, so the pair reads as one motion in two halves rather than a
    // disappear followed by an unrelated appear. Short on purpose - the panel
    // only lives for the length of a key hold, so a slow exit would spend the
    // whole time showing nothing.
    NumberAnimation {
        id: swapExit
        target: root
        property: "listFade"
        from: 1
        to: 0
        duration: MotionTokens.fast
        easing.type: Easing.InQuad
        onFinished: root._commitHint(true)
    }

    // Wide enough for three columns of window titles. The popup measures its
    // geometry from this, so the host's `window-hint` width has to agree.
    implicitWidth: 540
    // The tallest of the three columns, and the empty-workspace line when the
    // active one has nothing in it - that line lives outside the columns, so it
    // has to be added in by hand.
    implicitHeight: ready
        ? Math.max(
            Math.max(previousColumn.implicitHeight, column.implicitHeight, nextColumn.implicitHeight),
            hasWindows ? 0 : noWindows.implicitHeight)
        : emptyText.implicitHeight
    width: implicitWidth
    height: implicitHeight

    // The three columns: previous workspace, active workspace, next workspace,
    // positioned by x rather than by a `Row`.
    //
    // A positioner was the obvious tool and it is wrong here. It lays out from
    // its children's widths, and a column's width is a binding that can resolve
    // a beat after the model swap that emptied it - so the positioner polishes
    // against a stale width and, because nothing about the columns then changes
    // again, never re-lays-out. The result is an active column sitting at x 0
    // under the previous workspace's labels with the next one drawn over it.
    // Derived x cannot go stale: the slot a column occupies is a function of
    // the panel width, so every column is in its place from the first frame and
    // after every model change.
    //
    // `spacing` on the active column is bound to `listSpacing` because the focus
    // indicator computes its own y from that same pitch, and the neighbour
    // columns are handed it so all three rows line up across the panel.
    Item {
        id: body
        objectName: "windowHintBody"
        width: parent.width
        visible: root.ready
        opacity: root.listFade

        // Neighbour column: plain labels, no card and no state. At either end of
        // the workspace list this column is simply empty, which is the honest
        // answer rather than a wrapped-around neighbour.
        Column {
            id: previousColumn
            objectName: "windowHintPreviousColumn"
            x: 0
            width: root.columnWidth
            spacing: root.listSpacing

            Repeater {
                model: root.columns.previous.rows

                BarWindowHintLabel {
                    objectName: "windowHintPreviousRow"
                    width: parent.width
                    // `modelData` / `index` are declared as required properties
                    // on the label, so the delegate model fills them. Binding
                    // them here would point each one at ITSELF.
                    rowHeight: root.rowHeight
                    glyphInset: root.glyphInset
                    glyphWidth: root.glyphWidth
                    staggerStep: index * MotionTokens.dropdownItem
                    travelling: root.swapping
                    travelOffset: root.swapDirection * root.swapTravel
                    arrivalPending: root.entrancePending
                    onActivated: windowId => root.windowActivated(windowId)
                }
            }
        }

        // The active column: the only one carrying a fill, a highlight and the
        // focus indicator. The middle slot, and the one the markers are measured
        // against - so its x is stated, not left to a layout pass.
        Column {
            id: column
            objectName: "windowHintColumn"
            x: root.activeColumnX
            width: root.columnWidth
            spacing: root.listSpacing

            Repeater {
                model: root.windowPage.rows

            // Window row: app icon and title. The row no longer tints itself
            // when it holds focus - the shared highlight below is that
            // highlight, and painting it per row as well would put two fills on
            // screen and read as two different states. A row's own surface is
            // now only ever the hover response.
            Rectangle {
                id: windowRow
                required property var modelData
                required property int index

                objectName: "windowHintWindowRow"
                width: parent.width
                height: root.rowHeight
                radius: 6
                transformOrigin: Item.Center
                color: rowHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
                // A Rectangle borders itself by default; the shared highlight is
                // the only focus signal here, so that default is off.
                border.width: 0
                scale: rowPress.pressed ? MotionTokens.pressScale : 1
                // Rows arrive on a stagger, so a replaced list reads as a list
                // being rebuilt rather than as every row appearing at once. The
                // hidden value is bound to `entrancePending` so it can only ever
                // apply while an animation will actually raise it again.
                opacity: root.entrancePending ? 0 : 1
                // Offsets the row WITHOUT touching the Column's layout, so the
                // stagger cannot shift the rows that have already landed.
                transform: Translate {
                    y: root.swapping ? root.swapDirection * root.swapTravel : 0
                    Behavior on y {
                        enabled: !MotionTokens.reducedMotion
                        NumberAnimation {
                            duration: MotionTokens.medium
                            easing.type: Easing.OutQuint
                        }
                    }
                }
                // A row mid-flight is not a tap target: the list underneath it
                // is about to be replaced.
                enabled: !root.swapping

                // Test seam for the shared click-flash recipe.
                readonly property alias rowFlashAnimation: rowFlash
                readonly property alias rowFlashOverlay: rowFlashOverlay
                readonly property alias rowEntranceAnimation: rowEntrance

                // Per-row arrival, offset by the row's position. The offset is a
                // PauseAnimation in front of the fade rather than a property on
                // it: `NumberAnimation` has no delay of its own, and wrapping the
                // pair in a SequentialAnimation is what gives each row a start
                // time derived from its index - which is what turns a replaced
                // list into a visible rebuild instead of one frame of noise.
                NumberAnimation {
                    id: rowFade
                    target: windowRow
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: MotionTokens.medium
                    easing.type: Easing.OutQuint
                }

                // The stagger is a delay before the fade, not a property on it -
                // `NumberAnimation` has no start delay of its own. A Timer rather
                // than a nested PauseAnimation because the fade has to be started
                // from outside, once the Repeater has actually created the row.
                Timer {
                    id: rowEntrance
                    interval: windowRow.index * MotionTokens.dropdownItem
                    repeat: false
                    onTriggered: rowFade.start()
                }

                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                Behavior on scale {
                    enabled: !MotionTokens.reducedMotion
                    NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
                }

                // App icon; the service resolves a themed path per window.
                Image {
                    id: rowIcon
                    objectName: "windowHintWindowIcon"
                    x: root.glyphInset
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.glyphWidth
                    height: root.glyphWidth
                    source: windowRow.modelData.icon
                    visible: windowRow.modelData.icon !== ""
                    // Synchronous decode: the popup lives for the length of one
                    // key hold, so an async icon would land too late to read.
                    asynchronous: false
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                Text {
                    objectName: "windowHintWindowTitle"
                    anchors.left: rowIcon.visible ? rowIcon.right : parent.left
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: windowRow.modelData.title
                    color: windowRow.modelData.isFocused ? LazerTheme.textPrimary : LazerTheme.barSubtitle
                    font.pixelSize: 12
                    font.bold: windowRow.modelData.isFocused
                    elide: Text.ElideRight
                    maximumLineCount: 1

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                // Click flash, inert to input so it cannot swallow the tap.
                Rectangle {
                    id: rowFlashOverlay
                    objectName: "windowHintRowFlash"
                    anchors.fill: parent
                    radius: 6
                    color: LazerTheme.textPrimary
                    opacity: 0
                    enabled: false
                }

                NumberAnimation {
                    id: rowFlash
                    target: rowFlashOverlay
                    property: "opacity"
                    from: MotionTokens.clickFlashOpacity
                    to: 0
                    duration: MotionTokens.clickFlashDuration
                    easing.type: MotionTokens.clickFlashEasing
                }

                HoverHandler { id: rowHover; blocking: false }
                TapHandler {
                    id: rowPress
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: {
                        if (MotionTokens.reducedMotion)
                            rowFlashOverlay.opacity = 0
                        else
                            rowFlash.restart()
                        root.windowActivated(windowRow.modelData.windowId)
                    }
                }
            }
            }

            // Overflow line for the windows the cap left out. Empty when the
            // list fit, so visibility binds straight to the text - and a Column
            // skips an invisible child when it sizes itself, so the line needs no
            // height binding of its own to collapse.
            Text {
                objectName: "windowHintOverflow"
                width: parent.width
                visible: root.overflowText !== ""
                text: root.overflowText
                color: LazerTheme.textMuted
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // Neighbour column: the workspace after the active one, mirroring the
        // previous column on the other side.
        Column {
            id: nextColumn
            objectName: "windowHintNextColumn"
            x: root.columnWidth * 2
            width: root.columnWidth
            spacing: root.listSpacing

            Repeater {
                model: root.columns.next.rows

                BarWindowHintLabel {
                    objectName: "windowHintNextRow"
                    width: parent.width
                    // Filled by the delegate model - see the previous column.
                    rowHeight: root.rowHeight
                    glyphInset: root.glyphInset
                    glyphWidth: root.glyphWidth
                    staggerStep: index * MotionTokens.dropdownItem
                    travelling: root.swapping
                    travelOffset: root.swapDirection * root.swapTravel
                    arrivalPending: root.entrancePending
                    onActivated: windowId => root.windowActivated(windowId)
                }
            }
        }
    }

    // One shared focus highlight for the whole list, the way the launcher's does:
    // a single element that glides to the current row instead of every row
    // showing and hiding its own. A filled wash rather than the launcher's border
    // frame, and the rows give up their own focused tint so exactly one
    // highlight exists at a time - two fills would read as two states.
    Rectangle {
        id: focusFrame
        objectName: "windowHintFocusFrame"
        z: 5
        radius: 6
        // The token the rows' focused tint used, so this is that highlight that
        // moved rather than a new colour.
        color: LazerTheme.settingsSelected
        // A Rectangle draws a 1px border by default. This is a fill, and a
        // default black hairline around it would read as an outline again.
        border.width: 0
        // Inert to input, so it can never intercept a tap meant for the row.
        enabled: false

        // Bounded by the row, not inset: the highlight has to cover exactly the
        // row it marks, and the row spans its column's full width. The active
        // column is the MIDDLE slot, so both edges are an offset away - a
        // highlight at x 0 would be drawn under the previous workspace's labels
        // and none of it would be visible.
        x: root.activeColumnX
        y: root.focusedRowTop
        width: root.columnWidth
        height: root.rowHeight
        opacity: root.hasTarget ? 1 : 0

        Behavior on opacity {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
        }
        Behavior on y {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.settingsSidebarCollapse; easing.type: Easing.OutQuint }
        }
    }

    // The focus indicator, in the workspace widget's vocabulary and motion, turned
    // 90 degrees for a list that travels vertically: a short green bar beside
    // the focused row's glyph, `barIndicatorHeight` thick with the same radius,
    // in `osuGreen`. One instance for the whole list, driven by the dual-speed
    // tracker above so a switch elongates along the bar's long axis and
    // contracts on arrival rather than sliding at one rate.
    // Stacking: rows paint at the default 0, the shared focus highlight sits
    // above them at 5, and this indicator above the highlight at 6. The order
    // matters — the indicator is a mark ON the highlight, and at the same z the
    // declaration order alone would decide, so it is stated explicitly.
    Rectangle {
        id: focusUnderline
        objectName: "windowHintFocusIndicator"
        z: 6

        width: root.indicatorThickness
        height: root._barLength
        radius: LazerTheme.barIndicatorRadius
        color: LazerTheme.osuGreen
        // The active column is the middle slot, so the bar's inset is measured
        // from that column's left edge, not from the panel's.
        x: root.activeColumnX + root.indicatorInset
        y: root._barTop
        visible: root.hasTarget
        opacity: root.hasTarget ? 1 : 0

        // Switch blink: the same tinted-glow blink the workspace indicator
        // plays per genuine target switch.
        Rectangle {
            id: indicatorFlashOverlay
            objectName: "windowHintIndicatorFlash"
            anchors.fill: parent
            radius: parent.radius
            color: LazerTheme.flashWash
            opacity: 0
            enabled: false
        }

        NumberAnimation {
            id: _flashIndicator
            target: indicatorFlashOverlay
            property: "opacity"
            from: MotionTokens.clickFlashOpacity
            to: 0
            duration: MotionTokens.clickFlashDuration
            easing.type: MotionTokens.clickFlashEasing
        }

        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
    }

    // Drive the indicator from the one focused row. Hooked to the target itself
    // rather than to `focusedRowTop`: the derived top edge and `hasTarget` are
    // separate bindings, and QML does not order their change handlers, so a hook
    // on the top edge could observe the "target lost" case after the target came
    // back and snap the bar to the meaningless position a target-less row
    // computes. Both hooks call the same routine; the second is a no-op.
    //
    // The target is computed from `focusedRowIndex` - the property that just
    // changed - rather than read back from `focusedRowTop` or the binding on
    // `_indicatorTargetY`. A change handler runs as soon as its own property is
    // notified, which is before the bindings that depend on it have necessarily
    // been recomputed; reading one of those there yields the PREVIOUS row's
    // target and leaves the bar one switch behind. This is the same discipline
    // the workspace widget uses, where `updateIndicator` computes `centerX`
    // itself and passes it into the tracker.
    function _syncIndicator() {
        var target = root._targetYFor(root.focusedRowIndex)
        if (!root.hasTarget) {
            // No target: the bar is hidden, so it must not be left mid-trail
            // either - a trail still in flight when the next target arrives
            // would stretch out of the wrong place.
            root._pendingTop = -1
            root._snapIndicator(target)
            return
        }
        // First placement snaps: there is nothing on screen to travel from.
        if (!root._placed) {
            root._placed = true
            root._targetKey = String(root.focusedRowIndex)
            root._snapIndicator(target)
            return
        }
        root._retargetIndicator(target, String(root.focusedRowIndex))
    }

    onFocusedRowIndexChanged: _syncIndicator()
    onHasTargetChanged: _syncIndicator()

    Component.onCompleted: {
        if (root.hasTarget)
            root._syncIndicator()
    }

    // Cold snapshot: the service has not resolved an active workspace yet, so
    // the menu says so instead of drawing an empty list.
    Text {
        id: emptyText
        objectName: "windowHintEmpty"
        width: parent.width
        text: "Waiting for the active workspace"
        color: LazerTheme.textMuted
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
        visible: !root.ready
    }

    // An empty workspace is a real state, not a missing snapshot: the bar
    // already names the workspace, so the body explains the bare list. It is
    // scoped to the ACTIVE column - a line about the current workspace centred
    // under the whole panel would sit under the previous workspace's labels.
    Text {
        id: noWindows
        objectName: "windowHintNoWindows"
        x: root.activeColumnX
        width: root.columnWidth
        visible: root.ready && !root.hasWindows
        text: "No windows on this workspace"
        color: LazerTheme.textMuted
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 1
    }
}