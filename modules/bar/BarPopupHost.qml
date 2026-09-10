import QtQuick
import Quickshell
import Quickshell.Wayland
import "../lazerbar"
import "../../services" as Services
import "./BarHoverLogic.js" as BarHoverLogic

// Per-screen fixed hover popup host with stable PanelWindow geometry.
// Keeps the layer-shell window size fixed; only the inner TwoLayerPopup
// animates via revealProgress. Hover bridge lives in open/close timers.
PanelWindow {
    id: root

    // Name the surface so compositor diagnostics can identify it.
    WlrLayershell.namespace: "afloat-popup"
    // Keep the full-screen owner below the bar and settings owners.
    // The mask limits input to the small active popup rectangle.
    WlrLayershell.layer: WlrLayer.Top

    // Intent payload from the hovered widget.
    property var intent: null
    property var currentIntent: null
    property var pendingIntent: null
    property int transitionSerial: 0
    readonly property bool closeTimerRunning: closeTimer.running
    readonly property bool contentInteractive: popup.interactable
    property bool open: false
    property bool widgetHovered: false
    property bool popupHovered: false
    // Keep the full-screen layer-shell surface absent until a popup owns it.
    property bool surfaceActive: false
    property string direction: "down"
    property real anchorX: 0
    property real screenWidth: 1920
    property real screenHeight: 1080
    property int effectiveBarHeight: 48
    property int floatingMargin: 4
    property real intentScreenWidth: 0
    property real intentScreenHeight: 0
    property real intentBarHeight: 0
    property real intentFloatingMargin: -1
    property bool popupHoverWasActive: false
    function setReducedMotionOverride(v) { MotionTokens.reducedMotionOverride = v }

    property real displayX: 0
    property real displayY: 0
    property real displayWidth: 260
    property real displayHeight: 1
    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 260
    property real targetHeight: 1
    // Shared replacement glide progress: 0→1 per replacement, 1 = settled.
    // intent = newest accepted (diagnostics); currentIntent = rendered.
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
    // Set when a new intent arrives while the exit reveal still owns the
    // surface: onOpenChanged then reverses the reveal instead of snapping.
    property bool _reviving: false
    // Stable travel distance for the current reveal/exit cycle.
    property real revealDistance: 1
    // Left-flip state for edge tray submenus: the container expands left
    // while both layers glide right by the same delta (contentShiftX), so
    // the primary column never moves on screen. flipBaseX is the primary's
    // pinned left edge; the flip releases once the container glides home.
    property bool submenuFlipped: false
    property real flipBaseX: 0
    property real contentShiftX: submenuFlipped ? flipBaseX - displayX : 0
    // Keep the reveal viewport large enough while displayed geometry morphs.
    readonly property real revealViewportHeight: Math.max(root.displayHeight,
            root.targetHeight, root.revealDistance, 1)

    readonly property real activeScreenWidth: intentScreenWidth > 0 ? intentScreenWidth : screenWidth
    readonly property real activeScreenHeight: intentScreenHeight > 0 ? intentScreenHeight : screenHeight
    readonly property real activeBarHeight: intentBarHeight > 0 ? intentBarHeight : effectiveBarHeight
    readonly property real activeFloatingMargin: intentFloatingMargin >= 0 ? intentFloatingMargin : floatingMargin

    // Expose the two-layer slots generically; host owns only the surface.
    readonly property alias sidebarData: popup.sidebarData
    readonly property alias contentData: popup.contentData
    readonly property alias popupItem: popup
    readonly property alias popupContainerItem: popupGeometry
    readonly property alias popupViewportItem: popupViewport
    readonly property alias contextActions: contextPopupActions

    signal actionRequested(string action)
    signal closeRequested()

    // Identity travels its own height; content starts further away, matching
    // the settings panel's shorter-rail / longer-content stagger.
    readonly property real travelSign: root.direction === "up" ? 1 : -1
    readonly property real identityTravel: Math.max(Number(popup.sidebarLayer.height),
            Number(popup.sidebarLayer.implicitHeight), 48) + 1
    readonly property real contentTravel: root.revealDistance + 1
    readonly property real identityOffset: root.travelSign * root.identityTravel
    readonly property real slideOffset: root.travelSign * root.contentTravel
    // Content slide runs on its own clock after the exchange (the geometry
    // glide's eased tail is too abrupt) and freezes its travel distance at
    // commit so the morphing shell width cannot jitter the sliding layers.
    // The same clock drives the layer fade: incoming fades 0->1 while the
    // outgoing fades 1->0, so asymmetric hops never read as a rigid shift.
    property real contentSlideProgress: 0
    property int contentSlideSign: 1
    property real _contentSlideDistance: 260

    function startReveal(target) {
        revealMotion.stop()
        var dist = Math.abs(target - popup.revealProgress)
        if (dist < 0.001) {
            popup.revealProgress = target
            return
        }
        // Scale duration by travelled distance so an interrupted reveal
        // resumes at proportional speed instead of jumping or lingering.
        // Tray has no content delay (contentDelay 0), so its enter only needs
        // the sidebar span instead of the full two-layer total.
        var base = MotionTokens.reducedMotion ? MotionTokens.fast : popup.revealDuration
        if (target >= 1 && root.currentIntent && root.currentIntent.actionKind === "tray")
            base = MotionTokens.settingsSidebarFade
        revealMotion.duration = Math.max(MotionTokens.fast, Math.round(base * dist))
        // OutQuint front-loads most travel into the first frames (looks like
        // an instant pop); OutCubic stays smooth. Exit uses InOutQuad so it
        // slides out visibly instead of lingering then vanishing (InQuad).
        revealMotion.easing.type = target >= 1 ? Easing.OutCubic : Easing.InOutQuad
        revealMotion.to = target
        revealMotion.restart()
    }

    // Reuse the settings-panel diagnostics channel so one IPC switch turns on
    // both surfaces; every popup decision is logged without adding an owner.
    readonly property bool debugEnabled: Services.SettingsService.hoverDebugEnabled
    property string _lastDebugSignature: ""

    function _debugRect(item) {
        if (!item)
            return { "x": 0, "y": 0, "width": 0, "height": 0 }
        return {
            "x": Math.round(Number(item.x) * 10) / 10, "y": Math.round(Number(item.y) * 10) / 10,
            "width": Math.max(0, Math.round(Number(item.width) * 10) / 10),
            "height": Math.max(0, Math.round(Number(item.height) * 10) / 10),
        }
    }

    function debugSnapshot() {
        return {
            "host": {
                "phase": root.open ? "open" : (root.surfaceActive ? "revealing" : "closed"),
                "surfaceActive": root.surfaceActive, "widgetHovered": root.widgetHovered,
                "popupHovered": root.popupHovered, "direction": root.direction,
                "windowVisible": root.visible, "windowRect": root._debugRect(root),
                "layer": Number(root.WlrLayershell.layer),
                "closeTimer": closeTimer.running, "clearTimer": clearIntentTimer.running,
            },
            "intent": root.intent ? {
                "widgetId": String(root.intent.widgetId || ""), "kind": String(root.intent.kind || ""),
                "actionKind": String(root.intent.actionKind || ""),
                "anchorX": Number(root.intent.anchorX),
            } : null,
            "container": { "rect": root._debugRect(popupContainer), "visible": popupContainer.visible },
            "popup": {
                "visible": popup.visible, "revealProgress": Number(popup.revealProgress),
                "sidebar": root._debugRect(popup.sidebarLayer),
                "content": root._debugRect(popup.contentLayer),
                "sidebarOpacity": Number(popup.sidebarLayer.opacity),
                "contentOpacity": Number(popup.contentLayer.opacity),
            },
        }
    }

    function debugLog(event, payload) {
        if (!root.debugEnabled)
            return
        var entry = Object.assign({ "event": event }, payload || ({}))
        var signature = JSON.stringify(entry)
        if (signature === root._lastDebugSignature)
            return
        root._lastDebugSignature = signature
        console.log("[afloat:PopupDebug]", signature)
    }

    function emitDebugSnapshot() {
        root.debugLog("snapshot", root.debugSnapshot())
    }

    // Poll only while diagnostics are enabled so no extra owner or timer runs live.
    Timer {
        interval: 120
        repeat: true
        running: root.debugEnabled
        onTriggered: root.emitDebugSnapshot()
    }

    onPopupHoveredChanged: {
        if (popupHoverWasActive && !popupHovered)
            requestClose()
        popupHoverWasActive = popupHovered
    }

    function updateIntent(intentObj) {
        if (!intentObj)
            return

        // A new intent revives the live host before replacement is evaluated.
        // This prevents a pending close from racing the single popup instance.
        cancelClose()
        var isOpen = root.open && root.currentIntent
        // A close that already flipped open keeps the surface and both intents
        // alive until the exit cleanup runs: a new intent in that window must
        // revive the live popup (glide + slide) instead of reopening it.
        var isExiting = !root.open && root.surfaceActive && root.currentIntent !== null
        var isLive = isOpen || isExiting
        var isReplacement = isLive && !root.sameIntent(root.currentIntent, intentObj)
        if (!isLive) {
            root._reviving = false
            root.invalidateContentTransition()
            root.currentIntent = intentObj
            root.applyIntentFields(intentObj)
            root.updateTargetGeometry(intentObj)
        } else if (isReplacement) {
            // intent = newest accepted for diagnostics; content stays on A
            // until the shared progress crosses the exchange threshold.
            root._reviving = isExiting
            root.applyIntentFields(intentObj)
            root.beginIntentReplacement(intentObj)
        } else {
            // Same instance updates (for example a tray delegate label or a
            // refreshed callback payload) stay live without a crossfade.
            root._reviving = isExiting
            root.invalidateContentTransition()
            root.currentIntent = intentObj
            root.applyIntentFields(intentObj)
            root.updateTargetGeometry(intentObj)
            // Reviving with the same intent: the retarget above stays parked
            // while closed, so home a frozen display directly.
            if (isExiting)
                root.rebaseGlide()
        }

        root.open = true
        root.surfaceActive = true
        clearIntentTimer.stop()
        root.debugLog("open", { "windowVisible": root.visible, "surfaceActive": true,
                                "direction": root.direction, "anchorX": root.anchorX })
    }

    function applyIntentFields(intentObj) {
        root.intent = intentObj
        var anchor = Number(intentObj.anchorX)
        if (isFinite(anchor) && anchor >= 0)
            root.anchorX = anchor
        var sw = Number(intentObj.screenWidth)
        if (isFinite(sw) && sw > 0)
            root.intentScreenWidth = sw
        var sh = Number(intentObj.screenHeight)
        if (isFinite(sh) && sh > 0)
            root.intentScreenHeight = sh
        var barHeight = Number(intentObj.effectiveBarHeight)
        if (isFinite(barHeight) && barHeight >= 0)
            root.intentBarHeight = barHeight
        var margin = Number(intentObj.floatingMargin)
        if (isFinite(margin) && margin >= 0)
            root.intentFloatingMargin = margin
        var pos = intentObj.barPosition !== undefined
                ? String(intentObj.barPosition).trim().toLowerCase() : ""
        if (pos === "top" || pos === "bottom")
            root.direction = BarHoverLogic.popupDirection(pos)
    }

    function invalidateContentTransition() {
        contentSlideMotion.stop()
        root.transitionSerial += 1
        root.pendingIntent = null
        root._exchangeCommitted = false
        root._transitionOutgoingIntent = null
        root._deferredRebaseSerial = -1
    }

    // Displayed geometry is a pure function of the shared eased progress.
    // Every channel reads the same clock so X/Y/W/H never disagree on phase.
    function _snapshotStart() {
        root._startX = root.displayX
        root._startY = root.displayY
        root._startW = root.displayWidth
        root._startH = root.displayHeight
    }

    function _snapshotTarget() {
        root._targetSnapX = root.targetX
        root._targetSnapY = root.targetY
        root._targetSnapW = root.targetWidth
        root._targetSnapH = root.targetHeight
    }

    function _applyProgress() {
        root.displayX = root._startX + (root._targetSnapX - root._startX) * root.transitionProgress
        root.displayY = root._startY + (root._targetSnapY - root._startY) * root.transitionProgress
        root.displayWidth = root._startW + (root._targetSnapW - root._startW) * root.transitionProgress
        root.displayHeight = root._startH + (root._targetSnapH - root._startH) * root.transitionProgress
    }

    function startGlide() {
        root._snapshotStart()
        root._snapshotTarget()
        transitionMotion.stop()
        root.transitionProgress = 0
        root._applyProgress()
        transitionMotion.restart()
    }

    // Rebase without resetting progress: start = live display, target = new
    // goals, progress untouched. Continuity holds by construction.
    function rebaseGlide() {
        root._snapshotStart()
        root._snapshotTarget()
        root._applyProgress()
        if (root.transitionProgress >= 0.999) {
            var dx = Math.abs(root.displayX - root.targetX)
            var dy = Math.abs(root.displayY - root.targetY)
            var dw = Math.abs(root.displayWidth - root.targetWidth)
            var dh = Math.abs(root.displayHeight - root.targetHeight)
            if (dx > 0.5 || dy > 0.5 || dw > 0.5 || dh > 0.5) {
                transitionMotion.stop()
                root.transitionProgress = 0
                root._snapshotStart()
                root._snapshotTarget()
                root._applyProgress()
                transitionMotion.restart()
            }
        } else if (!transitionMotion.running) {
            transitionMotion.restart()
        }
    }

    function commitExchange(serial) {
        if (serial !== root.transitionSerial || !root.pendingIntent || !root.open)
            return
        if (root._exchangeCommitted)
            return
        root._exchangeCommitted = true
        root._transitionOutgoingIntent = root.currentIntent
        // Slide direction follows the pointer: moving right brings the new
        // content in from the right edge; moving left mirrors the track.
        var fromX = root.currentIntent ? Number(root.currentIntent.anchorX) : 0
        var toX = Number(root.pendingIntent.anchorX)
        root.contentSlideSign = isFinite(fromX) && isFinite(toX) && toX < fromX ? -1 : 1
        root._contentSlideDistance = Math.max(root.popupItem.contentLayer.width, 260)
        root.contentSlideProgress = 0
        root.currentIntent = root.pendingIntent
        root.pendingIntent = null
        if (MotionTokens.reducedMotion)
            root.contentSlideProgress = 1
        else
            contentSlideMotion.restart()
        var captured = serial
        Qt.callLater(function() { root.remeasureAndRebase(captured) })
    }

    // Exchange cleanup lives here so the slide animation and tests share one
    // settle path; stale guards keep a cancelled transition from clearing.
    function settleContentSlide() {
        if (root._exchangeCommitted && !root.pendingIntent)
            root._transitionOutgoingIntent = null
    }

    function remeasureAndRebase(serial) {
        if (serial !== root.transitionSerial || !root.open)
            return
        if (!root.currentIntent)
            return
        // Replacement during a fresh-open reveal flight must not fight the
        // reveal: position glide already runs, height rebase waits for settle.
        if (popup.revealProgress > 0.01 && popup.revealProgress < 0.99) {
            root._deferredRebaseSerial = serial
            return
        }
        root._deferredRebaseSerial = -1
        root.computeAndCommitTargets(root.currentIntent)
        root.rebaseGlide()
    }

    function handleTransitionProgress() {
        root._applyProgress()
        if (!root._exchangeCommitted && root.pendingIntent
                && root.transitionProgress >= root.exchangeThreshold) {
            root.commitExchange(root.transitionSerial)
        }
    }

    function beginIntentReplacement(intentObj) {
        root.pendingIntent = intentObj
        root.transitionSerial += 1
        root._exchangeCommitted = false
        root._deferredRebaseSerial = -1
        if (MotionTokens.reducedMotion) {
            // Reduced motion: commit newest immediately, assign final geometry.
            root.currentIntent = root.pendingIntent
            root.pendingIntent = null
            root._exchangeCommitted = true
            root._transitionOutgoingIntent = null
            contentSlideMotion.stop()
            root.contentSlideProgress = 1
            root.computeAndCommitTargets(root.currentIntent)
            transitionMotion.stop()
            root.displayX = root.targetX
            root.displayY = root.targetY
            root.displayWidth = root.targetWidth
            root.displayHeight = root.targetHeight
            root._snapshotStart()
            root._snapshotTarget()
            root.transitionProgress = 1
            return
        }
        // Start the position glide on the same frame using A's committed
        // size (targetWidth/Height), not the transient display value: with
        // rapid A->B->C cascades the display may still carry an older intent's
        // mid-glide value, while target* is A's measured size. currentIntent
        // stays on A. Continuity holds because startGlide snapshots the live
        // display as the glide start.
        var posGeom = targetGeometryFor(intentObj, root.targetWidth, root.targetHeight)
        root.targetX = posGeom.x
        root.targetY = posGeom.y
        root.commitRevealDistance()
        root.startGlide()
    }

    function applyPendingIntent(serial) {
        // Legacy next-tick entry kept for harness compatibility: route stale
        // serials through the serial guard, live ones through the exchange.
        if (serial !== root.transitionSerial || !root.pendingIntent)
            return
        if (!root.open)
            return
        if (MotionTokens.reducedMotion) {
            root.currentIntent = root.pendingIntent
            root.pendingIntent = null
            root._exchangeCommitted = true
            root._transitionOutgoingIntent = null
            contentSlideMotion.stop()
            root.contentSlideProgress = 1
            root.computeAndCommitTargets(root.currentIntent)
            transitionMotion.stop()
            root.displayX = root.targetX
            root.displayY = root.targetY
            root.displayWidth = root.targetWidth
            root.displayHeight = root.targetHeight
            root._snapshotStart()
            root._snapshotTarget()
            root.transitionProgress = 1
            return
        }
        root.commitExchange(serial)
    }

    function sameIntent(left, right) {
        if (!left || !right)
            return false
        return String(left.widgetId || "") === String(right.widgetId || "")
            && String(left.instanceKey || "") === String(right.instanceKey || "")
            && String(left.kind || "hover") === String(right.kind || "hover")
            && String(left.actionKind || "") === String(right.actionKind || "")
            // Tray delegates share the widget identity; the per-icon key
            // decides whether the popup glides or stays live in place.
            && String(left.delegateKey || "") === String(right.delegateKey || "")
    }

    function _intentNumber(intentObj, fieldName, fallback, minimum) {
        var value = Number(intentObj && intentObj[fieldName])
        return isFinite(value) && value >= minimum ? value : fallback
    }

    function anchorXForIntent(intentObj) {
        return _intentNumber(intentObj, "anchorX", root.anchorX, 0)
    }

    function activeScreenWidthForIntent(intentObj) {
        return _intentNumber(intentObj, "screenWidth", root.activeScreenWidth, 1)
    }

    function directionForIntent(intentObj) {
        var position = intentObj && intentObj.barPosition !== undefined
                ? String(intentObj.barPosition).trim().toLowerCase() : ""
        return position === "top" || position === "bottom"
                ? BarHoverLogic.popupDirection(position) : root.direction
    }

    function barHeightForIntent(intentObj) {
        return _intentNumber(intentObj, "effectiveBarHeight", root.activeBarHeight, 0)
    }

    function floatingMarginForIntent(intentObj) {
        return _intentNumber(intentObj, "floatingMargin", root.activeFloatingMargin, 0)
    }

    function screenHeightForIntent(intentObj) {
        return _intentNumber(intentObj, "screenHeight", root.activeScreenHeight, 1)
    }

    function popupHeightForIntent(intentObj) {
        if (!intentObj)
            return 1
        // Hold stable height while the two-layer reveal is in flight so a
        // late DBus menu fetch does not retarget geometry mid-slide.
        if (popup.revealProgress > 0.01 && popup.revealProgress < 0.99) {
            if (popup.stableContentHeight > 0)
                return popup.stableContentHeight
            if (popup.stableSidebarHeight > 0)
                return popup.stableSidebarHeight
        }
        var height = String(intentObj.kind || "") === "context"
                ? contextPopupActions.implicitHeight : popupActions.implicitHeight
        return isFinite(Number(height)) && Number(height) > 0 ? Number(height) : 1
    }

    function targetGeometryFor(intentObj, width, height) {
        var left = BarHoverLogic.clampAnchor(anchorXForIntent(intentObj) - width / 2,
                width, activeScreenWidthForIntent(intentObj), 8)
        var top = directionForIntent(intentObj) === "down"
                ? barHeightForIntent(intentObj) + floatingMarginForIntent(intentObj)
                : Math.max(0, screenHeightForIntent(intentObj) - barHeightForIntent(intentObj)
                    - floatingMarginForIntent(intentObj) - height)
        return { x: left, y: top, width: width, height: height }
    }

    function computeAndCommitTargets(intentObj) {
        var trayExtraWidth = popupActions && popupActions.trayMenuContent
                ? Number(popupActions.trayMenuContent.extraWidth) : 0
        var baseWidth = Math.max(240, popup.sidebarLayer.implicitWidth || 260,
                popup.contentLayer.implicitWidth || 260)
        var width = baseWidth
        if (isFinite(trayExtraWidth) && trayExtraWidth > 0)
            width = baseWidth + trayExtraWidth
        var displayedIntent = root.currentIntent || intentObj
        var sidebarHeight = Math.max(Number(popup.sidebarLayer.implicitHeight),
                Number(popup.sidebarLayer.height), 48)
        var height = sidebarHeight + popupHeightForIntent(displayedIntent) + 1
        if (!isFinite(width) || width < 0)
            width = 240
        if (!isFinite(height) || height < 1)
            height = 1
        // Keep the primary column anchored; expand only to the right so the
        // root list never shifts when the second level appears. At the
        // screen edge right-expansion would shove the primary left, so flip
        // the submenu left and expand the container left instead.
        var baseGeometry = targetGeometryFor(intentObj, baseWidth, height)
        var geometry = targetGeometryFor(intentObj, width, height)
        var trayContent = popupActions ? popupActions.trayMenuContent : null
        var isTrayIntent = displayedIntent && String(displayedIntent.actionKind || "") === "tray"
        if (isFinite(trayExtraWidth) && trayExtraWidth > 0 && isTrayIntent) {
            var maxLeft = root.activeScreenWidth - width - 8
            if (maxLeft < 8) maxLeft = 8
            var rightX = Math.min(baseGeometry.x, maxLeft)
            if (rightX < baseGeometry.x - 0.5) {
                root.submenuFlipped = true
                root.flipBaseX = baseGeometry.x
                if (trayContent) trayContent.submenuFlipped = true
                geometry.x = Math.max(baseGeometry.x - trayExtraWidth, 8)
            } else {
                root.submenuFlipped = false
                if (trayContent) trayContent.submenuFlipped = false
                geometry.x = rightX
            }
            if (geometry.x < 8) geometry.x = 8
        } else if (!isTrayIntent) {
            root.submenuFlipped = false
            if (trayContent) trayContent.submenuFlipped = false
        } else if (root.submenuFlipped && Math.abs(root.displayX - root.flipBaseX) < 1) {
            root.submenuFlipped = false
            if (trayContent) trayContent.submenuFlipped = false
        }
        root.targetWidth = geometry.width
        root.targetHeight = geometry.height
        // Target X/Y are owned here: geometry.x already carries the tray
        // flip/right-expansion pinning. retargetGeometry must not recompute
        // them from the full width (that re-centers and undoes the pin).
        root.targetX = geometry.x
        root.targetY = geometry.y
        root.commitRevealDistance()
    }

    function updateTargetGeometry(intentObj, immediate) {
        root.computeAndCommitTargets(intentObj)
        root.retargetGeometry(intentObj, immediate === true || !root.open)
    }

    function commitRevealDistance() {
        var needed = Math.max(root.targetHeight, root.displayHeight, 1)
        if (popup.revealProgress < 0.01)
            root.revealDistance = needed
        else if (popup.revealProgress > 0.99)
            root.revealDistance = Math.max(root.revealDistance, needed)
    }

    function retargetGeometry(intentObj, immediate) {
        // Closed host owns no motion: targets may refresh, but starting or
        // resuming a glide while exiting would fight the exit reveal.
        if (!root.open && !immediate)
            return
        // Single shared progress driver: display* is only written by the
        // progress function (or the immediate/reduced-motion direct assign).
        // Late DBus batches must not restart the glide mid-slide: rebase
        // keeps the current progress so the remaining curve covers the
        // corrected distance without a bounce.
        if (!immediate && !MotionTokens.reducedMotion
                && popup.revealProgress > 0.01 && popup.revealProgress < 0.99
                && !root.pendingIntent && root.transitionProgress >= 0.999) {
            return
        }
        if (immediate || MotionTokens.reducedMotion) {
            transitionMotion.stop()
            root.displayX = root.targetX
            root.displayY = root.targetY
            root.displayWidth = root.targetWidth
            root.displayHeight = root.targetHeight
            root._snapshotStart()
            root._snapshotTarget()
            root.transitionProgress = 1
            return
        }
        // Replacement glide active (pending pre-exchange, or post-exchange
        // still travelling): rebase from live display, keep progress.
        if (root.pendingIntent || (root._exchangeCommitted && root.transitionProgress < 0.999)) {
            root.rebaseGlide()
            return
        }
        root.startGlide()
    }

    function showIntent(intentObj) {
        updateIntent(intentObj)
    }

    function requestClose() {
        if (closeTimer.running)
            return
        // A pre-exchange close cancels the replacement outright. A
        // post-exchange close freezes the shell glide but lets the content
        // slide and height finish under the exit reveal instead of snapping
        // them to their end state. The serial bump drops deferred swaps so
        // nothing installs content after the close has begun.
        transitionMotion.stop()
        if (root.pendingIntent)
            root.invalidateContentTransition()
        else {
            root.transitionSerial += 1
            root._deferredRebaseSerial = -1
        }
        root.debugLog("closePending", { "widgetHovered": root.widgetHovered, "popupHovered": root.popupHovered })
        closeTimer.start()
    }

    function cancelClose() {
        closeTimer.stop()
    }

    // Explicit user close with the shared exit reveal. Clears both hover
    // owners first so the close timer can actually fire for persistent
    // menus that hold widgetHovered while open.
    function requestAnimatedClose() {
        root.widgetHovered = false
        root.popupHovered = false
        root.requestClose()
    }

    // Release the popup owner before another overlay claims the screen.
    function dismissImmediately() {
        root.debugLog("dismissed", { "open": root.open, "surfaceActive": root.surfaceActive })
        closeTimer.stop()
        clearIntentTimer.stop()
        revealMotion.stop()
        transitionMotion.stop()
        contentSlideMotion.stop()
        root.invalidateContentTransition()
        popup.revealProgress = 0
        root.open = false
        root.widgetHovered = false
        root.popupHovered = false
        root.intent = null
        root.currentIntent = null
        root.pendingIntent = null
        root._transitionOutgoingIntent = null
        root._reviving = false
        root.transitionSerial += 1
        root.transitionProgress = 1
        root.surfaceActive = false
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    // Keep the layer-shell surface fixed at screen size; only the inner
    // clipped content animates so per-frame resizes never cross a protocol
    // commit boundary.
    implicitWidth: screen ? screen.width : root.screenWidth
    implicitHeight: screen ? screen.height : root.screenHeight
    // Keep the host full-screen; the inner popup owns its absolute bar-adjacent
    // placement so an upward popup can occupy the space above a bottom bar.
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    margins { top: 0; bottom: 0; left: 0; right: 0 }
    // No input when closed; the window otherwise masks only the popup.
    // Keep the visual/input region alive for the exit reveal after open flips
    // false; clearing it at close start cuts the second layer off immediately.
    mask: Region { item: root.surfaceActive ? popupContainer : null }
    // Do not keep a full-screen transparent surface above the settings window
    // when no bar popup is open or completing its reveal.
    visible: root.surfaceActive

    // Close after MotionTokens.fast if both hover owners are gone.
    Timer {
        id: closeTimer
        interval: MotionTokens.fast
        onTriggered: {
            if (BarHoverLogic.shouldClose(root.widgetHovered, root.popupHovered, true)) {
                root.debugLog("closed", { "revealProgress": Number(popup.revealProgress) })
                // Freeze geometry but keep an in-flight content slide/height
                // alive under the exit reveal; retain both intents until the
                // exit reveal cleanup has completed.
                transitionMotion.stop()
                root.transitionSerial += 1
                root.pendingIntent = null
                root._deferredRebaseSerial = -1
                // Retract any open tray submenu with the popup; otherwise it
                // stays open and greets the user stale on the next reveal.
                var tc = popupActions ? popupActions.trayMenuContent : null
                if (tc) {
                    tc.closeSubmenu()
                    tc.forgetCursor()
                }
                root.open = false
                root.closeRequested()
                clearIntentTimer.restart()
            }
        }
    }

    // Slide the stacked layers together; geometry is the only reveal channel.
    NumberAnimation {
        id: revealMotion
        target: popup
        property: "revealProgress"
        duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.settingsSidebarFade
        onFinished: {
            // Pick up any geometry deferred mid-slide so the final size
            // settles with one gentle motion after the reveal, not a bounce.
            // Flush a deferred post-exchange rebase first so B measures with
            // settled slots instead of reveal-held heights.
            if (popup.revealProgress > 0.99 && root.open) {
                if (root._deferredRebaseSerial >= 0) {
                    var serial = root._deferredRebaseSerial
                    root._deferredRebaseSerial = -1
                    root.remeasureAndRebase(serial)
                } else {
                    root.retargetGeometry(root.currentIntent)
                }
            }
        }
    }

    // Single shared progress clock for replacement glides. Displayed geometry
    // is a pure function of transitionProgress (see onTransitionProgressChanged);
    // position and size use MotionTokens.medium + Easing.OutQuint, content stays
    // fully opaque, exchange fires at exchangeThreshold.
    NumberAnimation {
        id: transitionMotion
        target: root
        property: "transitionProgress"
        from: 0
        to: 1
        duration: MotionTokens.reducedMotion ? 0 : MotionTokens.medium
        easing.type: Easing.OutQuint
    }

    onTransitionProgressChanged: root.handleTransitionProgress()

    // Dedicated content slide clock: slow enough to read as a deliberate
    // stagger after the shell glide; reduced motion settles instantly.
    NumberAnimation {
        id: contentSlideMotion
        target: root
        property: "contentSlideProgress"
        from: 0
        to: 1
        duration: MotionTokens.reducedMotion ? 0 : MotionTokens.slow
        easing.type: Easing.OutCubic
        onFinished: root.settleContentSlide()
    }

    // Clear the intent only after the exit reveal has finished so the
    // fading layers remain intact during the staggered fade.
    Timer {
        id: clearIntentTimer
        interval: popup.revealDuration + 40
        onTriggered: {
            if (!root.open) {
                root.invalidateContentTransition()
                root.intent = null
                root.currentIntent = null
                root.surfaceActive = false
            }
        }
    }

    // Let current-intent bindings settle before starting the reveal. Without
    // this one event-loop turn, the first frame can use the menu's fallback
    // height and reveal only part of the measured content.
    // For tray menus the DBus fetch is async; hold the reveal briefly so
    // the first frame already contains rows and the content layer does not
    // pop in mid-slide.
    Timer {
        id: revealStartTimer
        interval: 16
        repeat: false
        property int trayAttempts: 0
        property int trayStableTicks: 0
        property int trayLastCount: -1
        property real trayLastHeight: -1
        function resetTrayWait() {
            trayAttempts = 0
            trayStableTicks = 0
            trayLastCount = -1
            trayLastHeight = -1
        }
        onTriggered: {
            if (root.open && root.surfaceActive) {
                var trayContent = popupActions.trayMenuContent
                var isTray = root.currentIntent && root.currentIntent.actionKind === "tray" && trayContent
                if (isTray) {
                    // Long DBus menus (clash-verge/fcitx) arrive in batches:
                    // liveCount climbs 0→N→M while delegates measure. Starting
                    // at the first batch makes later batches jump mid-slide,
                    // so wait until count AND column height are stable.
                    var loading = trayContent.menuLoading || trayContent.resolvedMenuHandle == null
                    var count = Number(trayContent.liveCount)
                    var colH = Math.round(Number(trayContent.rawColumnHeight))
                    if (!loading && count > 0 && count === trayLastCount && colH === Math.round(trayLastHeight)) {
                        trayStableTicks++
                    } else {
                        trayStableTicks = 0
                        trayLastCount = (!loading && count > 0) ? count : trayLastCount
                        trayLastHeight = (!loading && count > 0) ? colH : trayLastHeight
                        // Fresh handle/count resets the baseline without counting
                        // this tick as stable.
                        if (loading || count <= 0) {
                            trayLastCount = -1
                            trayLastHeight = -1
                        }
                    }
                    var settled = !loading && count > 0 && trayStableTicks >= 4
                    if (!settled && trayAttempts < 60) {
                        trayAttempts++
                        restart()
                        return
                    }
                }
                var coldWaitedMs = revealStartTimer.trayAttempts * 16
                revealStartTimer.resetTrayWait()
                root.updateTargetGeometry(root.currentIntent, true)
                root.revealDistance = Math.max(root.targetHeight, root.displayHeight, 1)
                // TEMP-PROBE [DEBUG-cold1]: coldWaitedMs added to the log.
                root.debugLog("reveal-start", { "h": Math.round(root.targetHeight),
                    "progress": Number(popup.revealProgress),
                    "kind": root.currentIntent ? String(root.currentIntent.actionKind || "") : "",
                    "coldWaitedMs": coldWaitedMs })
                root.startReveal(1)
            }
        }
    }

    // Keep popupHovered in sync via non-blocking observation; widgetHovered
    // is driven by the external owner (BarContent/widget HoverHandler).
    onOpenChanged: {
        // Reveal is re-driven by the open state; visibility itself stays on
        // the surfaceActive binding so parents and children never read each
        // other's effective visibility (which deadlocks at false).
        if (open) {
            // A revive interrupts the exit reveal: keep the current reveal
            // position and slide it back open so geometry, height and content
            // keep their continuous transition instead of snapping.
            var revived = root._reviving
            root._reviving = false
            if (revived) {
                revealStartTimer.stop()
                root.startReveal(1)
                return
            }
            // Fresh opens always slide from the start. Without this snap a
            // reopen after cleanup resumes mid-travel and the content appears
            // instantly at partial height.
            root.debugLog("reveal-snap", { "progressBefore": Number(popup.revealProgress) })
            revealMotion.stop()
            popup.revealProgress = 0
            revealStartTimer.resetTrayWait()
            if (MotionTokens.reducedMotion) {
                revealStartTimer.stop()
                root.updateTargetGeometry(root.currentIntent, true)
                root.revealDistance = Math.max(root.targetHeight, root.displayHeight, 1)
                root.startReveal(1)
            } else {
                revealStartTimer.restart()
            }
        } else {
            revealStartTimer.stop()
            root.debugLog("reveal-exit-start", { "progress": Number(popup.revealProgress) })
            // Expand the exit travel only when the popup is fully revealed
            // (progress ~1) so the offset change is invisible (Y=0 at 1).
            // Mid-reveal closes keep the current distance to avoid a backward jump.
            if (popup.revealProgress > 0.99) {
                root.revealDistance = Math.max(root.targetHeight, root.displayHeight, root.revealDistance, 1)
            }
            root.startReveal(0)
        }
    }

    // Release the flip once the container glides home after the submenu
    // closes; the shift binding keeps the primary static until then.
    onDisplayXChanged: {
        if (root.submenuFlipped && Math.abs(root.displayX - root.flipBaseX) < 1) {
            var tc = popupActions ? popupActions.trayMenuContent : null
            if (tc && Number(tc.extraWidth) > 0)
                return
            root.submenuFlipped = false
            if (tc) tc.submenuFlipped = false
        }
    }

    // Public geometry owner keeps screen-relative coordinates stable for
    // diagnostics and callers; the visual owner below is clipped separately.
    Item {
        id: popupGeometry
        objectName: "popupGeometry"
        x: root.displayX
        y: root.displayY
        width: root.displayWidth
        height: root.displayHeight
    }

    // Fixed outer host; the viewport ends at the bar edge so the translucent
    // bar surface cannot reveal the popup while it retracts underneath it.
    Item {
        id: popupViewport
        objectName: "popupViewport"
        x: 0
        y: root.direction === "down"
                ? root.activeBarHeight + root.activeFloatingMargin : 0
        width: root.activeScreenWidth
        height: root.direction === "down"
                ? root.activeScreenHeight - root.activeBarHeight - root.activeFloatingMargin
                : root.activeScreenHeight - root.activeBarHeight - root.activeFloatingMargin
        clip: true

        // Position the rendered popup inside the bar-edge clipping viewport.
        Item {
            id: popupContainer
            objectName: "popupContainer"
            width: root.displayWidth
            height: root.revealViewportHeight
            x: root.displayX
            y: root.displayY - popupViewport.y

            // Non-blocking hover bridge on the popup surface.
            HoverHandler {
                id: popupHoverHandler
                blocking: false
                onHoveredChanged: root.popupHovered = hovered
            }

            // Flip compensation: both layers glide right by the container's
            // leftward expansion delta, so the primary column is pixel-static
            // on screen for the whole flip engage/settle cycle.
            Binding { target: popup.sidebarLayer; property: "x"; value: root.contentShiftX }
            Binding { target: popup.contentLayer; property: "x"; value: root.contentShiftX }

            // Two-layer surface; vertical orientation with direction driven by
            // the bar position (top -> Down, bottom -> Up).
            TwoLayerPopup {
                id: popup
                orientation: TwoLayerPopup.Orientation.Vertical
                clipVertical: false
                direction: root.direction === "up" ? TwoLayerPopup.Direction.Up : TwoLayerPopup.Direction.Down
                opening: root.open
                width: popupContainer.width
                height: popupContainer.height
                revealProgress: 0
                // Content and identity slide together from frame one. The old
                // 200ms contentDelay held the content layer behind the bar for
                // the first ~1/3 of travel, so it popped in around 3/4.
                contentDelay: 0
                animateLayerOpacity: false
                sidebarOffset: root.identityOffset
                contentOffset: root.slideOffset
                // Single source of truth: the reveal lives while the surface is
                // active, covering both the open state and the exit slide window.
                visible: root.surfaceActive

                // Identity layer bound to the current intent; updates in place when
                // the hovered tray delegate changes so no overlapping windows appear.
                // Persistent context menus expose the header close affordance.
                sidebarData: Item {
                    objectName: "popupIdentityTransition"
                    width: 260
                    implicitWidth: 260
                    height: 48
                    implicitHeight: 48
                    clip: true

                    // Incoming identity enters from the right and settles in
                    // the same slot as the outgoing header.
                    BarPopupIdentity {
                        objectName: "popupIdentity"
                        z: 1
                        foregroundOpacity: root._exchangeCommitted ? root.contentSlideProgress : 1
                        x: root._exchangeCommitted
                                ? root.contentSlideSign * root._contentSlideDistance * (1 - root.contentSlideProgress) : 0
                        title: root.currentIntent ? (root.currentIntent.title || "") : ""
                        iconSource: root.currentIntent ? (root.currentIntent.iconSource || "") : ""
                        tintIcon: root.currentIntent ? root.currentIntent.tintIcon === true : false
                        summary: root.currentIntent ? (root.currentIntent.summary || "") : ""
                        hostWidth: 260
                        showClose: root.currentIntent ? String(root.currentIntent.kind || "") === "context" : false
                        onCloseRequested: root.requestAnimatedClose()
                    }

                    // Outgoing identity leaves to the left during replacement.
                    BarPopupIdentity {
                        objectName: "popupIdentityOutgoing"
                        z: 0
                        foregroundOpacity: root._exchangeCommitted ? 1 - root.contentSlideProgress : 1
                        visible: root._transitionOutgoingIntent !== null
                        x: root._exchangeCommitted
                                ? -root.contentSlideSign * root._contentSlideDistance * root.contentSlideProgress : 0
                        title: root._transitionOutgoingIntent ? (root._transitionOutgoingIntent.title || "") : ""
                        iconSource: root._transitionOutgoingIntent ? (root._transitionOutgoingIntent.iconSource || "") : ""
                        tintIcon: root._transitionOutgoingIntent ? root._transitionOutgoingIntent.tintIcon === true : false
                        summary: root._transitionOutgoingIntent ? (root._transitionOutgoingIntent.summary || "") : ""
                        hostWidth: 260
                        showClose: false
                    }
                }

                // Keep both menu bodies in one content host so only the active
                // intent contributes to the popup height and visible surface.
                contentData: Item {
                     objectName: "popupContentSlot"
                     width: 260
                     implicitWidth: 260
                     implicitHeight: root.popupHeightForIntent(root.currentIntent)
                     height: implicitHeight
                     // Visible height channel: animate toward the new content's
                     // natural height so the exchange grows/shrinks smoothly
                     // instead of snapping while the slide travels.
                     Behavior on height {
                         enabled: root._exchangeCommitted && !MotionTokens.reducedMotion
                         NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutCubic }
                     }
                     clip: true
                     enabled: root.contentInteractive
                     onImplicitHeightChanged: root.updateTargetGeometry(root.currentIntent)

                    // Settings section-block surface under the action rows; the
                    // darker cards float on it exactly like the settings panel.
                    Rectangle {
                        objectName: "popupContentSurface"
                        x: 0
                        y: root.direction === "down" ? -1 : 0
                        width: parent.width
                        height: parent.height + 1
                        color: LazerTheme.settingsSection
                    }

                    // Action layer bound to the hovered widget intent.
                     // Incoming body enters from the right with the header.
                     BarPopupActions {
                         id: popupActions
                         objectName: "popupActions"
                         z: 1
                         opacity: root._exchangeCommitted ? root.contentSlideProgress : 1
                         x: root._exchangeCommitted
                                 ? root.contentSlideSign * root._contentSlideDistance * (1 - root.contentSlideProgress) : 0
                         width: parent.width
                         height: implicitHeight
                         actionKind: root.currentIntent && root.currentIntent.kind !== "context"
                                 ? (root.currentIntent.actionKind || "") : "context"
                         payload: root.currentIntent ? root.currentIntent.payload : null
                         onDismissRequested: root.dismissImmediately()
                     }

                     // Outgoing body leaves to the left while its replacement
                     // is measured and morphs the host width/height.
                     BarPopupActions {
                         objectName: "popupActionsOutgoing"
                         z: 0
                         opacity: root._exchangeCommitted ? 1 - root.contentSlideProgress : 1
                         visible: root._transitionOutgoingIntent !== null
                         enabled: false
                         x: root._exchangeCommitted
                                 ? -root.contentSlideSign * root._contentSlideDistance * root.contentSlideProgress : 0
                         width: parent.width
                         height: implicitHeight
                         actionKind: root._transitionOutgoingIntent
                                 && root._transitionOutgoingIntent.kind !== "context"
                                 ? (root._transitionOutgoingIntent.actionKind || "") : "context"
                         payload: root._transitionOutgoingIntent
                                 ? root._transitionOutgoingIntent.payload : null
                     }

                    // Retarget the layer-shell mask when a tray submenu grows or retracts.
                    Connections {
                        target: popupActions.trayMenuContent
                        function onExtraWidthChanged() {
                            root.updateTargetGeometry(root.currentIntent)
                        }
                        function onSubmenuProgressChanged() {
                            root.updateTargetGeometry(root.currentIntent)
                        }
                    }

                    // Context actions reuse the same content owner and geometry.
                     // Incoming context body follows the same right-to-left
                     // content track as ordinary popup actions.
                     BarContextPopupActions {
                         id: contextPopupActions
                         objectName: "contextPopupActions"
                         z: 1
                         opacity: root._exchangeCommitted ? root.contentSlideProgress : 1
                         x: root._exchangeCommitted
                                 ? root.contentSlideSign * root._contentSlideDistance * (1 - root.contentSlideProgress) : 0
                         width: parent.width
                         height: implicitHeight
                        actionKind: root.currentIntent && root.currentIntent.kind === "context" ? "context" : ""
                        widgetId: root.currentIntent ? (root.currentIntent.widgetId || "") : ""
                        instanceKey: root.currentIntent ? (root.currentIntent.instanceKey || "") : ""
                        section: root.currentIntent ? (root.currentIntent.section || "center") : "center"
                        hasSettings: root.currentIntent ? root.currentIntent.hasSettings === true : false
                        layoutMode: root.currentIntent ? root.currentIntent.layoutMode === true : false
                        availableWidgets: root.currentIntent ? (root.currentIntent.availableWidgets || []) : []
                        payload: root.currentIntent ? root.currentIntent.payload : null
                        onActionRequested: action => {
                            if (action === "close" || action === "toggleLayoutMode")
                                root.requestAnimatedClose()
                         }
                     }

                     // Outgoing context actions remain mounted until the
                     // shared transition reaches its settled state.
                     BarContextPopupActions {
                         objectName: "contextPopupActionsOutgoing"
                         z: 0
                         opacity: root._exchangeCommitted ? 1 - root.contentSlideProgress : 1
                         visible: root._transitionOutgoingIntent !== null
                         enabled: false
                         x: root._exchangeCommitted
                                 ? -root.contentSlideSign * root._contentSlideDistance * root.contentSlideProgress : 0
                         width: parent.width
                         height: implicitHeight
                         actionKind: root._transitionOutgoingIntent
                                 && root._transitionOutgoingIntent.kind === "context" ? "context" : ""
                         widgetId: root._transitionOutgoingIntent
                                 ? (root._transitionOutgoingIntent.widgetId || "") : ""
                         instanceKey: root._transitionOutgoingIntent
                                 ? (root._transitionOutgoingIntent.instanceKey || "") : ""
                         section: root._transitionOutgoingIntent
                                 ? (root._transitionOutgoingIntent.section || "center") : "center"
                         hasSettings: root._transitionOutgoingIntent
                                 ? root._transitionOutgoingIntent.hasSettings === true : false
                         layoutMode: root._transitionOutgoingIntent
                                 ? root._transitionOutgoingIntent.layoutMode === true : false
                         availableWidgets: root._transitionOutgoingIntent
                                 ? (root._transitionOutgoingIntent.availableWidgets || []) : []
                         payload: root._transitionOutgoingIntent
                                 ? root._transitionOutgoingIntent.payload : null
                     }
                }
            }
        }
    }
}
