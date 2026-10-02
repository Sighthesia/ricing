import QtQuick
import QtTest
import "../../modules/bar" as Bar
import "../../modules/lazerbar" as Lazer
import "../../modules/bar/BarPopupMotion.js" as Motion

// Geometry contract for BarPopupHost's content slot during a tray-to-tray
// replacement.
//
// BarPopupHost is a PanelWindow, so it cannot be instantiated here at all:
// under qmltestrunner `module "Quickshell" plugin "quickshell-coreplugin" not
// found`, and `qs -p` on anything that mounts it maps a real layer-shell
// window over the user's desktop. So the part that decides whether painted
// content may leave the panel - the host's own state machine plus its content
// slot - is reproduced below around the REAL BarPopupActions, BarTrayMenuContent
// and TwoLayerPopup, with the host's expressions copied verbatim. A change to
// the gate under test therefore has to be made in both places; that duplication
// is the price of not mapping a window.
//
// The bug this exists for: on a fast sweep between adjacent tray icons the
// second intent lands while the first hop's exchange is still mounted.
// `beginIntentReplacement()` resets `_exchangeCommitted` on that frame and
// deliberately keeps `_transitionOutgoingIntent`, so a clip gate keyed on
// `_exchangeCommitted` alone released the slot back to the 504px tray input
// canvas for exactly one frame - 244px wider than the 260px painted panel, with
// the stale body still mounted. Measured here as slotW=504 / face=260.
Item {
    id: host
    width: 1920
    height: 1080

    // ---------------------------------------------------------------- state
    property var intent: null
    property var currentIntent: null
    property var pendingIntent: null
    property int transitionSerial: 0
    property bool open: false
    property bool surfaceActive: false
    property string direction: "down"
    property real anchorX: 0
    property real screenWidth: 1920
    property real screenHeight: 1080
    property real intentScreenWidth: 1920
    property real intentScreenHeight: 1080
    property int effectiveBarHeight: 48
    property int intentBarHeight: 48
    property int floatingMargin: 4
    property int intentFloatingMargin: 4

    property real displayX: 0
    property real displayY: 0
    property real displayWidth: 260
    property real displayHeight: 1
    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 260
    property real targetHeight: 1
    property real transitionProgress: 1
    readonly property real exchangeThreshold: 0.45
    property real _startX: 0
    property real _startY: 0
    property real _startW: 260
    property real _startH: 1
    property real _targetSnapX: 0
    property real _targetSnapY: 0
    property real _targetSnapW: 260
    property real _targetSnapH: 1
    property bool _exchangeCommitted: false
    property var _transitionOutgoingIntent: null
    property int _deferredRebaseSerial: -1
    property real revealDistance: 1
    property bool submenuFlipped: false
    property real flipBaseX: 0
    property real contentShiftX: submenuFlipped ? flipBaseX - displayX : 0
    readonly property real revealViewportHeight: Math.max(host.displayHeight,
            host.targetHeight, host.revealDistance, 1)
    property real contentSlideProgress: 0
    property real contentSlideSign: 1
    property real _contentSlideDistance: 260
    property real _lastMeasuredHeight: 0
    property var regionRect: ({ "x": 0, "y": 0, "width": 260, "height": 1 })

    readonly property bool identityHidden: !!(currentIntent && currentIntent.noIdentity)
    readonly property real identityHeight: host.identityHidden ? 0 : 48
    readonly property real travelSign: host.direction === "up" ? 1 : -1
    readonly property real identityTravel: host.identityHidden ? 1
            : Math.max(Number(popup.sidebarLayer.height),
            Number(popup.sidebarLayer.implicitHeight), 48) + 1
    readonly property real contentTravel: host.revealDistance + 1
    readonly property real identityOffset: host.travelSign * host.identityTravel
    readonly property real slideOffset: host.travelSign * host.contentTravel

    // ------------------------------------------------------------- geometry
    function popupWidthForIntent(intentObj, actions) {
        if (!intentObj || String(intentObj.kind || "") === "context")
            return 260
        var kind = String(intentObj.actionKind || "")
        if (kind === "media")
            return 420
        if (kind === "window-hint")
            return Number(actions ? actions.implicitWidth : 0) || 260
        return 260
    }
    readonly property real incomingPopupWidth: popupWidthForIntent(host.currentIntent, popupActions)
    readonly property real outgoingPopupWidth: popupWidthForIntent(
        host._transitionOutgoingIntent, popupActionsOutgoing)
    readonly property real popupSlotWidth: Math.max(host.incomingPopupWidth, host.outgoingPopupWidth)
    readonly property real trayInputWidth: host.popupSlotWidth
        + (popupActions && popupActions.trayMenuContent
            ? Number(popupActions.trayMenuContent.primaryMenuWidth) : 244)
    readonly property real trayFaceWidth: 260
    readonly property real popupContentWidth: host.currentIntent
        && String(host.currentIntent.actionKind || "") === "tray"
        ? Math.max(host.popupSlotWidth, host.trayInputWidth, host.targetWidth)
        : host.popupSlotWidth
    readonly property real paintedPanelWidth: host.currentIntent
            && String(host.currentIntent.kind || "") !== "context"
            && String(host.currentIntent.actionKind || "") === "tray"
        ? host.trayFaceWidth : host.popupWidthForIntent(host.currentIntent, popupActions)

    readonly property bool traySubmenuPanelAttached: (popupActions
            && popupActions.trayMenuContent
            && String(popupActions.trayMenuContent.submenuPhase || "") !== "closing"
            && String(popupActions.trayMenuContent.submenuPhase || "") !== "closed"
            && Number(popupActions.trayMenuContent.submenuProgress) > 0)
        || (host._transitionOutgoingIntent !== null
            && popupActionsOutgoing
            && popupActionsOutgoing.trayMenuContent
            && String(popupActionsOutgoing.trayMenuContent.submenuPhase || "") !== "closing"
            && String(popupActionsOutgoing.trayMenuContent.submenuPhase || "") !== "closed"
            && Number(popupActionsOutgoing.trayMenuContent.submenuProgress) > 0)

    // The REAL rule, shared with BarPopupHost. A copy here would pass vacuously
    // whenever the host's gate changed - which is exactly what happened once.
    readonly property bool contentBodiesDisplaced: Motion.contentBodiesDisplaced(
            host._transitionOutgoingIntent !== null, host.pendingIntent,
            host._exchangeCommitted, host.contentSlideProgress)

    function measuredContentHeight(intentObj) {
        if (!intentObj)
            return 0
        return Number(popupActions.implicitHeight) || 0
    }
    function popupHeightForIntent(intentObj) {
        var height = host.measuredContentHeight(intentObj)
        if (height > 0)
            return height
        return host._lastMeasuredHeight > 0 ? host._lastMeasuredHeight : 1
    }
    function noteMeasuredHeight() {
        var height = host.measuredContentHeight(host.currentIntent)
        if (height > 0)
            host._lastMeasuredHeight = height
    }
    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
    function anchorOf(intentObj) {
        var a = Number(intentObj ? intentObj.anchorX : -1)
        return isFinite(a) && a >= 0 ? a : host.anchorX
    }
    function targetGeometryFor(intentObj, width, height) {
        var left = host.clamp(host.anchorOf(intentObj) - width / 2, 8,
            Math.max(8, host.intentScreenWidth - width - 8))
        var top = host.intentBarHeight + host.intentFloatingMargin
        return { x: left, y: top, width: width, height: height }
    }
    function _submenuAllowance(intentObj, trayContent) {
        if (!trayContent || !intentObj)
            return 0
        if (String(intentObj.actionKind || "") !== "tray")
            return 0
        var band = trayContent.submenuColumn
        if (!band || !isFinite(Number(band.width)) || Number(band.width) <= 0)
            return 0
        return Number(band.width)
    }
    function computeAndCommitTargets(intentObj) {
        host.noteMeasuredHeight()
        var trayContent = popupActions ? popupActions.trayMenuContent : null
        var trayExtraWidth = trayContent ? Number(trayContent.extraWidth) : 0
        var displayedIntent = host.currentIntent || intentObj
        var isTrayIntent = displayedIntent
            && String(displayedIntent.actionKind || "") === "tray"
        var baseWidth = Math.max(240, 260, isTrayIntent ? 260 : 260)
        var width = baseWidth
        if (isFinite(trayExtraWidth) && trayExtraWidth > 0)
            width = baseWidth + trayExtraWidth
        var height = host.identityHeight + host.popupHeightForIntent(displayedIntent) + 1
        if (!isFinite(width) || width < 0)
            width = 240
        if (!isFinite(height) || height < 1)
            height = 1
        var baseGeometry = host.targetGeometryFor(intentObj, baseWidth, height)
        var geometry = host.targetGeometryFor(intentObj, width, height)
        if (isFinite(trayExtraWidth) && trayExtraWidth > 0 && isTrayIntent) {
            var maxLeft = 1920 - width - 8
            if (maxLeft < 8) maxLeft = 8
            var rightX = Math.min(baseGeometry.x, maxLeft)
            if (rightX < baseGeometry.x - 0.5) {
                host.submenuFlipped = true
                host.flipBaseX = baseGeometry.x
                if (trayContent) trayContent.submenuFlipped = true
                geometry.x = Math.max(baseGeometry.x - trayExtraWidth, 8)
            } else {
                host.submenuFlipped = false
                if (trayContent) trayContent.submenuFlipped = false
                geometry.x = rightX
            }
            if (geometry.x < 8) geometry.x = 8
        } else if (!isTrayIntent) {
            host.submenuFlipped = false
            if (trayContent) trayContent.submenuFlipped = false
        } else if (host.submenuFlipped && Math.abs(host.displayX - host.flipBaseX) < 1) {
            host.submenuFlipped = false
            if (trayContent) trayContent.submenuFlipped = false
        }
        host.targetWidth = geometry.width
        host.targetHeight = geometry.height
        host.targetX = geometry.x
        host.targetY = geometry.y
        host.regionRect = {
            "x": geometry.x,
            "y": geometry.y - viewport.y,
            "width": geometry.width + host._submenuAllowance(displayedIntent, trayContent),
            "height": geometry.height,
        }
        host.commitRevealDistance()
    }
    function updateTargetGeometry(intentObj, immediate) {
        host.computeAndCommitTargets(intentObj)
        host.retargetGeometry(intentObj, immediate === true || !host.open)
    }
    function commitRevealDistance() {
        var needed = Math.max(host.targetHeight, host.displayHeight, 1)
        if (popup.revealProgress < 0.01)
            host.revealDistance = needed
        else if (popup.revealProgress > 0.99)
            host.revealDistance = Math.max(host.revealDistance, needed)
    }
    function retargetGeometry(intentObj, immediate) {
        if (!host.open && !immediate)
            return
        if (!immediate && popup.revealProgress > 0.01 && popup.revealProgress < 0.99
                && !host.pendingIntent && host.transitionProgress >= 0.999) {
            host.rebaseGlide()
            return
        }
        if (immediate) {
            transitionMotion.stop()
            host.displayX = host.targetX
            host.displayY = host.targetY
            host.displayWidth = host.targetWidth
            host.displayHeight = host.targetHeight
            host._snapshotStart()
            host._snapshotTarget()
            host.transitionProgress = 1
            return
        }
        if (host.pendingIntent || (host._exchangeCommitted && host.transitionProgress < 0.999)) {
            host.rebaseGlide()
            return
        }
        host.startGlide()
    }
    function _snapshotStart() {
        host._startX = host.displayX; host._startY = host.displayY
        host._startW = host.displayWidth; host._startH = host.displayHeight
    }
    function _snapshotTarget() {
        host._targetSnapX = host.targetX; host._targetSnapY = host.targetY
        host._targetSnapW = host.targetWidth; host._targetSnapH = host.targetHeight
    }
    function _applyProgress() {
        host.displayX = host._startX + (host._targetSnapX - host._startX) * host.transitionProgress
        host.displayY = host._startY + (host._targetSnapY - host._startY) * host.transitionProgress
        host.displayWidth = host._startW + (host._targetSnapW - host._startW) * host.transitionProgress
        host.displayHeight = host._startH + (host._targetSnapH - host._startH) * host.transitionProgress
    }
    function startGlide() {
        host._snapshotStart(); host._snapshotTarget()
        transitionMotion.stop()
        host.transitionProgress = 0
        host._applyProgress()
        transitionMotion.restart()
    }
    function rebaseGlide() {
        host._snapshotStart(); host._snapshotTarget()
        host._applyProgress()
        if (host.transitionProgress >= 0.999) {
            if (Math.abs(host.displayX - host.targetX) > 0.5
                || Math.abs(host.displayWidth - host.targetWidth) > 0.5) {
                transitionMotion.stop()
                host.transitionProgress = 0
                host._snapshotStart(); host._snapshotTarget(); host._applyProgress()
                transitionMotion.restart()
            }
        } else if (!transitionMotion.running) {
            transitionMotion.restart()
        }
    }
    function commitExchange(serial) {
        if (serial !== host.transitionSerial || !host.pendingIntent || !host.open)
            return
        if (host._exchangeCommitted)
            return
        host._exchangeCommitted = true
        host._transitionOutgoingIntent = host.currentIntent
        var fromX = host.currentIntent ? Number(host.currentIntent.anchorX) : 0
        var toX = Number(host.pendingIntent.anchorX)
        host.contentSlideSign = isFinite(fromX) && isFinite(toX) && toX < fromX ? -1 : 1
        host.currentIntent = host.pendingIntent
        host.pendingIntent = null
        host._contentSlideDistance = Math.max(host.popupSlotWidth, 260)
        host.contentSlideProgress = 0
        contentSlideMotion.restart()
    }
    function settleContentSlide() {
        if (host._exchangeCommitted && !host.pendingIntent)
            host._transitionOutgoingIntent = null
    }
    function remeasureAndRebase(serial) {
        if (serial !== host.transitionSerial || !host.open)
            return
        if (popup.revealProgress > 0.01 && popup.revealProgress < 0.99) {
            host._deferredRebaseSerial = serial
            return
        }
        host._deferredRebaseSerial = -1
        host.computeAndCommitTargets(host.currentIntent)
        host.rebaseGlide()
    }
    function handleTransitionProgress() {
        host._applyProgress()
        if (!host._exchangeCommitted && host.pendingIntent
                && host.transitionProgress >= host.exchangeThreshold) {
            host.commitExchange(host.transitionSerial)
        }
    }
    function beginIntentReplacement(intentObj) {
        host.pendingIntent = intentObj
        host.transitionSerial += 1
        host._exchangeCommitted = false
        host._deferredRebaseSerial = -1
        var posGeom = host.targetGeometryFor(intentObj, host.targetWidth, host.targetHeight)
        host.targetX = posGeom.x
        host.targetY = posGeom.y
        host.commitRevealDistance()
        host.startGlide()
    }
    function invalidateContentTransition() {
        contentSlideMotion.stop()
        host.transitionSerial += 1
        host.pendingIntent = null
        host._exchangeCommitted = false
        host._transitionOutgoingIntent = null
        host._deferredRebaseSerial = -1
    }
    function sameIntent(left, right) {
        if (!left || !right) return false
        return String(left.widgetId || "") === String(right.widgetId || "")
            && String(left.instanceKey || "") === String(right.instanceKey || "")
            && String(left.kind || "hover") === String(right.kind || "hover")
            && String(left.actionKind || "") === String(right.actionKind || "")
            && String(left.delegateKey || "") === String(right.delegateKey || "")
    }
    function updateIntent(intentObj) {
        if (!intentObj) return
        host.anchorX = Number(intentObj.anchorX)
        var isOpen = host.open && host.currentIntent
        var isReplacement = isOpen && !host.sameIntent(host.currentIntent, intentObj)
        if (!isOpen) {
            host.invalidateContentTransition()
            host.currentIntent = intentObj
            host.updateTargetGeometry(intentObj, true)
        } else if (isReplacement) {
            host.beginIntentReplacement(intentObj)
        } else {
            host.updateTargetGeometry(intentObj)
        }
        host.open = true
        host.surfaceActive = true
    }

    NumberAnimation {
        id: transitionMotion
        target: host; property: "transitionProgress"
        from: 0; to: 1; duration: Lazer.MotionTokens.medium
        easing.type: Easing.OutQuint
    }
    NumberAnimation {
        id: contentSlideMotion
        target: host; property: "contentSlideProgress"
        from: 0; to: 1; duration: Lazer.MotionTokens.slow
        easing.type: Easing.OutCubic
        onFinished: host.settleContentSlide()
    }
    onTransitionProgressChanged: host.handleTransitionProgress()

    // ------------------------------------------------------------- viewport
    Item {
        id: viewport
        y: host.effectiveBarHeight + host.floatingMargin
        width: 1920
        height: 1080 - host.effectiveBarHeight - host.floatingMargin
        clip: true

        Item {
            id: container
            width: host.displayWidth
            height: host.revealViewportHeight
            x: host.displayX
            y: host.displayY - viewport.y

            Binding { target: popup.sidebarLayer; property: "x"; value: host.contentShiftX }
            Binding { target: popup.contentLayer; property: "x"; value: host.contentShiftX }

            Lazer.TwoLayerPopup {
                id: popup
                orientation: Lazer.TwoLayerPopup.Orientation.Vertical
                clipVertical: false
                direction: Lazer.TwoLayerPopup.Direction.Down
                opening: host.open
                width: container.width
                height: container.height
                revealProgress: 1
                contentDelay: 0
                railCollapsible: host.identityHidden
                animateLayerOpacity: false
                sidebarOffset: host.identityOffset
                contentOffset: host.slideOffset
                visible: host.surfaceActive

                sidebarData: Item {
                    width: host.popupSlotWidth
                    implicitWidth: host.popupSlotWidth
                    height: host.identityHeight
                    implicitHeight: height
                    visible: host.identityHeight > 0.5
                    clip: true
                }

                contentData: Item {
                    id: slotItem
                    objectName: "popupContentSlot"
                    width: host.contentBodiesDisplaced ? host.paintedPanelWidth
                             : host.popupContentWidth
                    implicitWidth: host.popupContentWidth
                    implicitHeight: host.popupHeightForIntent(host.currentIntent)
                    height: implicitHeight
                    Behavior on height {
                        enabled: host._exchangeCommitted
                        NumberAnimation { duration: Lazer.MotionTokens.slow; easing.type: Easing.OutCubic }
                    }
                    clip: host._transitionOutgoingIntent !== null || !host.traySubmenuPanelAttached
                    enabled: true
                    onImplicitHeightChanged: {
                        host.noteMeasuredHeight()
                        host.updateTargetGeometry(host.currentIntent)
                    }
                    onImplicitWidthChanged: host.updateTargetGeometry(host.currentIntent)

                    // Present in the real host: a tray submenu growing or
                    // retracting re-targets the panel geometry.
                    Connections {
                        target: popupActions.trayMenuContent
                        function onExtraWidthChanged() {
                            host.updateTargetGeometry(host.currentIntent)
                        }
                    }

                    Rectangle {
                        objectName: "popupContentSurface"
                        x: 0
                        y: host.direction === "down" ? -1 : 0
                        width: host.currentIntent
                            && String(host.currentIntent.actionKind || "") === "tray"
                            ? host.trayFaceWidth : parent.width
                        height: parent.height + 1
                        color: Lazer.LazerTheme.settingsSection
                    }

                    Bar.BarPopupActions {
                        id: popupActions
                        objectName: "popupActions"
                        z: 1
                        opacity: host._exchangeCommitted ? host.contentSlideProgress : 1
                        x: host._exchangeCommitted
                                ? host.contentSlideSign * host._contentSlideDistance * (1 - host.contentSlideProgress) : 0
                        width: parent.width
                        height: implicitHeight
                        actionKind: host.currentIntent && host.currentIntent.kind !== "context"
                                ? (host.currentIntent.actionKind || "") : "context"
                        payload: host.currentIntent ? host.currentIntent.payload : null
                    }

                    Bar.BarPopupActions {
                        id: popupActionsOutgoing
                        objectName: "popupActionsOutgoing"
                        z: 0
                        opacity: host._exchangeCommitted ? 1 - host.contentSlideProgress : 1
                        visible: host._transitionOutgoingIntent !== null
                        enabled: false
                        x: host._exchangeCommitted
                                ? -host.contentSlideSign * host._contentSlideDistance * host.contentSlideProgress : 0
                        width: parent.width
                        height: implicitHeight
                        actionKind: host._transitionOutgoingIntent
                                && host._transitionOutgoingIntent.kind !== "context"
                                ? (host._transitionOutgoingIntent.actionKind || "") : "context"
                        payload: host._transitionOutgoingIntent
                                ? host._transitionOutgoingIntent.payload : null
                    }
                }
            }
        }
    }

    function fakeEntry(text, extra) {
        var e = extra || ({})
        return { text: text, enabled: e.enabled !== false, isSeparator: !!e.isSeparator,
                 hasChildren: !!e.hasChildren, triggered: function() {} }
    }
    // A menu that is still fetching its rows: a handle is present, the model is
    // not. This is the real cold state (rootOpenerLoader has no item here).
    function loadingIntent(anchorX, tag) {
        return { widgetId: "tray", instanceKey: "tray", delegateKey: tag,
                 actionKind: "tray", anchorX: anchorX, title: tag,
                 payload: { trayItem: { id: tag }, menuHandle: { id: "raw-" + tag } } }
    }
    // Rows resolved: real BarTrayMenuContent renders `entries` directly.
    function readyIntent(anchorX, tag, nRows) {
        var rows = []
        for (var i = 0; i < nRows; i++)
            rows.push(fakeEntry(tag + " row " + i))
        return { widgetId: "tray", instanceKey: "tray", delegateKey: tag,
                 actionKind: "tray", anchorX: anchorX, title: tag,
                 payload: { trayItem: { id: tag }, menuHandle: { id: "raw-" + tag },
                            useStubEntries: true, entries: rows } }
    }

    // Records the first frame on which the slot leaves the painted panel while a
    // body is displaced, a stale body is mounted, or a replacement is pending.
    // The slot is the clip owner, so its width IS the clip rect.
    property bool watching: false
    property int unboundFrames: 0
    property int staleFrames: 0
    property real widestOverhang: 0
    // Largest flip-compensation shift seen while watching. The edge test needs
    // it to prove the scenario actually engaged the flip rather than passing
    // because nothing happened.
    property real maxShiftSeen: 0
    property string unboundDetail: ""
    function watchSlot() {
        if (!host.watching)
            return
        var stale = host.pendingIntent !== null
            || host._transitionOutgoingIntent !== null
            || (host._exchangeCommitted && host.contentSlideProgress < 1)
        if (!stale)
            return
        host.staleFrames += 1
        host.maxShiftSeen = Math.max(host.maxShiftSeen, Math.abs(host.contentShiftX))
        var excess = slotItem.width - host.paintedPanelWidth
        if (excess > 0.5) {
            host.unboundFrames += 1
            if (excess > host.widestOverhang)
                host.widestOverhang = excess
            if (host.unboundDetail === "")
                host.unboundDetail = "slotW=" + Math.round(slotItem.width)
                    + " face=" + Math.round(host.paintedPanelWidth)
                    + " over=" + Math.round(excess)
                    + " pending=" + (host.pendingIntent !== null)
                    + " outgoing=" + (host._transitionOutgoingIntent !== null)
                    + " committed=" + host._exchangeCommitted
                    + " clip=" + slotItem.clip
        }
    }

    Timer {
        interval: 4
        repeat: true
        running: host.watching
        onTriggered: host.watchSlot()
    }

    TestCase {
        id: tc
        name: "BarPopupSlotGeometry"
        when: windowShown

        function settleAt(anchorX, tag, rows) {
            host.open = false
            host.surfaceActive = false
            host.invalidateContentTransition()
            host.updateIntent(host.readyIntent(anchorX, tag, rows))
            wait(500)
        }

        function resetWatch() {
            host.unboundFrames = 0
            host.staleFrames = 0
            host.widestOverhang = 0
            host.unboundDetail = ""
        }

        // THE REGRESSION. Hop 1 commits an exchange, so a stale body is mounted.
        // Hop 2 lands before that slide has settled and is read on the frame it
        // lands, where `_exchangeCommitted` has already been reset while
        // `_transitionOutgoingIntent` is still live.
        function test_pendingReplacementKeepsTheClipOnThePaintedPanel() {
            settleAt(1164, "clipA", 9)
            resetWatch()
            host.watching = true
            host.updateIntent(host.readyIntent(1120, "clipB", 11))
            wait(60)
            verify(host._exchangeCommitted, "the first exchange never committed")
            verify(host._transitionOutgoingIntent !== null,
                "the first exchange mounted no outgoing body")
            host.updateIntent(host.readyIntent(1076, "clipC", 6))
            var slot = slotItem.width
            var face = host.paintedPanelWidth
            verify(host._transitionOutgoingIntent !== null,
                "the outgoing body was already released, so this is not the window")
            compare(slot <= face + 0.5, true,
                "the content slot jumped back to the 504px tray input canvas ("
                + Math.round(slot) + "px, face " + Math.round(face) + "px) on the "
                + "frame a fast second hop landed, while the previous icon's body "
                + "was still mounted")
            wait(800)
            host.watching = false
            compare(host.unboundFrames, 0,
                "the content slot left the painted panel in "
                + host.unboundFrames + " of " + host.staleFrames
                + " displaced/stale frames, worst overhang "
                + Math.round(host.widestOverhang) + "px: " + host.unboundDetail)
        }

        // Same contract with the icon at the screen's right edge, where a second
        // level has to flip left and the flip compensation
        // (`Binding` on popup.contentLayer/.sidebarLayer x = contentShiftX)
        // translates the whole slot sideways. The container then has to stay at
        // least face + shift wide, or the primary face hangs off its own panel.
        function test_edgeFlipKeepsTheShiftedFaceInsideTheContainer() {
            settleAt(1890, "edgeA", 9)
            resetWatch()
            host.watching = true
            host.updateIntent(host.readyIntent(1846, "edgeB", 9))
            wait(40)
            host.updateIntent(host.readyIntent(1802, "edgeC", 9))
            wait(900)
            host.watching = false
            verify(host.submenuFlipped === true || host.maxShiftSeen === 0,
                "the edge scenario never engaged the flip, so it proves nothing")
            compare(host.unboundFrames, 0,
                "the edge flip let the content leave the panel in "
                + host.unboundFrames + " of " + host.staleFrames
                + " displaced/stale frames, worst overhang "
                + Math.round(host.widestOverhang) + "px: " + host.unboundDetail)
        }

        // A handover must not carry the previous icon's held height: the panel
        // then stands at the old height with no rows in it, which is the empty
        // dark card the user photographed. Contract kept by BarTrayMenuContent
        // (363ebcc8); asserted here through the host so a host-side latch
        // (_lastMeasuredHeight) cannot quietly reintroduce it.
        function test_handoverDoesNotCarryThePreviousIconsHeight() {
            settleAt(1164, "heldA", 12)
            var menu = popupActions.trayMenuContent
            tryVerify(function() { return menu.heldHeight > 100 }, false,
                "a 12-row menu should raise a real held height", 3000, 20)
            host.updateIntent(host.loadingIntent(1120, "heldB"))
            wait(80)
            compare(menu.heldHeight, 0,
                "the next icon's panel adopted the previous icon's height")
            verify(host.targetHeight < 250,
                "the panel is standing " + Math.round(host.targetHeight)
                + "px tall for an icon whose rows have not arrived")
        }
    }
}
