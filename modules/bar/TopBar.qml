import QtQuick
import Quickshell
import Quickshell.Wayland
import "../lazerbar"
import "../lazerbar/ScreenCornerMask.js" as CornerMask
import "./FullscreenBarLogic.js" as RevealLogic
import "./WindowHintMenuLogic.js" as HintMenu
import "../../services" as Services

// Mount the layout-driven bar plus the launcher wave owner per screen.
// BarPopupHost is mounted per screen and bound to BarContent hover intents.
Variants {
    model: Quickshell.screens

    Scope {
        id: screenScope

        required property var modelData

        // Keep the theme's bar metrics tracking settings; the singleton itself
        // stays service-free so component suites run without Quickshell.
        Binding {
            target: LazerTheme
            property: "barHeightSetting"
            value: Services.SettingsService.bar.height
        }

        readonly property bool floating: Services.SettingsService.bar.floating
        readonly property int floatingMargin: floating
                ? Math.max(0, Math.min(24, Number(Services.SettingsService.bar.floatingMargin) || 0)) : 0
        readonly property int effectiveHeight:
            Math.max(40, Math.min(64, Number(Services.SettingsService.bar.height) || 48))
        readonly property bool atTop: String(Services.SettingsService.bar.position || "top") !== "bottom"
        // Output identity, for effects that must only answer on their own
        // screen (the bar's glow pulse, for one).
        readonly property string screenName: screenScope.modelData ? String(screenScope.modelData.name || "") : ""
        readonly property bool autoHideEnabled: Services.SettingsService.bar.autoHideFullscreen === true
        // Per-output: a fullscreen window on a background workspace of another
        // monitor must not collapse this screen's bar.
        readonly property bool fullscreenActive: {
            // Read the map, don't call the lookup: a binding needs a property it
            // can subscribe to, and this is the one the service reassigns.
            const verdicts = Services.NiriService.fullscreenOutputs
            const name = screenScope.modelData ? String(screenScope.modelData.name || "") : ""
            return screenScope.autoHideEnabled && !!verdicts && verdicts[name] === true
        }

        // Fullscreen auto-hide state machine. `pinned` keeps the bar on screen
        // whenever something that anchors below it is open, so a popup or the
        // launcher can never render against a bar that is off-screen.
        property var _revealState: RevealLogic.initialState()
        readonly property bool revealed: _revealState.revealed
        // 0 while collapsed, 1 while shown. Drives the slide offset and the edge
        // hint only — the bar itself does not fade.
        property real revealProgress: revealed ? 1 : 0
        Behavior on revealProgress {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.slow; easing.type: Easing.OutCubic }
        }
        // Anything that draws against the bar's own geometry pins it open: an
        // open bar popup, the launcher wave and the settings panel all anchor
        // below the bar, and none of them can render against a bar that is
        // off-screen. Opening the launcher from a fullscreen window therefore
        // also brings the bar back. The mod hint is named explicitly as well as
        // covered by `popupHost.open`, so the pin holds for the whole hold
        // rather than only for the frames the popup has finished opening.
        readonly property bool _pinned: popupHost.open
                || launcherSurface.host.interactive
                || settingsOverlay.interactive
                || screenScope.windowHintHeld
        readonly property bool windowHintHeld: Services.WindowHintService.hintHeld

        // Hold-key window hint, presented as a bar popup. The service owns the
        // snapshot; this scope only translates a hold into a hover intent and
        // back, so the hint reuses the popup's reveal, surface and input
        // region instead of owning a second floating surface.
        //
        // Identity keys stay constant across refreshes on purpose: the host
        // treats a same-identity intent as a live update and leaves the popup
        // in place, so switching workspaces while mod is held updates the rows
        // without a replacement crossfade.
        function buildWindowHintIntent() {
            const hint = Services.WindowHintService.activeHint
            if (!hint)
                return null
            return {
                widgetId: "window-hint",
                instanceKey: "hint:" + (screenScope.modelData ? String(screenScope.modelData.name || "") : ""),
                kind: "hover",
                actionKind: "window-hint",
                title: HintMenu.identityTitle(hint),
                // The focused window's own icon carries the header, so the
                // identity stays true to what the menu is listing.
                iconSource: hint.currentWindowIcon || "",
                tintIcon: false,
                summary: HintMenu.identitySummary(hint),
                anchorX: barContent.hintAnchorX(),
                screenWidth: screenScope.modelData ? Number(screenScope.modelData.width) : 1920,
                screenHeight: screenScope.modelData ? Number(screenScope.modelData.height) : 1080,
                barPosition: String(Services.SettingsService.bar.position || "top"),
                effectiveBarHeight: screenScope.effectiveHeight,
                floatingMargin: screenScope.floatingMargin,
                payload: {
                    hint: hint,
                    // niri owns workspace and window activation. The route
                    // matches the workspace widget's own chips.
                    onHintWorkspace: index => Quickshell.execDetached([
                        "niri", "msg", "action", "focus-workspace", String(index)
                    ]),
                    onHintWindow: windowId => Quickshell.execDetached([
                        "niri", "msg", "action", "focus-window", "--id", String(windowId)
                    ])
                }
            }
        }

        function openWindowHint() {
            const intent = buildWindowHintIntent()
            if (!intent)
                return
            // Nothing hovers this popup, so the host's own hover owner has to
            // be latched or the close timer would retire it on the first tick.
            popupHost.widgetHovered = true
            popupHost.updateIntent(intent)
        }

        function refreshWindowHint() {
            if (!Services.WindowHintService.hintHeld)
                return
            const intent = buildWindowHintIntent()
            if (intent)
                popupHost.updateIntent(intent)
        }

        function closeWindowHint() {
            // A widget can still sit under the pointer: hand its popup back
            // rather than closing the surface, because the widget emits no new
            // hover event and would otherwise stay popup-less until the
            // pointer left and returned.
            if (barContent.reemitHoverIntent())
                return
            popupHost.widgetHovered = false
            popupHost.dismissAnimated()
        }

        // Feed one transition into the state machine. The returned state is
        // always stored; only the reveal edge effects (drop a popup, arm the
        // idle collapse) are edge-triggered, so an event that changes nothing
        // visible cannot skip a state field the next reduce needs.
        function _sendReveal(type, value, distance) {
            const wasRevealed = _revealState.revealed
            const next = RevealLogic.reduce(_revealState, {
                type: type,
                value: value,
                distance: distance
            })
            _revealState = next
            if (wasRevealed && !next.revealed) {
                // A bar popup is opened by hovering a widget, and the pointer
                // cannot be on one while the bar is off-screen.
                popupHost.dismissImmediately()
                _hideTimer.stop()
                if (type !== "leave")
                    _revealState = RevealLogic.rearmAfterCollapse(_revealState, _pointerDistance)
            } else if (next.revealed && !wasRevealed) {
                _hideTimer.restart()
            }
        }

        // Last known distance of the pointer from the bar's anchored edge, valid
        // only while the pointer is actually over the bar. Negative means "not
        // known", which rearmAfterCollapse treats as "arm".
        //
        // It must be forgotten on leave, not merely left behind: once the bar is
        // collapsed its input region is only the edge strip, so a pointer that
        // sits in the middle of the bar stops producing position events entirely.
        // A stale distance would then decide the next collapse, and the commonest
        // case — fullscreen toggled while the pointer is mid-screen — would
        // disarm the strip for a pointer that is nowhere near it.
        property real _pointerDistance: -1

        function _notePointerDistance(distance) {
            if (!isFinite(Number(distance)))
                return
            _pointerDistance = Number(distance)
            _sendReveal("move", undefined, _pointerDistance)
        }

        function _forgetPointer() {
            _pointerDistance = -1
        }

        // Collapse again after a pause, but never out from under an open popup.
        //
        // `idleHideDelay` is 0 — leaving the bar already collapses it at once.
        // A Timer cannot express that directly (interval 0 is a per-turn spin,
        // not an immediate fire), so fall back to the smallest real tick.
        Timer {
            id: _hideTimer
            interval: Math.max(RevealLogic.minTimerInterval, RevealLogic.idleHideDelay)
            onTriggered: {
                if (!screenScope.revealed || !screenScope.fullscreenActive || screenScope._pinned)
                    return
                screenScope._sendReveal("idle")
            }
        }

        // Mirror the reveal chain for out-of-process inspection. A collapse that
        // silently fails looks identical to one that never triggered, so the
        // debugFullscreenBar IPC target reads this instead of guessing.
        readonly property var _debugEntry: ({
            screenName: screenName,
            fullscreenActive: fullscreenActive,
            autoHideEnabled: autoHideEnabled,
            revealed: revealed,
            revealProgress: revealProgress,
            pinned: _pinned,
            state: _revealState
        })
        on_DebugEntryChanged: Services.BarDebugState.sync(screenName, _debugEntry)
        Component.onDestruction: Services.BarDebugState.remove(screenName)

        onFullscreenActiveChanged: _sendReveal("fullscreen", fullscreenActive)
        onAutoHideEnabledChanged: _sendReveal("enabled", autoHideEnabled)
        // Losing the pin (a popup or overlay just closed) must not strand a bar
        // that was only visible because of it: the pointer left the surface
        // while the pin held it open, so nothing else will collapse it.
        on_PinnedChanged: {
            _sendReveal("pinned", _pinned)
            if (!_pinned && screenScope.revealed && screenScope.fullscreenActive)
                _hideTimer.restart()
        }

        // Desktop-blocking mask only when the debug override demands it.
        readonly property bool settingsMaskActive:
            Services.SettingsService.settingsMaskOverride !== "off"
            && settingsOverlay.blocksDesktop

        // Serialize launcher transitions; settings/music owners live elsewhere.
        OverlayCoordinator {
            id: overlayCoordinator
            onOpenRequested: (owner, target) => {
                if (owner === "wave") launcherSurface.host.openRoute(target, null)
                else if (owner === "settings") settingsOverlay.openFrom(null, true)
            }
            onCloseRequested: owner => {
                if (owner === "wave") launcherSurface.host.close()
                else if (owner === "settings") settingsOverlay.closeWithoutFocusRestore()
            }
        }

        // Bar-side open intents (gear button) join the same serialized path.
        Connections {
            target: SettingsOverlayBridge
            function onOpenRequested() {
                overlayCoordinator.request("settings", null, true)
            }
        }

        // Drive the hold-key window hint through the shared popup host. One
        // connection per screen scope, so every screen shows the same snapshot
        // anchored over its own bar; the service is a singleton, so this is the
        // only place the trigger is consumed.
        //
        // The snapshot refresh lands separately from the hold: a workspace
        // switch while mod is down is a data change, not a reopen, and must
        // keep the popup in place.
        Connections {
            target: Services.WindowHintService
            function onHintHeldChanged() {
                if (Services.WindowHintService.hintHeld)
                    screenScope.openWindowHint()
                else
                    screenScope.closeWindowHint()
            }
            function onActiveHintChanged() {
                screenScope.refreshWindowHint()
            }
        }

        // The hint's anchor is the bar's own midpoint, so a bar width change is
        // the only thing that can invalidate it.
        Connections {
            target: barContent
            function onAnchorInvalidated() { screenScope.refreshWindowHint() }
        }

        // Mirror the shared island settings route into this screen's owner.
        // SettingsService changes IslandService state before this window can
        // animate, so both the IPC and bar-button paths stay consistent.
        Connections {
            target: Services.IslandService
            function syncSettingsOverlay() {
                var settingsOpen = Services.IslandService.expanded
                        && Services.IslandService.panelPage === "settings-center"
                if (settingsOpen) {
                    popupHost.dismissImmediately()
                    overlayCoordinator.request("settings", null, true, true)
                } else if (settingsOverlay.interactive
                           && overlayCoordinator.activeTarget === "settings") {
                    settingsOverlay.closeWithoutFocusRestore()
                }
            }
            function onExpandedChanged() { syncSettingsOverlay() }
            function onPanelPageChanged() { syncSettingsOverlay() }
        }

        // Open the shared settings surface for a widget context action.
        Connections {
            target: Services.BarLayoutService
            function onWidgetSettingsVisibleChanged() {
                if (!Services.BarLayoutService.widgetSettingsVisible)
                    return
                popupHost.requestAnimatedClose()
                settingsOverlay.prepareDebugOpen()
                settingsOverlay.panel.selectedCategory = Services.BarLayoutService.widgetSettingsSection === "right"
                        ? "notifications" : "bar"
                overlayCoordinator.request("settings", null, true, true)
            }
        }

        PanelWindow {
            id: barWindow

            screen: screenScope.modelData
            color: "transparent"
            // Name the surface so compositor diagnostics can identify it.
            WlrLayershell.namespace: "afloat-bar"
            // Keep the physical bar above popup surfaces and normal windows.
            WlrLayershell.layer: WlrLayer.Overlay
            implicitHeight: screenScope.effectiveHeight
            // Deliberately NOT released while the bar collapses. niri sizes a
            // fullscreen tile to the whole output, so the reserved strip is
            // invisible during fullscreen; dropping it would instead reflow every
            // tiled window twice per fullscreen toggle.
            exclusiveZone: screenScope.floating ? 0 : implicitHeight
            anchors { top: screenScope.atTop; bottom: !screenScope.atTop; left: true; right: true }
            margins { top: screenScope.floatingMargin; bottom: screenScope.floatingMargin; left: screenScope.floatingMargin; right: screenScope.floatingMargin }

            // While collapsed the surface claims only a thin strip at the bar's
            // anchored edge. Keeping the probe on this same surface avoids a
            // second overlay-layer surface, whose z-order against this one the
            // compositor decides and the client cannot pin.
            //
            // The source is a bare Item, exactly like BarPopupHost's
            // popupFullRegion: it exists only to give the mask a geometry.
            mask: Region { item: revealProbe }

            // Slide the painted bar out of view. Only the inner content moves, so
            // the layer-shell surface, its exclusive zone and its blur region
            // never resize per frame.
            //
            // No opacity on this container: the bar translates as a solid object
            // and never fades. A bar that dissolves while sliding reads as two
            // things happening at once and looks half-broken on a fast throw,
            // and osu!lazer's panel moves are position-only for the same reason.
            // The edge hint below is the only thing that fades, since it is a
            // cue rather than a surface in motion.
            //
            // Geometry is set outright rather than with anchors.fill: an explicit
            // `y` would silently fight the top anchor, and a per-frame re-anchor
            // is exactly the kind of resize the note above rules out.
            Item {
                id: barSlide
                x: 0
                y: (1 - screenScope.revealProgress)
                        * (screenScope.atTop ? -barSlide.height : barSlide.height)
                width: parent.width
                height: parent.height

                // Paint the continuous sharp bar silhouette behind every widget.
                Rectangle {
                    anchors.fill: parent
                    radius: 0
                    color: Services.SettingsService.effectiveColorScheme === "light" ? LazerTheme.bgLight : LazerTheme.bgDark
                    opacity: Math.max(0.35, Math.min(1, Services.SettingsService.panelSurfaceOpacity))

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                    Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
                }

                // The pre-lazer full-screen ripple, re-hosted: the ring, its
                // luminous core and the afterglow band sweep across this bar
                // strip instead of the whole display, clipped to the strip.
                // Painted under the widgets so the sweep lights the bar's own
                // surface and the glyphs stay legible on top of it.
                RippleGlow {
                    id: barGlow

                    anchors.fill: parent
                    glowEnabled: Services.SettingsService.appearance.ripplePulseEnabled !== false
                    originXRatio: 0.5
                    originYRatio: 0.5

                    // A pulse published for another screen is not ours to
                    // play; a screen-agnostic one (a notification) is.
                    function playPulse() {
                        if (!Services.RipplePulseService.matchesScreen(screenScope.screenName))
                            return
                        originXRatio = Services.RipplePulseService.pulseOriginXRatio
                        play()
                    }

                    Connections {
                        target: Services.RipplePulseService
                        function onTokenChanged() { barGlow.playPulse() }
                    }

                    // A notification is not a bar event, so it is announced on
                    // the notification service instead of the pulse bus. The
                    // sweep starts on the side the card flies in from.
                    Connections {
                        target: Services.NotificationService
                        function onPopupArrived() {
                            if (!Services.SettingsService.appearance.ripplePulseEnabled)
                                return
                            barGlow.originXRatio = Services.NotificationService.notificationRight ? 0.82 : 0.18
                            barGlow.play()
                        }
                    }
                }

                // The screen bezel corners this bar physically covers. The bezel's
                // own surface is a separate overlay-layer surface, and a client
                // cannot order two of them against each other, so the corners the
                // bar overlaps are painted here instead: above this window's own
                // fill they are always the topmost thing, whatever the compositor
                // does with the other surface. Painted after the fill so the wedge
                // stays opaque black rather than being tinted by it.
                ScreenCornerMask {
                    anchors.fill: parent
                    radius: Math.max(0, Number(Services.SettingsService.appearance.screenCornerRadius) || 0)
                    corners: CornerMask.barCornerMask(
                        String(Services.SettingsService.bar.position || "top"),
                        Services.SettingsService.bar.floating === true)
                    // Clamp against the screen, not against this one-strip-tall
                    // window, so the radius matches the corners the bezel surface
                    // paints on the opposite edge.
                    screenWidth: screenScope.modelData.width
                    screenHeight: screenScope.modelData.height
                }

                BarContent {
                    id: barContent
                    anchors.fill: parent
                    screenName: screenScope.modelData ? String(screenScope.modelData.name || "") : ""

                    // While mod is held the hint owns the popup, so a widget's own hover traffic
                    // must not reach the host. Two reasons, both observable:
                    // a leave from the widget the pointer started on would run
                    // the host's close timer and retire the hint while mod is
                    // still down, and a second widget's hover or anchor update
                    // would take the popup over mid-hold, turning every refresh
                    // into an alternating replacement crossfade. The widget's
                    // recorded intent is kept either way, so releasing mod hands
                    // the popup straight back to it (see closeWindowHint).
                    readonly property bool hintOwnsPopup: screenScope.windowHintHeld

                    // Forward hover intents to the per-screen popup host.
                    onPopupRequested: intent => {
                        if (!intent || screenScope.hintOwnsPopup) return
                        var enriched = Object.assign({}, intent)
                        enriched.screenWidth = screenScope.modelData ? Number(screenScope.modelData.width) : 1920
                        enriched.screenHeight = screenScope.modelData ? Number(screenScope.modelData.height) : 1080
                        enriched.barPosition = String(Services.SettingsService.bar.position || "top")
                        enriched.effectiveBarHeight = screenScope.effectiveHeight
                        enriched.floatingMargin = screenScope.floatingMargin
                        popupHost.widgetHovered = true
                        popupHost.updateIntent(enriched)
                    }
                    onPopupCloseRequested: {
                        if (screenScope.hintOwnsPopup) return
                        popupHost.widgetHovered = false
                        popupHost.requestClose()
                    }
                    onPopupAnchorUpdate: intent => {
                        if (!intent || !popupHost.open || screenScope.hintOwnsPopup) return
                        var enriched = Object.assign({}, intent)
                        enriched.screenWidth = screenScope.modelData ? Number(screenScope.modelData.width) : 1920
                        enriched.screenHeight = screenScope.modelData ? Number(screenScope.modelData.height) : 1080
                        enriched.barPosition = String(Services.SettingsService.bar.position || "top")
                        enriched.effectiveBarHeight = screenScope.effectiveHeight
                        enriched.floatingMargin = screenScope.floatingMargin
                        // Refresh all slot data in place without recreating the reveal.
                        if (popupHost.intent)
                            popupHost.updateIntent(enriched)
                        popupHost.cancelClose()
                    }
                    onContextPopupRequested: intent => {
                        if (!intent) return
                        var enriched = Object.assign({}, intent)
                        enriched.screenWidth = screenScope.modelData ? Number(screenScope.modelData.width) : 1920
                        enriched.screenHeight = screenScope.modelData ? Number(screenScope.modelData.height) : 1080
                        enriched.barPosition = String(Services.SettingsService.bar.position || "top")
                        enriched.effectiveBarHeight = screenScope.effectiveHeight
                        enriched.floatingMargin = screenScope.floatingMargin
                        popupHost.widgetHovered = true
                        popupHost.updateIntent(enriched)
                    }
                    onContextPopupCloseRequested: {
                        popupHost.widgetHovered = false
                        popupHost.requestClose()
                    }
                }
            }

            // The surface's input region. Revealed, it is the whole bar; while
            // collapsed it is only this strip at the bar's anchored edge, which
            // is what makes the bar recallable while a fullscreen window holds
            // the screen. Switching it outright (never per frame) costs nothing:
            // the pointer has to already sit on the strip to trigger a reveal.
            Item {
                id: revealProbe
                width: barSlide.width
                height: screenScope.revealed ? barSlide.height : RevealLogic.revealStripHeight
                y: screenScope.atTop ? 0 : barSlide.height - height
            }

            // Painted hint that a collapsed bar is still here. A sharp
            // rectangular bar, like the bar itself — no rounding on a major
            // surface.
            Rectangle {
                width: barSlide.width
                height: RevealLogic.revealStripHeight
                y: screenScope.atTop ? 0 : barSlide.height - height
                radius: 0
                color: Services.SettingsService.effectiveColorScheme === "light"
                        ? LazerTheme.bgLight : LazerTheme.bgDark
                opacity: (1 - screenScope.revealProgress)
                        * Math.max(0.35, Math.min(1, Services.SettingsService.panelSurfaceOpacity)) * 0.7

                Behavior on opacity { NumberAnimation { duration: MotionTokens.medium } }
            }

            // Hover probe. This surface stays mapped and the pointer stays over
            // it while collapsed, so a reveal must consume the arm; only a
            // pointer that travels back out past the strip re-arms it.
            HoverHandler {
                id: surfaceHover
                onHoveredChanged: {
                    if (hovered) {
                        screenScope._sendReveal("enter")
                        _hideTimer.restart()
                    } else {
                        // The pointer is gone from the surface, so any distance
                        // it had is no longer evidence about the edge strip.
                        screenScope._forgetPointer()
                        screenScope._sendReveal("leave")
                        _hideTimer.stop()
                    }
                }
                onPointChanged: {
                    screenScope._notePointerDistance(
                        RevealLogic.distanceFromEdge(
                            point.position.y, barSlide.height, screenScope.atTop))
                    _hideTimer.restart()
                }
            }
        }

        // Per-screen hover popup host. One instance per screen scope; no per-widget hosts.
        BarPopupHost {
            id: popupHost
            screen: screenScope.modelData
            screenWidth: screenScope.modelData ? Number(screenScope.modelData.width) : 1920
            screenHeight: screenScope.modelData ? Number(screenScope.modelData.height) : 1080
            effectiveBarHeight: screenScope.effectiveHeight
            floatingMargin: screenScope.floatingMargin
        }

        Connections {
            target: SettingsOverlayBridge
            function onOpenRequested() { popupHost.requestAnimatedClose() }
        }

        // Keep the launcher wave below the bar while only its internal viewport moves.
            PanelWindow {
                id: launcherWindow
                screen: screenScope.modelData; color: "transparent"
                WlrLayershell.namespace: "afloat-launcher"
            implicitWidth: screenScope.modelData.width; implicitHeight: screenScope.modelData.height
            exclusionMode: ExclusionMode.Ignore
            anchors { top: Services.SettingsService.bar.position === "top"; bottom: Services.SettingsService.bar.position === "bottom"; left: true }
            // Offset by the same clamped height the bar actually renders at.
            margins { top: Services.SettingsService.bar.position === "top" ? screenScope.floatingMargin + screenScope.effectiveHeight : 0; bottom: Services.SettingsService.bar.position === "bottom" ? screenScope.floatingMargin + screenScope.effectiveHeight : 0 }
            mask: Region { item: launcherSurface.host.visible ? launcherSurface.host : null }
            // Take keyboard only while the launcher is up so typing reaches its
            // search field and global keys stay free when closed.
            WlrLayershell.keyboardFocus: launcherSurface.host.interactive
                    ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            LauncherSurface {
                id: launcherSurface; anchors.fill: parent
                coordinator: overlayCoordinator
                session: Services.LauncherService
            }
        }

        // Keep Settings in a dedicated left-side owner with no full-screen mask.
            PanelWindow {
                id: settingsWindow
                screen: screenScope.modelData; color: "transparent"
                WlrLayershell.namespace: "afloat-settings"
                // Settings must remain visible above the fixed popup owners.
                WlrLayershell.layer: WlrLayer.Overlay
            implicitWidth: Math.min(LazerTheme.settingsPanelWidth, screenScope.modelData.width)
            implicitHeight: screenScope.modelData.height
            exclusionMode: ExclusionMode.Ignore
            anchors { top: Services.SettingsService.bar.position === "top"; bottom: Services.SettingsService.bar.position === "bottom"; left: true }
            margins { top: Services.SettingsService.bar.position === "top" ? screenScope.floatingMargin + screenScope.effectiveHeight : 0; bottom: Services.SettingsService.bar.position === "bottom" ? screenScope.floatingMargin + screenScope.effectiveHeight : 0 }
            mask: Region { item: screenScope.settingsMaskActive ? settingsOverlay : null }
            // Take keyboard only while settings is open so typing reaches its
            // text fields and global keys stay free when closed.
            WlrLayershell.keyboardFocus: settingsOverlay.interactive
                    ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            LazerSettingsOverlay {
                id: settingsOverlay; anchors.fill: parent
                panel.appearanceSettings: Services.SettingsService.appearance
                panel.barSettings: Services.SettingsService.bar
                panel.notificationSettings: Services.SettingsService.notifications
                panel.saveCallback: Services.SettingsService.save
                panel.appearanceDefaults: Services.SettingsService.appearanceDefaults
                panel.barDefaults: Services.SettingsService.barDefaults
                panel.notificationDefaults: Services.SettingsService.notificationDefaults
                panel.settingsReset: Services.SettingsService.resetCategorySetting
                panel.wallpaperService: Services.WallpaperService
                panel.locationService: Services.LocationService
                panel.effectiveSunrise: Services.SettingsService.effectiveSunrise
                panel.effectiveSunset: Services.SettingsService.effectiveSunset
                panel.coordsValid: Services.SettingsService.locationCoordsValid
                panel.locationError: Services.LocationService.lastError
                panel.locationDisplayName: Services.LocationService.displayName
                debugHoverEnabled: Services.SettingsService.hoverDebugEnabled
                debugHoverToken: Services.SettingsService.hoverDebugToken
                debugMaskOverride: Services.SettingsService.settingsMaskOverride
                debugMaskActive: screenScope.settingsMaskActive
                debugScreenName: screenScope.modelData && screenScope.modelData.name
                        ? String(screenScope.modelData.name) : "unknown"
                onClosed: overlayCoordinator.ownerClosed("settings")
            }
        }
    }
}
