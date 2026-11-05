pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../bar/widgets" as BarWidgets
import "../lazerbar" as Lazer
import "../../services" as Services
import "./LockLogic.js" as LockLogic
import "./LockSurfaceLogic.js" as SurfaceLogic

// Own one compositor-enforced full-screen session-lock surface.
WlSessionLockSurface {
    id: root

    property var lockContext: null
    property var snapshot: null
    // This surface's slot in the shared per-screen snapshot data; the shared
    // snapshot never decides which screen a surface belongs to.
    readonly property int screenIndex: SurfaceLogic.screenSlot(Quickshell.screens, root.screen)
    readonly property string snapshotUrl: snapshot && screenIndex >= 0
            ? snapshot.snapshotUrlFor(screenIndex) : ""
    property string wallpaperPath: ""
    property real decodeRatio: 1
    // Whether this request expects a pre-lock capture. The session-start lock
    // passes false, so its reveal is not gated on an image that will never exist.
    property bool captureExpected: true
    // Single reveal driver; the backdrop derives the trailing mask from it
    // so bands and wallpaper edge always move as one curtain.
    property real waveProgress: 0
    property real entryBodyProgress: 0
    // Exit body travel has its own clock, matching WaveSurfaceHost: the wave
    // uses InSine while the opaque body uses InQuad. Binding both to
    // waveProgress makes the body swallow the stretched wave too early.
    property real exitBodyProgress: 1
    // Unlock drop driver: 0 keeps every content block in place, 1 has carried all
    // of them below the surface's bottom edge. The wave sweep waits for it.
    property real contentFallProgress: 0
    // Entry rise driver: the mirror of the drop, sampled by each block at its own
    // delayed position. It runs under the curtain, not after it.
    property real entryContentProgress: 0
    property bool reducedMotion: Lazer.MotionTokens.reducedMotion
    property bool exitStarted: false
    property bool exitWaveActive: false
    property bool exitWavePending: false
    property bool releaseSent: false
    property int revealWaitTicks: 0
    property string authControlState: SurfaceLogic.AuthControlStates.idle
    property bool themeSnapshotReady: false
    property var lockThemeSnapshot: ({})
    // Read the effective mode directly here. The lock surface can be created
    // before the shared theme palette has finished applying its new scheme.
    property bool lightScheme: Services.SettingsService.effectiveColorScheme === "light"
    readonly property real authInputWidth: Math.max(0, Math.min(360, root.width - 48))
    // One baseline for the lock entry and the power row: both are 48 tall, so
    // sharing this margin is what puts them on the same horizontal line.
    readonly property real authControlBottomMargin: 56
    readonly property real authControlHeight: 48
    // The password cells occupy the control between the glyph inset and the
    // right inset. They grow from this left edge and the caret tracks their end,
    // the way osu's own mask does: a centred run re-centred itself on every
    // keystroke, so a deleted capsule slid right while the caret stepped left
    // past it and only then disappeared.
    readonly property real passwordTextLeftInset: 56
    readonly property real passwordTextRightInset: 20
    readonly property color authControlColor: root.themeSnapshotReady
            ? root.lockThemeSnapshot.control
            : (root.lightScheme ? Lazer.LazerTheme.bgLight : Lazer.LazerTheme.settingsControlSurface)
    readonly property color authTextColor: root.themeSnapshotReady
            ? root.lockThemeSnapshot.text
            : SurfaceLogic.readableTextColor(Lazer.LazerTheme.accentColor, root.lightScheme)
    // Keep the lock glyph as an accent landmark instead of merging it with
    // the password text that occupies the same control. It sits on that control,
    // not on the wallpaper, so it follows the scheme rather than the clock's
    // wallpaper-region ink.
    readonly property color authIconColor: root.themeSnapshotReady
            ? root.lockThemeSnapshot.icon
            : SurfaceLogic.readableThemeColor(Lazer.LazerTheme.accentColor,
                                              root.lightScheme)
    readonly property color authDateColor: root.themeSnapshotReady
            ? root.lockThemeSnapshot.muted
            : (root.lightScheme ? "#5F5A66" : Lazer.LazerTheme.textMuted)
    readonly property real clockCenterX: clockLayout.ready ? clockLayout.centerX : 0.5
    readonly property real clockCenterY: clockLayout.ready ? clockLayout.centerY : 0.5
    // -1 means "no measurement": the clock ink then follows the scheme so a cold
    // placement cache can never paint a polarity the wallpaper contradicts.
    readonly property real clockLuminance: clockLayout.ready ? clockLayout.luminance : -1
    readonly property color clockColor: root.themeSnapshotReady
            ? root.lockThemeSnapshot.clock
            : SurfaceLogic.clockThemeColor(Lazer.LazerTheme.accentColor,
                                           root.clockLuminance, root.lightScheme)
    // The date shares the clock's ink: size alone carries the hierarchy, so the
    // pair reads as one instrument instead of two differently-tinted texts.
    readonly property color clockDateColor: root.clockColor
    // Distance between the bottom of the time's glyphs and the top of the date's.
    // Scales with the time so a larger size never collapses the two lines onto
    // each other: 0.33 of 72px is 24px of real air between the ink boxes.
    readonly property real clockLineGap: Math.round(clockTime.digitPixelSize * 0.33)
    readonly property bool authFailureVisible: root.lockContext
            ? root.lockContext.showFailure : false
    property date now: new Date()
    property bool inputMode: false

    signal releaseRequested()
    // Emitted only after the exit desktop is ready and the closing wave has
    // actually started. The lock owner uses it to re-arm its failsafe from
    // the visible wave, rather than counting image-decode time as animation.
    signal exitWaveStarted()
    // Startup gating: a session-start surface prepares immediately but holds
    // its entry wave until the wallpaper reveal has settled and the bar chrome
    // has finished staging. Manual surfaces wave at once. The boolean records
    // that the wave began; the signal notifies the lock owner. The names stay
    // distinct because a property and a signal may not share one.
    //
    // The signal is the entry-wave scheduling event, not the animation-start
    // event: it fires when the wave is committed to run (the bounded image
    // wait timer is armed; the 800ms enter still runs afterwards), or, under
    // reduced motion, when the settled state is committed. Task 5 releases
    // post-wave work on it, in parallel with the reveal.
    property bool startupRequest: false
    property bool startupRevealAllowed: true
    property bool startupWaveStarted: false
    signal startupWaveStartedSignal()

    // The surface itself commits no colour; the backdrop paints its first frame
    // (the theme floor, the wallpaper and the wave) as an opaque surface.
    color: "transparent"

    // Prepare the surface for its entry: snapshot the theme, reset the
    // animation state, and settle instantly when motion is reduced. Starting
    // the wave itself is separate (see beginEntryWave) so a session-start
    // surface can wait for the startup gates first.
    function prepareReveal(): void {
        lightScheme = Services.SettingsService.effectiveColorScheme === "light"
        lockThemeSnapshot = SurfaceLogic.lockThemeSnapshot(lightScheme, {
            accent: Lazer.LazerTheme.adapt ? Lazer.LazerTheme.accentColor : null,
            surface: lightScheme ? Lazer.LazerTheme.bgLight : Lazer.LazerTheme.bgDark,
            control: lightScheme ? Lazer.LazerTheme.bgLight : Lazer.LazerTheme.settingsControlSurface,
            panel: Lazer.LazerTheme.settingsPanel,
            trigger: Lazer.LazerTheme.settingsControlSurface,
            active: Lazer.LazerTheme.activeFill,
            hover: Lazer.LazerTheme.hoverFill,
            label: Lazer.LazerTheme.textPrimary,
            pink: Lazer.LazerTheme.osuPink,
            focus: Lazer.LazerTheme.focusRing,
            muted: lightScheme ? "#5F5A66" : Lazer.LazerTheme.textMuted,
            divider: Lazer.LazerTheme.divider,
        }, root.clockLuminance)
        themeSnapshotReady = true
        exitStarted = false
        exitWaveActive = false
        exitWavePending = false
        exitBodyProgress = 1
        entryBodyProgress = reducedMotion ? 1 : 0
        entryContentProgress = reducedMotion ? 1 : 0
        releaseSent = false
        exitReleaseSettleTimer.stop()
        startupWaveStarted = false
        inputMode = false
        contentFallProgress = 0
        authControlState = SurfaceLogic.AuthControlStates.idle
        unlockFeedbackTimer.stop()
        unlockCollapseTimer.stop()
        if (reducedMotion) {
            SurfaceLogic.applyRevealImmediately(root, allAnimations())
            return
        }
        SurfaceLogic.stopAll(allAnimations())
        revealWaitTicks = 0
    }

    // Manual entry: prepare and wave at once, never consulting the gates.
    function startReveal(): void {
        prepareReveal()
        beginEntryWave()
    }

    // Repaint the clock from a placement answer that landed after the cycle's
    // snapshot was frozen. The accent is taken from that frozen snapshot (not
    // from the live theme) so the clock cannot drift away from the rest of the
    // lock surface; only the role whose value depends on the wallpaper region
    // is recomputed.
    function refreshClockTheme(): void {
        if (!root.themeSnapshotReady || !clockLayout.ready)
            return
        var roles = SurfaceLogic.clockRoles(root.lockThemeSnapshot.accent,
                                            root.clockLuminance, root.lightScheme)
        var next = Object.assign({}, root.lockThemeSnapshot)
        next.clock = roles.clock
        root.lockThemeSnapshot = next
    }

    // Startup entry: prepare now, wave only once the gates allow it. Called
    // from Component.onCompleted; the onStartupRevealAllowedChanged handler
    // below covers the closed-to-open transition afterwards.
    function tryStartReveal(): void {
        prepareReveal()
        if (!root.startupRequest || root.startupRevealAllowed)
            root.beginEntryWave()
    }

    // Commit the entry wave and report it exactly once. With motion, this arms
    // the bounded image wait that starts the 800ms enter; under reduced motion
    // there is no animation, so the timer stays stopped and only the flag and
    // the scheduling signal are recorded. A repeat call after the wave began
    // (gate flapping, second prepare) is a no-op. Never called from
    // prepareReveal, so a startup surface whose gate is still closed settles
    // without emitting; the emission lands when the gate actually opens.
    function beginEntryWave(): void {
        if (root.exitStarted || root.startupWaveStarted)
            return
        root.startupWaveStarted = true
        if (!root.reducedMotion)
            revealStartTimer.restart()
        root.startupWaveStartedSignal()
    }

    // The unlock choreography runs in two beats: every content block drops back
    // through the bottom edge it arrived from, and only then does the wave close
    // over the now empty surface. The release still lands on the wave's own
    // completion.
    function startExit(): void {
        if (exitStarted)
            return
        exitStarted = true
        if (reducedMotion) {
            contentFallProgress = 1
            exitWaveActive = true
            exitBodyProgress = 0
            SurfaceLogic.applyExitImmediately(root, allAnimations())
            requestRelease()
            return
        }
        SurfaceLogic.stopAll(allAnimations())
        if (contentFallProgress <= 0) {
            contentFallAnimation.restart()
            return
        }
        startWaveExit()
    }

    function startWaveExit(): void {
        if (!backdrop.exitDesktopReady) {
            exitWavePending = true
            return
        }
        exitWavePending = false
        exitWaveActive = true
        exitBodyAnimation.restart()
        exitAnimation.from = waveProgress
        exitAnimation.start()
        root.exitWaveStarted()
    }

    function requestRelease(): void {
        if (releaseSent || !LockLogic.shouldReleaseLock("exiting", true))
            return
        releaseSent = true
        releaseRequested()
    }

    function allAnimations(): var {
        return [enterAnimation, entryBodyAnimation, entryContentAnimation,
            exitAnimation, exitBodyAnimation, contentFallAnimation]
    }

    // How far the clock has to move to be completely out of sight: from its
    // resting bottom to the surface's bottom edge plus its own ink height. It is
    // the longest journey on the surface, which is why it starts and finishes last
    // in both directions.
    readonly property real clockTravel: SurfaceLogic.travelBelow(
        root.height,
        root.clockCenterY * root.height + timeContent.height / 2,
        timeContent.height)

    // Every block reads one staggered span at its own delayed position, so the
    // clock, the lock control and the power row arrive and leave as a wave
    // instead of as a single block. A slot is how far a block has climbed from
    // below the surface's bottom edge; entry reads it forward, exit back down.
    // Both directions start at the bottom and end at the top, because that is the
    // only order that agrees with the distance each block covers: the bottom row
    // barely clears its own height while the clock crosses most of the output, so
    // starting the clock first would drop it through the two blocks under it.
    readonly property var contentSlots: SurfaceLogic.contentSlots(
        root.contentFallProgress,
        Lazer.MotionTokens.lockContentTravel,
        Lazer.MotionTokens.lockContentStagger,
        SurfaceLogic.contentBlocks.count,
        SurfaceLogic.contentShapes.fall)
    readonly property var entrySlots: SurfaceLogic.contentSlots(
        root.entryContentProgress,
        Lazer.MotionTokens.lockContentTravel,
        Lazer.MotionTokens.lockContentStagger,
        SurfaceLogic.contentBlocks.count,
        SurfaceLogic.contentShapes.rise)

    // The slot lists and the travel distances are passed in rather than read from
    // `root` inside these helpers: a property read inside a JS function is not
    // part of the binding's capture set, so the caller has to keep every dynamic
    // read in the expression itself.
    //
    // How far a block has to move to sit completely below the surface's bottom
    // edge: nothing about that is a shared constant, because each block rests at a
    // different height and has its own size.
    function travelBelow(blockBottom, blockHeight): real {
        return SurfaceLogic.travelBelow(root.height, blockBottom, blockHeight)
    }

    // Entry displacement: blocks that have not started yet sit below the bottom
    // edge and climb to their place. Both directions use the same distance, so a
    // block entering and a block leaving are the same journey — the motion is a
    // position move through the surface's edge, never a fade.
    function entryOffset(slots, block, distance): real {
        return (1 - SurfaceLogic.contentSlot(slots, block)) * distance
    }

    // Exit displacement, on the same staggered structure running downward. Every
    // block leaves through the bottom edge on the same journey it arrived on, so
    // nothing fades: it leaves sight by clearing the edge.
    function exitOffset(slots, block, distance): real {
        return SurfaceLogic.contentSlot(slots, block) * distance
    }

    // Enter the inline authentication mode without changing PAM state.
    function enterInputMode(): void {
        inputMode = true
        authControlState = SurfaceLogic.authControlTransition(
            authControlState, "enter-input")
        keyboardOwner.forceActiveFocus()
    }

    // Give the user a safe recovery path when authentication input is stuck.
    function cancelInputMode(): bool {
        if (!root.lockContext)
            return false
        const action = SurfaceLogic.inputEscapeAction(root.inputMode,
                                                      root.lockContext.unlockInProgress)
        if (action === "none")
            return false
        root.lockContext.reset()
        root.inputMode = false
        root.authControlState = SurfaceLogic.authControlTransition(
            root.authControlState, "reset")
        unlockFeedbackTimer.stop()
        unlockCollapseTimer.stop()
        keyboardOwner.forceActiveFocus()
        return true
    }

    // One key path for the whole surface. The keyboard owner and any focused
    // session button both go through it, so a power button can never become a
    // second keyboard owner that swallows the password.
    function applyAuthKey(key, text): bool {
        if (key === Qt.Key_Escape) {
            if (actionBar.handleEscape())
                return true
            return root.cancelInputMode()
        }
        if (!root.lockContext)
            return false
        const isSubmit = key === Qt.Key_Return || key === Qt.Key_Enter
        const isBackspace = key === Qt.Key_Backspace
        const isPrintable = text && text.length === 1
        if (!isSubmit && !isBackspace && !isPrintable)
            return false
        root.enterInputMode()
        const edit = SurfaceLogic.passwordInputEdit(
                    root.lockContext.currentText, isSubmit, isBackspace, text)
        if (edit.action === "submit") {
            root.lockContext.submit()
            return true
        }
        if (edit.action === "edit") {
            root.lockContext.currentText = edit.text
            return true
        }
        return false
    }

    onLockContextChanged: {
        contextConnections.target = lockContext
    }

    // The gate binding flips true once both startup readiness flags land;
    // only a session-start surface waits on it. tryStartReveal covers the case
    // where the gate was already open at creation, so this handler only fires
    // on the closed-to-open transition.
    onStartupRevealAllowedChanged: {
        if (root.startupRequest && root.startupRevealAllowed)
            root.beginEntryWave()
    }

    Component.onCompleted: {
        if (root.startupRequest)
            root.tryStartReveal()
        else
            root.startReveal()
        keyboardOwner.forceActiveFocus()
    }

    function showUnlockFeedback(): void {
        // Hold the expanded field while the unlock glyph is readable.
        inputMode = true
        authControlState = SurfaceLogic.authControlTransition(
            authControlState, "auth-success")
        unlockFeedbackTimer.restart()
    }

    function collapseUnlockFeedback(): void {
        inputMode = false
        unlockCollapseTimer.restart()
    }

    LockBackdrop {
        id: backdrop
        anchors.fill: parent
        snapshotSource: root.snapshotUrl
        wallpaperSource: root.wallpaperPath
        decodeRatio: root.decodeRatio
        captureExpected: root.captureExpected
        progress: root.waveProgress
        exiting: root.exitWaveActive
        exitWaveActive: root.exitWaveActive
        exitBodyProgress: root.exitBodyProgress
        entryBodyProgress: root.entryBodyProgress
        lightScheme: root.lightScheme
        surfaceColorOverride: root.themeSnapshotReady
                ? root.lockThemeSnapshot.surface : "transparent"
    }

    // Analyze the real wallpaper independently for every lock surface.
    WallpaperClockLayout {
        id: clockLayout
        wallpaperPath: root.wallpaperPath
        screenWidth: Math.round(root.width)
        screenHeight: Math.round(root.height)
        // Placement (and the region's luma) usually arrives before the lock, but
        // a cold cache answers during the surface's life: repaint the clock then.
        onAnalysisApplied: root.refreshClockTheme()
    }

    // Start the curtain after the base has had one settled frame. A capture
    // owns that hold — it is the desktop the user was just looking at, and it
    // must read before the mask starts. A session-start lock brings no capture
    // (its base is the floor, which is the compositor background it replaces),
    // so the wave leaves as soon as the wallpaper layer is decodable instead of
    // parking the floor for a screenshot's settle that has nothing to settle.
    Timer {
        id: revealStartTimer
        interval: root.captureExpected ? 250 : 0
        repeat: false
        onTriggered: {
            if (root.exitStarted || root.reducedMotion)
                return
            if (!backdrop.imagesReady && root.revealWaitTicks < 12) {
                root.revealWaitTicks += 1
                restart()
                return
            }
            // Retarget from the live value so a re-reveal never jumps. The
            // content rise runs on its own, longer clock than the body: the three
            // blocks climb out of the bottom edge while the curtain is still
            // travelling, so the wave and the content are two asynchronous
            // motions rather than one.
            enterAnimation.from = root.waveProgress
            entryBodyAnimation.restart()
            entryContentAnimation.restart()
            enterAnimation.start()
        }
    }

    // Let the unlock glyph and compact control read before the wave exits.
    Timer {
        id: unlockFeedbackTimer
        interval: Lazer.MotionTokens.medium
        repeat: false
        onTriggered: root.collapseUnlockFeedback()
    }

    // Start the curtain only after the compact success state has settled.
    Timer {
        id: unlockCollapseTimer
        interval: Lazer.MotionTokens.instant
        repeat: false
        onTriggered: root.startExit()
    }

    // Keep session actions inside this compositor-owned surface.
    LockActionBar {
        id: actionBar
        parent: backdrop.revealContentHost
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 28
        // Share the lock entry's baseline: same height, same bottom margin, so
        // the power row sits on the lock glyph's own horizontal line.
        anchors.bottomMargin: root.authControlBottomMargin
        reducedMotion: root.reducedMotion
        sessionService: Services.SessionService
        lightScheme: root.lightScheme
        lockTheme: root.themeSnapshotReady ? root.lockThemeSnapshot : null
        entranceRevealed: backdrop.revealContentInteractive
        // The power row starts first and ends last: it is closest to the bottom
        // edge, so its journey is the shortest and it clears first. Nothing
        // fades — it leaves sight by dropping through that edge.
        // Entry and exit never overlap (the fall starts only after the rise has
        // landed), so the two displacements simply add: both are measured
        // downward, and one of them is always zero.
        transform: Translate {
            y: root.entryOffset(root.entrySlots, SurfaceLogic.contentBlocks.actions,
                                root.travelBelow(root.height - root.authControlBottomMargin,
                                                 root.authControlHeight))
               + root.exitOffset(root.contentSlots, SurfaceLogic.contentBlocks.actions,
                                 root.travelBelow(root.height - root.authControlBottomMargin,
                                                  root.authControlHeight))
        }
        z: 3.5

        onKeyboardReleased: keyboardOwner.forceActiveFocus()
        onKeyForwarded: (key, text) => {
            // A focused power button only forwards what the password field
            // understands; anything else returns focus to the auth owner.
            if (!root.applyAuthKey(key, text))
                keyboardOwner.forceActiveFocus()
        }
    }

    // Keep keyboard ownership independent of the animated auth content. The
    // session-lock surface must accept password input even while the content is
    // still fading in or when the background image is unavailable.
    Item {
        id: keyboardOwner
        anchors.fill: parent
        focus: true
        z: 4

        Keys.onPressed: event => {
            event.accepted = root.applyAuthKey(event.key, event.text)
        }
    }

    // Keep the clock and authentication control in the shared clipped reveal layer.
    // Blocks leaving through the bottom edge are cut by the backdrop's own clip on
    // the opened region — that hard edge is what replaces a fade.
    Item {
        id: authSurface
        parent: backdrop.revealContentHost
        anchors.fill: parent
        z: 3
        enabled: backdrop.revealContentInteractive

        // Keep the primary clock above the interaction control.
        Column {
            id: timeContent
            x: root.clockCenterX * parent.width - width / 2
            y: root.clockCenterY * parent.height - height / 2
            // The two lines are stacked by their *ink*, not by their item boxes.
            // A rolling digit strip carries roll overscan above and below the
            // glyphs, and a Text box carries ascent/descent the glyphs never
            // reach, so box-to-box spacing put far more air between the time and
            // the date than the same number would between two ordinary labels.
            // Measuring both ink boxes (below) lets this stay a real, small gap.
            spacing: root.clockLineGap
                - (clockTime.height - clockTime.digitInkBottom)
                - (dateFont.ascent + dateInk.tightBoundingRect.top)
            // The clock starts last and finishes last: it has furthest to travel,
            // so letting it start first would drop it straight through the two
            // blocks still standing under it. Its journey runs from its own
            // resting bottom to far enough below the surface's bottom edge that
            // the ink is gone, so it leaves sight without fading. The offset rides
            // a transform so the centered layout bindings above stay authoritative.
            transform: Translate {
                y: root.entryOffset(root.entrySlots, SurfaceLogic.contentBlocks.clock,
                                    root.clockTravel)
                   + root.exitOffset(root.contentSlots, SurfaceLogic.contentBlocks.clock,
                                     root.clockTravel)
            }

            Behavior on x {
                enabled: !root.reducedMotion
                NumberAnimation {
                    duration: Lazer.MotionTokens.medium
                    easing.type: Easing.OutQuint
                }
            }
            Behavior on y {
                enabled: !root.reducedMotion
                NumberAnimation {
                    duration: Lazer.MotionTokens.medium
                    easing.type: Easing.OutQuint
                }
            }

            // Show hours and minutes with the shared rolling digit component.
            // The lock clock is the surface's hero: the heaviest face the
            // monospace stack carries, at a size that reads across the room.
            BarWidgets.RollingClockTime {
                id: clockTime
                anchors.horizontalCenter: parent.horizontalCenter
                currentTime: root.now
                digitPixelSize: 72
                digitFontFamily: "monospace"
                digitWeight: Font.Black
                showSeconds: false
                digitColor: root.clockColor
                mutedDigitColor: root.clockDateColor
                separatorColor: root.clockColor
                hourTransitionDuration: Lazer.MotionTokens.clockHourFlip
                minuteTransitionDuration: Lazer.MotionTokens.clockMinuteFlip
                transitionEasing: Lazer.MotionTokens.clockFlipEasing
            }

            // Keep the calendar date directly below the primary time, at
            // exactly half its size so the pair scales as one unit.
            Text {
                id: clockDate
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(root.now, "yyyy.MM.dd")
                color: root.clockDateColor
                font.family: "monospace"
                font.pixelSize: clockTime.digitPixelSize / 2
                font.weight: Font.Black
                Behavior on color {
                    enabled: !root.reducedMotion
                    ColorAnimation { duration: Lazer.MotionTokens.medium }
                }
            }

            FontMetrics {
                id: dateFont
                font.family: clockDate.font.family
                font.pixelSize: clockDate.font.pixelSize
                font.weight: clockDate.font.weight
            }

            // Ink box of the date's own glyphs, in the date Text's coordinates.
            TextMetrics {
                id: dateInk
                font.family: clockDate.font.family
                font.pixelSize: clockDate.font.pixelSize
                font.weight: clockDate.font.weight
                text: "0123456789."
            }
        }

        // Keep the lock entry centered at the bottom in both visual states.
        Rectangle {
            id: authControl
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.authControlBottomMargin
            width: root.inputMode ? root.authInputWidth : 68
            height: root.authControlHeight
            radius: Lazer.LazerTheme.settingsChoiceRadius
            color: root.authControlColor
            border.width: root.authFailureVisible ? 2 : 1
            border.color: root.authFailureVisible ? root.authIconColor
                : (root.themeSnapshotReady ? root.lockThemeSnapshot.divider
                                            : Lazer.LazerTheme.divider)
            property real failureOffset: 0

            Behavior on width {
                enabled: !root.reducedMotion
                NumberAnimation {
                    duration: Lazer.MotionTokens.medium
                    easing.type: Easing.OutQuint
                }
            }
            Behavior on color {
                enabled: !root.reducedMotion
                ColorAnimation { duration: Lazer.MotionTokens.fast }
            }
            Behavior on border.width {
                enabled: !root.reducedMotion
                NumberAnimation {
                    duration: Lazer.MotionTokens.fast
                    easing.type: Easing.OutQuint
                }
            }
            Behavior on border.color {
                enabled: !root.reducedMotion
                ColorAnimation { duration: Lazer.MotionTokens.fast }
            }
            // The failure shake and the staggered fall are separate offsets, so
            // a stale shake can never ride the drop away. The lock control sits
            // between the clock and the power row in both waves, and shares the
            // power row's bottom edge, so it makes the same short journey.
            transform: [
                Translate { x: authControl.failureOffset },
                Translate {
                    y: root.entryOffset(root.entrySlots, SurfaceLogic.contentBlocks.control,
                                        root.travelBelow(root.height - root.authControlBottomMargin,
                                                         root.authControlHeight))
                       + root.exitOffset(root.contentSlots, SurfaceLogic.contentBlocks.control,
                                         root.travelBelow(root.height - root.authControlBottomMargin,
                                                          root.authControlHeight))
                }
            ]

            // Keep the glyph visible while the same rectangle opens for input.
            Item {
                id: lockIconLayer
                width: 22
                height: 22
                anchors.verticalCenter: parent.verticalCenter
                x: root.inputMode ? 16 : (parent.width - width) / 2
                visible: true
                Behavior on x {
                    enabled: !root.reducedMotion
                    NumberAnimation {
                        duration: Lazer.MotionTokens.medium
                        easing.type: Easing.OutQuint
                    }
                }

                // Load the shared lock glyph before applying the theme tint.
                Image {
                    id: lockIconSource
                    anchors.fill: parent
                    width: 22
                    height: 22
                    source: root.authControlState === SurfaceLogic.AuthControlStates.unlocked
                            ? Qt.resolvedUrl("../lazerbar/icons/unlock.svg")
                            : Qt.resolvedUrl("../lazerbar/icons/lock.svg")
                    fillMode: Image.PreserveAspectFit
                    visible: false
                }

                // Tint the white source glyph for both color schemes.
                MultiEffect {
                    anchors.fill: lockIconSource
                    source: lockIconSource
                    colorization: 1
                    colorizationColor: root.authIconColor
                    Behavior on colorizationColor {
                        enabled: !root.reducedMotion
                        ColorAnimation { duration: Lazer.MotionTokens.fast }
                    }
                }
            }

            // osu-style password cells: one capsule per character, statically
            // declared because session-lock surfaces never paint Repeater
            // delegates. The row clips to the text inset, so overflow can never
            // widen the control.
            Item {
                id: passwordRow
                x: root.passwordTextLeftInset
                width: Math.max(0, parent.width - root.passwordTextLeftInset
                                - root.passwordTextRightInset)
                height: root.authControlHeight
                anchors.verticalCenter: parent.verticalCenter
                visible: root.inputMode
                clip: true

                // One FontSize-18 osu cell is half an em wide and one em tall.
                readonly property real cellWidth: 9
                readonly property real cellHeight: 18
                readonly property int count: root.lockContext
                        ? Math.min(root.lockContext.currentText.length,
                                   SurfaceLogic.maxMaskedCharacters) : 0

                // Fixed 32-cell strip anchored to the text's left edge. Left
                // alignment is what makes a deletion read as one capsule falling
                // away: the surviving cells hold their positions and only the
                // caret steps back. A centred strip re-centred itself on every
                // keystroke, so the capsule being deleted slid right under the
                // caret instead of staying where it was typed.
                Item {
                    id: passwordCells
                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32 * passwordRow.cellWidth
                    height: passwordRow.cellHeight

                    OsuPasswordDot { index: 0; x: 0 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 1; x: 1 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 2; x: 2 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 3; x: 3 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 4; x: 4 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 5; x: 5 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 6; x: 6 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 7; x: 7 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 8; x: 8 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 9; x: 9 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 10; x: 10 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 11; x: 11 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 12; x: 12 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 13; x: 13 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 14; x: 14 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 15; x: 15 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 16; x: 16 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 17; x: 17 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 18; x: 18 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 19; x: 19 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 20; x: 20 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 21; x: 21 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 22; x: 22 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 23; x: 23 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 24; x: 24 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 25; x: 25 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 26; x: 26 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 27; x: 27 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 28; x: 28 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 29; x: 29 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 30; x: 30 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                    OsuPasswordDot { index: 31; x: 31 * passwordRow.cellWidth; filled: index < passwordRow.count; cellWidth: passwordRow.cellWidth; cellHeight: passwordRow.cellHeight; dotColor: root.authTextColor }
                }
            }

            // osu caret at the end of the typed cells. The cells are painted
            // without a TextInput, so the geometry is explicit.
            Lazer.OsuTextCaret {
                target: null
                focused: root.inputMode && keyboardOwner.activeFocus
                cursorHeight: passwordRow.cellHeight * 0.9
                // Clamp to the clipped field so a full 32-cell row cannot put
                // the caret outside the control on a narrow screen.
                cursorX: Math.min(passwordRow.x + passwordCells.x
                                  + passwordRow.count * passwordRow.cellWidth,
                                  passwordRow.x + passwordRow.width - width)
                cursorY: (passwordRow.height - height) / 2
                color: root.authTextColor
                z: 2
                Behavior on color {
                    enabled: !root.reducedMotion
                    ColorAnimation { duration: Lazer.MotionTokens.fast }
                }
            }

            // Shake the unchanged input region when authentication fails.
            SequentialAnimation {
                id: failureAnimation
                running: false
                NumberAnimation {
                    target: authControl
                    property: "failureOffset"
                    from: 0
                    to: -6
                    duration: Lazer.MotionTokens.fast
                    easing.type: Easing.OutQuint
                }
                NumberAnimation {
                    target: authControl
                    property: "failureOffset"
                    to: 6
                    duration: Lazer.MotionTokens.fast
                    easing.type: Easing.OutQuint
                }
                NumberAnimation {
                    target: authControl
                    property: "failureOffset"
                    to: -3
                    duration: Lazer.MotionTokens.instant
                    easing.type: Easing.OutQuint
                }
                NumberAnimation {
                    target: authControl
                    property: "failureOffset"
                    to: 0
                    duration: Lazer.MotionTokens.fast
                    easing.type: Easing.OutQuint
                }
            }

            // Activate the inline field when the default lock entry is clicked.
            TapHandler {
                enabled: !root.inputMode
                onTapped: root.enterInputMode()
            }
        }

        // Keep the clock current without adding a second time source.
        Timer {
            interval: 1000
            repeat: true
            running: true
            triggeredOnStart: true
            onTriggered: root.now = new Date()
        }
    }

    // Keep release ownership in the animation completion path. Match the
    // launcher backdrop contract: the wave layers use the shorter 600ms
    // OutQuad sweep, while the launcher body has its own longer 800ms motion.
    NumberAnimation {
        id: enterAnimation
        target: root
        property: "waveProgress"
        from: 0
        to: 1
        duration: Lazer.MotionTokens.waveBackdropEnter
        easing.type: Easing.OutQuad
    }

    // Launcher parity: the body follows the longer panel motion and swallows
    // the backdrop after the shorter stretched-wave sweep has established it.
    NumberAnimation {
        id: entryBodyAnimation
        target: root
        property: "entryBodyProgress"
        from: 0
        to: 1
        duration: Lazer.MotionTokens.waveEnter
        easing.type: Easing.OutQuint
    }

    // Unlock reverses the same curtain on osu's hide easing (InSine); release
    // fires on landing.
    NumberAnimation {
        id: exitAnimation
        target: root
        property: "waveProgress"
        to: 0
        duration: Lazer.MotionTokens.waveExit
        easing.type: Easing.InSine
        // Keep the lock surface mapped for one compositor frame after the
        // wave reaches its hidden offset. Releasing in this callback can tear
        // down WlSessionLockSurface before Niri commits the final falling-wave
        // frame, which makes the wave disappear just short of the bottom.
        onFinished: exitReleaseSettleTimer.restart()
    }

    // Let the terminal wave position reach the compositor before unlocking the
    // session surface. This is deliberately outside allAnimations: it is a
    // post-animation release barrier, not another motion driver.
    Timer {
        id: exitReleaseSettleTimer
        interval: 32
        repeat: false
        onTriggered: root.requestRelease()
    }

    // Launcher parity: the body leaves on InQuad while the wave falls on
    // InSine. A shared progress value lets the body cover the stretched wave
    // too early, so keep its travel on its own clock.
    NumberAnimation {
        id: exitBodyAnimation
        target: root
        property: "exitBodyProgress"
        from: 1
        to: 0
        duration: Lazer.MotionTokens.waveExit
        easing.type: Easing.InQuad
    }

    // Content entry owner: a linear driver whose rise curve lives in
    // SurfaceLogic, so every block samples one curve. It spans the whole stagger
    // — the last block's own curve ends exactly when this does — so the rise is
    // one clock, not a clock plus a queue of timers. The wave does not wait on
    // it: the curtain and the content are two asynchronous motions, and the
    // wave's own landing is what the surface reports.
    NumberAnimation {
        id: entryContentAnimation
        target: root
        property: "entryContentProgress"
        from: 0
        to: 1
        duration: Lazer.MotionTokens.lockContentSpan
        easing.type: Easing.Linear
    }

    // Content fall owner: the same linear driver running down, so a block leaves
    // by the same journey it arrived on. The span covers every block's delayed
    // start, so the wave closes only after the trailing block has cleared the
    // bottom edge — nothing is left half-dropped behind the closing curtain.
    NumberAnimation {
        id: contentFallAnimation
        target: root
        property: "contentFallProgress"
        from: 0
        to: 1
        duration: Lazer.MotionTokens.lockContentSpan
        easing.type: Easing.Linear
        onFinished: root.startWaveExit()
    }

    Connections {
        id: contextConnections
        target: null
        function onUnlocked() {
            root.showUnlockFeedback()
        }

        // A failed conversation must hand keyboard focus straight back so
        // the next attempt can be typed without a pointer.
        function onShowFailureChanged() {
            if (root.lockContext && root.lockContext.showFailure) {
                root.authControlState = SurfaceLogic.authControlTransition(
                    root.authControlState, "auth-failure")
                root.enterInputMode()
                keyboardOwner.forceActiveFocus()
                if (root.reducedMotion)
                    authControl.failureOffset = 0
                else
                    failureAnimation.restart()
            }
        }
    }

    // The exit image may finish decoding after the content-fall animation. Keep
    // the lock surface intact until then, and start the same wave on the first
    // ready frame rather than letting a dark compositor clear frame intervene.
    Connections {
        target: backdrop
        function onExitDesktopReadyChanged() {
            if (root.exitWavePending && backdrop.exitDesktopReady)
                root.startWaveExit()
        }
    }
}
