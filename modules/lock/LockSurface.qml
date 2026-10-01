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
    // Whether this request expects a pre-lock capture. The session-start lock
    // passes false, so its reveal is not gated on an image that will never exist.
    property bool captureExpected: true
    // Single reveal driver; the backdrop derives the trailing mask from it
    // so bands and wallpaper edge always move as one curtain.
    property real waveProgress: 0
    // Unlock fall driver: 0 keeps every content block in place, 1 has dropped
    // and faded all of them away. The wave sweep waits for it.
    property real contentFallProgress: 0
    property bool reducedMotion: Lazer.MotionTokens.reducedMotion
    property bool exitStarted: false
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
    // The password field occupies the control between the glyph inset and the
    // right inset. The masked bullets and the empty-field caret are both
    // centered on this one axis: the caret used to center on the whole control
    // instead, so an emptied field showed its mark 18px left of where the
    // bullets had been.
    readonly property real passwordTextLeftInset: 56
    readonly property real passwordTextRightInset: 20
    readonly property real passwordTextAxis: SurfaceLogic.passwordTextAxis(
        authControl.width, root.passwordTextLeftInset, root.passwordTextRightInset)
    readonly property color authControlColor: root.themeSnapshotReady
            ? root.lockThemeSnapshot.control
            : (root.lightScheme ? Lazer.LazerTheme.bgLight : Lazer.LazerTheme.settingsControlSurface)
    readonly property color authTextColor: root.themeSnapshotReady
            ? root.lockThemeSnapshot.text
            : SurfaceLogic.readableTextColor(Lazer.LazerTheme.accentColor, root.lightScheme)
    // Keep the lock glyph as an accent landmark instead of merging it with
    // the password text that occupies the same control.
    readonly property color authIconColor: root.themeSnapshotReady
            ? root.lockThemeSnapshot.icon
            : SurfaceLogic.clockThemeColor(Lazer.LazerTheme.accentColor,
                                           root.clockLuminance, root.lightScheme)
    readonly property color authDateColor: root.themeSnapshotReady
            ? root.lockThemeSnapshot.muted
            : (root.lightScheme ? "#5F5A66" : Lazer.LazerTheme.textMuted)
    readonly property real clockCenterX: clockLayout.ready ? clockLayout.centerX : 0.5
    readonly property real clockCenterY: clockLayout.ready ? clockLayout.centerY : 0.5
    readonly property real clockLuminance: clockLayout.ready ? clockLayout.luminance : 0.5
    readonly property color clockColor: root.themeSnapshotReady
            ? root.lockThemeSnapshot.clock
            : SurfaceLogic.clockThemeColor(Lazer.LazerTheme.accentColor,
                                           root.clockLuminance, root.lightScheme)
    readonly property color clockDateColor: root.themeSnapshotReady
            ? root.lockThemeSnapshot.clockMuted
            : SurfaceLogic.clockThemeMutedColor(Lazer.LazerTheme.accentColor,
                                                root.clockLuminance, root.lightScheme)
    readonly property bool authFailureVisible: root.lockContext
            ? root.lockContext.showFailure : false
    property date now: new Date()
    property bool inputMode: false

    signal releaseRequested()
    // Startup gating: a session-start surface prepares immediately but holds
    // its entry wave until the wallpaper reveal has settled and the bar chrome
    // has finished staging. Manual surfaces wave at once. The boolean records
    // that the wave began; the signal notifies the lock owner. The names stay
    // distinct because a property and a signal may not share one.
    property bool startupRequest: false
    property bool startupRevealAllowed: true
    property bool startupWaveStarted: false
    signal startupWaveStartedSignal()

    // The surface starts with the selected theme surface until the bands sweep
    // and unveil the wallpaper.
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
        })
        themeSnapshotReady = true
        exitStarted = false
        releaseSent = false
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

    // Startup entry: prepare now, wave only once the gates allow it. Called
    // from Component.onCompleted; the onStartupRevealAllowedChanged handler
    // below covers the closed-to-open transition afterwards.
    function tryStartReveal(): void {
        prepareReveal()
        if (!root.startupRequest || root.startupRevealAllowed)
            root.beginEntryWave()
    }

    // Start the 800ms enter animation via the bounded image wait. Runs once:
    // a repeat call after the wave began (gate flapping, second prepare) is a
    // no-op, and reduced motion has no wave to start.
    function beginEntryWave(): void {
        if (root.exitStarted || root.reducedMotion || root.startupWaveStarted)
            return
        root.startupWaveStarted = true
        revealStartTimer.restart()
        root.startupWaveStartedSignal()
    }

    // The unlock choreography runs in two beats: every content block drops away
    // on the notification fling, and only then does the wave close over the now
    // empty surface. The release still lands on the wave's own completion.
    function startExit(): void {
        if (exitStarted)
            return
        exitStarted = true
        if (reducedMotion) {
            contentFallProgress = 1
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
        exitAnimation.from = waveProgress
        exitAnimation.start()
    }

    function requestRelease(): void {
        if (releaseSent || !LockLogic.shouldReleaseLock("exiting", true))
            return
        releaseSent = true
        releaseRequested()
    }

    function allAnimations(): var {
        return [enterAnimation, exitAnimation, contentFallAnimation]
    }

    // One curve, one clock: the clock, the lock entry and the power row all
    // fall together on this single sample. The progress read stays in the
    // binding itself — a bare read from inside the JS helper is not part of the
    // capture set.
    readonly property var contentFall: SurfaceLogic.contentFallCurve(root.contentFallProgress)
    readonly property real fallDistance: Lazer.MotionTokens.lockContentFallDistance

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
        captureExpected: root.captureExpected
        progress: root.waveProgress
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
    }

    // Keep the screenshot visible for at least one settled frame before the
    // mask starts. If capture fails, the opaque floor still starts the reveal
    // after a bounded wait rather than exposing the wallpaper immediately.
    Timer {
        id: revealStartTimer
        interval: 250
        repeat: false
        onTriggered: {
            if (root.exitStarted || root.reducedMotion)
                return
            if (!backdrop.imagesReady && root.revealWaitTicks < 12) {
                root.revealWaitTicks += 1
                restart()
                return
            }
            // Retarget from the live value so a re-reveal never jumps.
            enterAnimation.from = root.waveProgress
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
        // The power row falls on the same curve as the rest of the content.
        opacity: 1 - root.contentFall.fade
        transform: Translate { y: root.contentFall.drop * root.fallDistance }
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
                spacing: 8
                // The clock and its date fall with everything else. The drop
                // rides a transform so the centered layout binding above stays
                // authoritative.
                opacity: 1 - root.contentFall.fade
                transform: Translate { y: root.contentFall.drop * root.fallDistance }

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
                BarWidgets.RollingClockTime {
                    id: clockTime
                    anchors.horizontalCenter: parent.horizontalCenter
                currentTime: root.now
                digitPixelSize: 48
                digitFontFamily: "monospace"
                digitBold: true
                showSeconds: false
                    digitColor: root.clockColor
                    mutedDigitColor: root.clockDateColor
                    separatorColor: root.clockColor
                hourTransitionDuration: Lazer.MotionTokens.clockHourFlip
                minuteTransitionDuration: Lazer.MotionTokens.clockMinuteFlip
                transitionEasing: Lazer.MotionTokens.clockFlipEasing
            }

            // Keep the calendar date directly below the primary time.
                Text {
                    id: clockDate
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDate(root.now, "yyyy.MM.dd")
                    color: root.clockDateColor
                    font.family: "monospace"
                    font.pixelSize: 16
                    Behavior on color {
                        enabled: !root.reducedMotion
                        ColorAnimation { duration: Lazer.MotionTokens.medium }
                    }
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
            // The failure shake and the unlock fall are separate offsets, so a
            // stale shake can never ride the drop away.
            transform: [
                Translate { x: authControl.failureOffset },
                Translate { y: root.contentFall.drop * root.fallDistance }
            ]
            opacity: 1 - root.contentFall.fade

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

            // Render the password without mounting a second keyboard owner.
            Text {
                id: passwordDisplay
                    anchors.fill: parent
                anchors.leftMargin: root.passwordTextLeftInset
                anchors.rightMargin: root.passwordTextRightInset
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                visible: root.inputMode && text.length > 0
                color: root.authTextColor
                font.family: "monospace"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                text: root.lockContext
                        ? SurfaceLogic.maskedPassword(root.lockContext.currentText) : ""
                Behavior on color {
                    enabled: !root.reducedMotion
                    ColorAnimation { duration: Lazer.MotionTokens.fast }
                }
            }

            // Empty focused field: a slim caret on the bullets' own axis. It
            // was a 12x6 pill centered on the whole control, which had the same
            // footprint as one masked character and sat left of the text, so a
            // cleared field read as a stray circle rather than a cursor.
            Rectangle {
                id: emptyPasswordMarker
                x: root.passwordTextAxis - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 18
                radius: 1.5
                color: root.authIconColor
                opacity: root.inputMode && keyboardOwner.activeFocus
                    && (!root.lockContext || root.lockContext.currentText.length === 0) ? 1 : 0
                visible: root.inputMode
                enabled: false
                Behavior on opacity {
                    enabled: !root.reducedMotion
                    NumberAnimation {
                        duration: Lazer.MotionTokens.fast
                        easing.type: Easing.OutQuint
                    }
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

    // Keep release ownership in the animation completion path.
    // One driver sweeps bands and trailing mask as a single curtain.
    NumberAnimation {
        id: enterAnimation
        target: root
        property: "waveProgress"
        from: 0
        to: 1
        duration: Lazer.MotionTokens.waveEnter
        easing.type: Easing.OutQuad
    }

    // Unlock reverses the same curtain; release fires on landing. Fast start
    // stays responsive while the gentle OutQuad tail settles the bands past
    // the edge instead of rushing them into it.
    NumberAnimation {
        id: exitAnimation
        target: root
        property: "waveProgress"
        to: 0
        duration: Lazer.MotionTokens.waveExit
        easing.type: Easing.OutQuad
        onFinished: root.requestRelease()
    }

    // Content fall owner: a plain linear driver whose gravity and fade shapes
    // live in SurfaceLogic, so every block samples one curve. Linear here is
    // deliberate — easing twice would bend the free-fall acceleration.
    NumberAnimation {
        id: contentFallAnimation
        target: root
        property: "contentFallProgress"
        from: 0
        to: 1
        duration: Lazer.MotionTokens.lockContentFall
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
}
