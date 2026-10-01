import QtQuick
import "../lazerbar"
import "./WindowHintMenuLogic.js" as HintLogic

// Body of the mod-key window hint: the active workspace's windows, each row
// clickable to focus it. Rendered inside the bar's popup, so it reuses the
// popup's surface colors, section fill and shared reveal instead of owning a
// surface of its own.
//
// There is deliberately nothing else in here. The bar already shows which
// workspace is active, and the hint is driven by a key rather than a pointer,
// so an identity header and a workspace strip would both be third copies of
// facts already on screen. What remains is the one list the bar cannot show:
// the windows on this workspace, with the focused one marked.
Item {
    id: root

    // The live snapshot from WindowHintService, replaced wholesale on every
    // refresh, so each binding below re-evaluates on a workspace switch.
    property var hint: null
    signal windowActivated(string windowId)

    readonly property var windowPage: HintLogic.cappedWindowRows(hint)
    readonly property bool ready: HintLogic.ready(hint)
    readonly property string overflowText: HintLogic.overflowLabel(windowPage.hidden)
    readonly property bool hasWindows: windowPage.rows.length > 0
    readonly property int rowHeight: 28
    // The one row the focus underline belongs to, or -1.
    readonly property int focusedRowIndex: HintLogic.focusedRowIndex(hint)
    // Left inset of a row's glyph, shared by the icon, the title and the
    // underline so all three start on the same x.
    readonly property int glyphInset: 8
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
    readonly property int indicatorInset: 4

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

    implicitWidth: 360
    implicitHeight: ready ? column.implicitHeight : emptyText.implicitHeight
    width: implicitWidth
    height: implicitHeight

    // Body of the window list, plus the overflow line when the cap left rows out.
    // `spacing` is bound to `listSpacing` because the focus underline below
    // computes its own y from that same pitch.
    Column {
        id: column
        objectName: "windowHintColumn"
        width: parent.width
        spacing: root.listSpacing
        visible: root.ready

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

                // Test seam for the shared click-flash recipe.
                readonly property alias rowFlashAnimation: rowFlash
                readonly property alias rowFlashOverlay: rowFlashOverlay

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

        // Overflow line for the windows the cap left out. Empty when the list
        // fit, so visibility binds straight to the text.
        Text {
            objectName: "windowHintOverflow"
            width: parent.width
            height: visible ? implicitHeight : 0
            visible: root.overflowText !== ""
            text: root.overflowText
            color: LazerTheme.textMuted
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
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
        // row it marks, and the row spans the full content width.
        x: 0
        y: root.focusedRowTop
        width: parent.width
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
    Rectangle {
        id: focusUnderline
        objectName: "windowHintFocusIndicator"

        width: LazerTheme.barIndicatorHeight
        height: root._barLength
        radius: LazerTheme.barIndicatorRadius
        color: LazerTheme.osuGreen
        x: root.indicatorInset
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
    // already names the workspace, so the body explains the bare list.
    Text {
        objectName: "windowHintNoWindows"
        width: parent.width
        height: visible ? implicitHeight : 0
        visible: root.ready && !root.hasWindows
        text: "No windows on this workspace"
        color: LazerTheme.textMuted
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
    }
}