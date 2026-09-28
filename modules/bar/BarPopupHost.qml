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
    property bool widgetHoverWasSet: false
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
    // The open tray submenu is the only intentional content overflow: its
    // surface sticks out sideways past the 260-wide slot. The outgoing layer
    // only counts while its exchange is still mounted; after settle its
    // payload clears and its stale progress must not hold the clip open.
    readonly property bool traySubmenuOverflowActive: (popupActions
            && popupActions.trayMenuContent
            && Number(popupActions.trayMenuContent.submenuProgress) > 0)
        || (root._transitionOutgoingIntent !== null
            && popupActionsOutgoing
            && popupActionsOutgoing.trayMenuContent
            && Number(popupActionsOutgoing.trayMenuContent.submenuProgress) > 0)

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
    // Push the debug switch into the tray content so its hover exits are traced
    // on the same switch. A singleton write from here, not a separate owner.
    onDebugEnabledChanged: {
        var tc = root._trayContent()
        if (tc)
            tc.debugLeave = root.debugEnabled
    }
    property string _lastDebugSignature: ""
    // Set by every hover-exit path, with the pointer's last known position in
    // region coordinates. The close decision treats "no owner has hover" as
    // "the user left", which is wrong when the compositor dropped focus while
    // the pointer sat inside the region — this is what tells the two apart.
    property string _lastLeave: "none"
    // Set once a reveal has actually run to the surface. The first open in a
    // session is the only time the content tree has not laid out when the
    // target geometry is committed, so it is the only time the input region
    // would be built from placeholder values.
    property bool _hasRevealed: false
    // The popup surface's own unfiltered pointer position, in container
    // coordinates. Survives the leave, so it records where the pointer was when
    // the surface lost it.
    property var _lastRawPoint: null
    property string _lastDeparture: "none"
    // True when the most recent tray departure was reported from inside the
    // committed input region, i.e. the pointer was still over the popup. The
    // close timer consults this; see the comment there.
    property bool _departureInsideRegion: false
    // Re-arms allowed for inside-region departures before the popup closes
    // anyway. Bounded on purpose: the pointer really can leave, and a popup that
    // refuses to close is worse than one that closes a beat early.
    property int _regionLeaveBudget: 3

    function noteLeave(source) {
        var tc = root._trayContent()
        var at = root._cursorInViewport(tc)
        var region = popupInputRegion
        var inside = at ? root._pointInRect(at.x, at.y, region) : false
        root._lastLeave = source + (at ? (" at " + at.x + "," + at.y
            + (inside ? " INSIDE" : " outside")) : " at none")
        root.debugLog("leave", { "source": root._lastLeave,
            "region": root._debugRect(region), "regionActive": root.surfaceActive,
            "widgetHovered": root.widgetHovered, "popupHovered": root.popupHovered })
    }

    function _debugRect(item) {
        if (!item)
            return { "x": 0, "y": 0, "width": 0, "height": 0 }
        return {
            "x": Math.round(Number(item.x) * 10) / 10, "y": Math.round(Number(item.y) * 10) / 10,
            "width": Math.max(0, Math.round(Number(item.width) * 10) / 10),
            "height": Math.max(0, Math.round(Number(item.height) * 10) / 10),
        }
    }

    function _pointInRect(px, py, rect) {
        if (px < 0 || !rect)
            return false
        return px >= rect.x && px <= rect.x + rect.width
            && py >= rect.y && py <= rect.y + rect.height
    }
    // Where the tray's remembered pointer sits inside the viewport the input
    // region is expressed in. Mapped through the live scene graph rather than
    // compared numerically: the memory is in tray-content coordinates, the
    // region in viewport coordinates, and the two differ by the container's
    // anchored position. Returns null when there is no memory at all, so
    // "no pointer" never reads as "pointer outside".
    function _cursorInViewport(tc) {
        if (!tc || Number(tc.lastCursorX) < 0)
            return null
        var p = tc.mapToItem(popupViewport, Number(tc.lastCursorX), Number(tc.lastCursorY))
        return { "x": Math.round(p.x * 10) / 10, "y": Math.round(p.y * 10) / 10 }
    }
    function _pointInRegion(tc) {
        var p = root._cursorInViewport(tc)
        return p ? root._pointInRect(p.x, p.y, popupInputRegion) : false
    }
    // Same rule for a rect: the inner item lives in its own parent's space, so
    // its corners are mapped up before they are compared. Comparing raw
    // geometry across spaces reports "outside" for everything anchored away
    // from the origin, which is how this block first claimed the submenu column
    // fell outside the region.
    function _rectInside(inner, outer) {
        if (!inner || !outer || !inner.mapToItem)
            return false
        var a = inner.mapToItem(popupViewport, 0, 0)
        var b = inner.mapToItem(popupViewport, inner.width, inner.height)
        return root._pointInRect(a.x, a.y, outer) && root._pointInRect(b.x, b.y, outer)
    }

    // Tray submenu internals: phase/geometry/highlight of the second level.
    // The host snapshot only sees the two layers, so the failure modes that
    // live inside the tray menu (cold fetch, anchor clamp, hover memory) are
    // invisible without this block.
    function _trayDebug() {
        var tc = root._trayContent()
        if (!tc)
            return null
        var anchorY = Number(tc.submenuAnchorBottomY)
        var view = tc.submenuViewport
        return {
            "phase": String(tc.submenuPhase || ""),
            "progress": Math.round(Number(tc.submenuProgress) * 1000) / 1000,
            "interactable": tc.submenuInteractable === true,
            "content": tc.hasSubmenuContent === true,
            "liveCount": Number(tc.liveCount),
            "rawCol": Math.round(Number(tc.rawColumnHeight)),
            "held": Math.round(Number(tc.heldHeight)),
            "flickH": Math.round(Number(tc.submenuAvailHeight) + anchorY),
            "anchorY": Math.round(anchorY),
            "avail": Math.round(Number(tc.submenuAvailHeight)),
            "body": Math.round(Number(tc.submenuBodyFull)),
            "surface": root._debugRect(tc.submenuSurface),
            "surfaceVisible": tc.submenuSurface.visible === true,
            "column": root._debugRect(tc.submenuColumn),
            "viewH": view ? Math.round(Number(view.height)) : -1,
            "viewContentH": view ? Math.round(Number(view.contentHeight)) : -1,
            "viewY": view ? Math.round(Number(view.y)) : -1,
            "viewInteractive": view ? view.interactive === true : false,
            "contentInteractive": root.contentInteractive,
            "cursorX": Math.round(Number(tc.lastCursorX)),
            "cursorY": Math.round(Number(tc.lastCursorY)),
            "highlightSub": tc.highlightedSubmenuRow ? 1 : 0,
            "highlightRow": tc.highlightedRow ? 1 : 0,
        }
    }

    // The tray handle, resolved here because both debug blocks need it and it
    // is not a property of the root.
    // Which surface is entitled to the pixel the pointer was last seen on. The
    // notification host publishes its own claimed rect, so this needs no
    // reference into a surface the popup does not own.
    // Window-space rect of an item — the space wl_surface.set_input_region is
    // expressed in. Everything else in this snapshot is viewport-local.
    // NOTE: `mapToScene` does not exist in QML (C++ only), which silently made
    // this return null; `mapToItem(null, ...)` is the QML spelling of the same
    // mapping and resolves to the window's content item.
    function _sceneRect(item) {
        if (!item || !item.mapToItem)
            return null
        var a = item.mapToItem(null, 0, 0)
        var b = item.mapToItem(null, item.width, item.height)
        return {
            "x": Math.round(a.x * 10) / 10, "y": Math.round(a.y * 10) / 10,
            "width": Math.round((b.x - a.x) * 10) / 10,
            "height": Math.round((b.y - a.y) * 10) / 10,
        }
    }
    function _cursorInScene(tc) {
        if (!tc || Number(tc.lastCursorX) < 0)
            return null
        var p = tc.mapToItem(null, Number(tc.lastCursorX), Number(tc.lastCursorY))
        return { "x": Math.round(p.x * 10) / 10, "y": Math.round(p.y * 10) / 10 }
    }
    function _sceneCovers(tc) {
        var p = root._cursorInScene(tc)
        var r = root._sceneRect(popupInputRegion)
        if (!p || !r)
            return false
        return root._pointInRect(p.x, p.y, r)
    }

    function _thiefAt(p) {
        if (!p)
            return "none"
        if (PopupInputArbitration.coversPoint(p.x, p.y))
            return "notifications"
        return root._pointInRect(p.x, p.y, popupInputRegion) ? "popup" : "none"
    }

    function _trayContent() {
        return popupActions ? popupActions.trayMenuContent : null
    }

    // The tray content is swapped when the popup changes intent, so the debug
    // switch is re-pushed whenever that happens rather than relying on the
    // switch changing again.
    function _syncTrayDebug() {
        var tc = root._trayContent()
        if (!tc)
            return
        if (tc.debugLeave !== root.debugEnabled)
            tc.debugLeave = root.debugEnabled
        if (tc.debugEvents !== root.debugEnabled)
            tc.debugEvents = root.debugEnabled
        // The tray reports a departure with the position it still remembers, so
        // the host can judge the exit against the input region instead of
        // guessing from a memory it may already have lost.
        if (!tc.departuresWired) {
            tc.departuresWired = true
            tc.pointerDeparted.connect(function(x, y, source) {
                root.onTrayPointerDeparted(x, y, source)
            })
        }
    }

    // Region-relative judgement of a tray departure. This is the measurement
    // that was missing: the surface losing hover while the pointer is inside
    // the region is a compositor-side leave, and closing on it is what makes
    // the first expand unusable.
    function onTrayPointerDeparted(x, y, source) {
        var tc = root._trayContent()
        if (!tc || !isFinite(Number(x)) || !isFinite(Number(y))) {
            root._lastDeparture = String(source) + " at none"
            root._departureInsideRegion = false
            return
        }
        // No "x < 0 means no pointer" test here: the tray content slides in from
        // the right, so a real pointer can sit at a negative x in its own
        // coordinates. The tray emits only when it truly has a position.
        var p = popupViewport.mapFromItem(tc, Number(x), Number(y))
        var inside = root._pointInRect(p.x, p.y, popupInputRegion)
        root._lastDeparture = String(source) + " at " + Math.round(p.x * 10) / 10 + ","
            + Math.round(p.y * 10) / 10 + (inside ? " INSIDE" : " outside")
        root._departureInsideRegion = inside
        root.debugLog("depart", { "source": root._lastDeparture,
            "region": root._debugRect(popupInputRegion), "regionActive": root.surfaceActive,
            "widgetHovered": root.widgetHovered, "popupHovered": root.popupHovered })
    }

    function debugSnapshot() {
        root._syncTrayDebug()
        var tc = root._trayContent()
        return {
            "tray": root._trayDebug(),
            "input": {
                // The layer-shell mask is the only thing that decides whether the
                // compositor routes pointer events into this surface at all, so a
                // silent "no hover, no click" with healthy local state is
                // indistinguishable from a region that does not cover the point.
                "region": root._debugRect(popupInputRegion),
                "regionActive": root.surfaceActive,
                // Both must land inside the region for the submenu column to be
                // reachable: the pointer Qt last saw, and where the column band
                // actually is. Anything outside means the compositor, not the
                // tray content, dropped the event. The tray cursor memory lives
                // in tray-content coordinates, so it is mapped up into the
                // viewport the region is expressed in.
                "cursorInRegion": root._pointInRegion(tc),
                // The remembered pointer in the region's own space, so a lost
                // pointer can be located against the region without doing the
                // mapping by hand. null means "no pointer was ever seen here".
                "cursorAt": root._cursorInViewport(tc),
                "columnInRegion": root._rectInside(tc ? tc.submenuColumn : null,
                    popupInputRegion),
                // Which owner most recently reported the pointer gone. A close
                // with every hover owner false and the pointer still inside the
                // region means the compositor dropped focus, not the user.
                "lastLeave": String(root._lastLeave),
                // The tray's own departure, judged against the region. INSIDE
                // here means the pointer was demonstrably over us when the exit
                // fired, so treating it as the user leaving is what closes the
                // popup under the cursor.
                "lastDepart": String(root._lastDeparture),
                // The rival claim on the same pixels. The popup and the
                // notification host are both Top-layer surfaces and the client
                // cannot order them; the notification host maps later, so a
                // visible card sits above the popup. Recording its region turns
                // "the pointer was stolen" from an assumption into a check: if a
                // departure lands inside notifRegion, that is the thief.
                "notifRegion": {
                    "x": PopupInputArbitration.notifX,
                    "y": PopupInputArbitration.notifY,
                    "width": PopupInputArbitration.notifWidth,
                    "height": PopupInputArbitration.notifHeight,
                },
                "notifClaimsInput": Number(PopupInputArbitration.notifHeight) > 0,
                "pointerStolenBy": root._thiefAt(root._cursorInViewport(
                    root._trayContent())),
                // Unfiltered pointer, plus the per-owner event tally. The owner
                // that stopped speaking is the link where delivery broke.
                "rawPoint": root._lastRawPoint,
                // The region as the COMPOSITOR sees it. Region.item builds the
                // wl_surface input region from mapToScene, i.e. window
                // coordinates — NOT the viewport-local rect every other field
                // here reports. Comparing a viewport-local cursor against a
                // viewport-local rect can only ever agree, so "the region covers
                // the pointer" was never actually being tested. Both sides are
                // mapped to the window here, which is the only comparison that
                // means anything.
                "regionScene": root._sceneRect(popupInputRegion),
                "cursorScene": root._cursorInScene(root._trayContent()),
                "cursorInRegionScene": root._sceneCovers(root._trayContent()),
                "evPrimary": tc ? Number(tc._evPrimary) : -1,
                "evBand": tc ? Number(tc._evBand) : -1,
                "evPanel": tc ? Number(tc._evPanel) : -1,
                "firstPrimary": String(tc ? tc._evFirstPrimary : "none"),
                "firstBand": String(tc ? tc._evFirstBand : "none"),
                "firstPanel": String(tc ? tc._evFirstPanel : "none"),
            },
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
        // Build the payload OUTSIDE the guard: a ReferenceError or bad property
        // read inside debugSnapshot() must not take the whole diagnostic stream
        // down with it, because a silent stream looks exactly like "nothing
        // happened" — the failure this channel exists to disprove.
        var signature
        try {
            signature = JSON.stringify(entry)
        } catch (e) {
            signature = "{\"event\":\"" + event + "\",\"payloadError\":true}"
        }
        if (signature === root._lastDebugSignature)
            return
        root._lastDebugSignature = signature
        console.log("[afloat:PopupDebug]", signature)
        // Mirror to the settings cache: the popup half of the hover diagnostics
        // is otherwise only readable from the shell's stdout.
        Services.SettingsService.recordHoverSnapshot(signature)
    }

    function emitDebugSnapshot() {
        var snap
        try {
            snap = root.debugSnapshot()
        } catch (e) {
            // Report the failure instead of going quiet: an empty timeline is
            // indistinguishable from a healthy one where nothing changed.
            snap = { "error": "snapshot failed", "detail": String(e) }
        }
        root.debugLog("snapshot", snap)
    }

    // Poll only while diagnostics are enabled so no extra owner or timer runs live.
    Timer {
        id: debugPoll
        interval: 120
        repeat: true
        running: root.debugEnabled
        onTriggered: root.emitDebugSnapshot()
    }

    onPopupHoveredChanged: {
        if (popupHoverWasActive && !popupHovered) {
            root.noteLeave("popup-surface")
            requestClose()
        } else if (popupHovered) {
            // The pointer is demonstrably back on the popup, so any deferred
            // close was a hand-off artefact and the debt is settled.
            root._regionLeaveBudget = 3
            root._departureInsideRegion = false
        }
        popupHoverWasActive = popupHovered
    }

    onWidgetHoveredChanged: {
        if (root.widgetHoverWasSet && !root.widgetHovered && !root.popupHovered)
            root.noteLeave("widget")
        root.widgetHoverWasSet = true
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
            // First reveal after the surface has been torn down, or the very
            // first one in a session: nothing has laid out yet, so targetY and
            // targetHeight are still the property defaults (0 and 1). The
            // surface maps against the input region built from them — a 260x50
            // strip at the top-left of the screen, nowhere near the popup — and
            // the pointer is gone before revealStartTimer corrects the target
            // up to 960ms later. That is the whole of "only the first time":
            // on every later open the content has already laid out and the
            // region is correct at map time. Home the display onto the target
            // before mapping, so the region is meaningful from the first frame.
            if (isExiting || !root._hasRevealed)
                root.rebaseGlide()
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

    // Popup width follows the intent: media carries a wide card (cover +
    // identity + spectrum), everything else stays at the classic 260.
    function popupWidthForIntent(intentObj) {
        if (!intentObj || String(intentObj.kind || "") === "context")
            return 260
        return String(intentObj.actionKind || "") === "media" ? 420 : 260
    }

    // Slot width fits both sliding layers during an exchange so the
    // outgoing body is never squeezed before it leaves.
    readonly property real incomingPopupWidth: popupWidthForIntent(root.currentIntent)
    readonly property real outgoingPopupWidth: popupWidthForIntent(root._transitionOutgoingIntent)
    readonly property real popupSlotWidth: Math.max(root.incomingPopupWidth, root.outgoingPopupWidth)

    function popupHeightForIntent(intentObj) {        if (!intentObj)
            return 1
        // Track live height even while the two-layer reveal is in flight:
        // holding a stale height here defers the correction until after
        // full expansion, which reads as a second jump once already open.
        // Late arrivals glide concurrently via rebaseGlide in
        // retargetGeometry, so no post-reveal motion remains.
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
        // Late arrivals during the reveal rebase instead of waiting for
        // settle: on a settled glide this snaps display to the new target
        // (nothing else is travelling), on a running glide it keeps the
        // current progress so the remaining curve covers the corrected
        // distance without a bounce. Either way the shell has settled by
        // the time the reveal completes, instead of starting a second
        // motion after full expansion.
        if (!immediate && !MotionTokens.reducedMotion
                && popup.revealProgress > 0.01 && popup.revealProgress < 0.99
                && !root.pendingIntent && root.transitionProgress >= 0.999) {
            root.rebaseGlide()
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

    // Click-driven dismiss (tray row activation, …): same cleanup the close
    // timer performs, but starting on the click frame instead of after the
    // hover grace. The exit reveal and any open tray submenu retract stay
    // visible together; intents are retained until clearIntentTimer so a
    // same-frame revive still wins over the exit.
    function dismissAnimated() {
        closeTimer.stop()
        transitionMotion.stop()
        root.transitionSerial += 1
        root.pendingIntent = null
        root._deferredRebaseSerial = -1
        var tc = popupActions ? popupActions.trayMenuContent : null
        if (tc) {
            tc.closeSubmenu()
            tc.forgetCursor()
        }
        root.open = false
        root.closeRequested()
        clearIntentTimer.restart()
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
    // The region follows the union of the displayed container and its committed
    // target: driven by the animated width alone it lagged the summon, leaving
    // the second level painted outside it. The union also keeps the region wide
    // until a retract glide has actually finished.
    //
    // Note: do NOT offer a "whole surface" mask as a diagnostic. The close rule
    // needs the *widget* hover, and a full-screen mask keeps the popup above the
    // bar permanently, so widgetHovered can never return and every popup dies
    // immediately — the mode breaks the shell rather than isolating the mask.
    mask: Region { item: root.surfaceActive ? popupInputRegion : null }
    // Do not keep a full-screen transparent surface above the settings window
    // when no bar popup is open or completing its reveal.
    visible: root.surfaceActive

    // Close after MotionTokens.fast if both hover owners are gone.
    Timer {
        id: closeTimer
        interval: MotionTokens.fast
        onTriggered: {
            if (!BarHoverLogic.shouldClose(root.widgetHovered, root.popupHovered, true))
                return
            // "No owner holds hover" is not the same as "the pointer left".
            // Measured on the desktop: crossing the primary's right edge into
            // the submenu column produced a leave at 1366.9,113.5 — inside the
            // committed input region, with the pointer demonstrably still over
            // the popup. Closing on that is what made the first expand dead:
            // no highlight, no click, popup gone. So a leave whose last known
            // position is still inside the region is treated as the pointer
            // being handed off, and re-arms the close instead of closing.
            // Bounded, so a genuinely departed pointer still closes promptly.
            if (root._departureInsideRegion && root._regionLeaveBudget > 0) {
                root._regionLeaveBudget -= 1
                root.debugLog("closeDeferred", {
                    "departure": String(root._lastDeparture),
                    "budget": root._regionLeaveBudget,
                })
                closeTimer.restart()
                return
            }
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
        if (!open)
            root._hasRevealed = false
        else
            root._hasRevealed = true
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

        // Input-region owner for the layer-shell mask.
        //
        // Driven by the COMMITTED target geometry only, never by the animating
        // container. That distinction is the whole point: every geometry change
        // of a Region's item re-commits wl_surface.set_input_region, and the
        // compositor re-evaluates pointer focus on each one. The container
        // width glides 260→512 across the submenu flight, so an
        // animation-following mask re-committed the region ~30 times per open,
        // and each commit could hand the pointer away mid-flight. A leave is
        // not self-healing: the pointer only comes back on physical motion, so
        // a user who parks the cursor on the arriving panel sees no highlight
        // and no click until they wiggle the mouse.
        //
        // target* is committed synchronously when the submenu is summoned
        // (computeAndCommitTargets reacts to extraWidth), so the region already
        // covers the second level on the first frame of the summon and then
        // holds still for the whole 500ms flight.
        Item {
            id: popupInputRegion
            objectName: "popupInputRegion"
            x: root.targetX
            y: root.targetY - popupViewport.y
            width: root.targetWidth
            height: root.targetHeight
        }

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
                onHoveredChanged: {
                    root.popupHovered = hovered
                    // The compositor's own view of the pointer, before any
                    // MouseArea filtering. When the panel is visibly under the
                    // cursor but nothing on it reacts, this is the only source
                    // that says whether the pointer is still ours at all — and
                    // its last known position on the way out is where delivery
                    // actually stopped.
                    if (!hovered && root.debugEnabled)
                        root.debugLog("popupPointerGone", {
                            "lastRaw": root._lastRawPoint,
                            "region": root._debugRect(popupInputRegion),
                        })
                }
                onPointChanged: function(point) {
                    root._lastRawPoint = {
                        "x": Math.round(point.position.x * 10) / 10,
                        "y": Math.round(point.position.y * 10) / 10,
                    }
                }
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
                    width: root.popupSlotWidth
                    implicitWidth: root.popupSlotWidth
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
                        hostWidth: root.popupSlotWidth
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
                        hostWidth: root.popupSlotWidth
                        showClose: false
                    }
                }

                // Keep both menu bodies in one content host so only the active
                // intent contributes to the popup height and visible surface.
                contentData: Item {
                     objectName: "popupContentSlot"
                     width: root.popupSlotWidth
                     implicitWidth: root.popupSlotWidth
                     implicitHeight: root.popupHeightForIntent(root.currentIntent)
                     height: implicitHeight
                     // Visible height channel: animate toward the new content's
                     // natural height so the exchange grows/shrinks smoothly
                     // instead of snapping while the slide travels.
                     Behavior on height {
                         enabled: root._exchangeCommitted && !MotionTokens.reducedMotion
                         NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutCubic }
                     }
                    // Keep hover replacement layers inside the content column;
                    // an open tray submenu is the only intentional overflow.
                    // While an exchange is mounted both bodies slide
                    // horizontally, so force the clip even with a submenu open:
                    // otherwise the sliding layers paint past the slot edge.
                    clip: root._transitionOutgoingIntent !== null || !root.traySubmenuOverflowActive
                     enabled: root.contentInteractive
                     onImplicitHeightChanged: root.updateTargetGeometry(root.currentIntent)
                     onImplicitWidthChanged: root.updateTargetGeometry(root.currentIntent)

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
                         onDismissRequested: root.dismissAnimated()
                     }

                      // Outgoing body leaves to the left while its replacement
                      // is measured and morphs the host width/height.
                      BarPopupActions {
                          id: popupActionsOutgoing
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
                    // extraWidth is the only channel needed: it flips 0<->panelWidth once
                    // per open, which is exactly when the mask must widen. Retargeting on
                    // submenuProgress instead restarted the geometry glide on every frame of
                    // the slide, pinning displayWidth at its old value until the animation
                    // ended: the panel was painted outside the input region the whole time,
                    // so hover and taps stayed dead until the mask caught up afterwards.
                    Connections {
                        target: popupActions.trayMenuContent
                        function onExtraWidthChanged() {
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
