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
    // Single reveal driver; the backdrop derives the trailing mask from it
    // so bands and wallpaper edge always move as one curtain.
    property real waveProgress: 0
    property bool reducedMotion: Lazer.MotionTokens.reducedMotion
    property bool exitStarted: false
    property bool releaseSent: false
    property int revealWaitTicks: 0
    // Read the effective mode directly here. The lock surface can be created
    // before the shared theme palette has finished applying its new scheme.
    readonly property bool lightScheme: Services.SettingsService.effectiveColorScheme === "light"
    // Reveal foreground content at the instant the trailing wave edge starts
    // exposing the wallpaper; the content itself does not animate.
    readonly property bool foregroundRevealed: reducedMotion
            || SurfaceLogic.trailingRevealStarted(root.waveProgress, backdrop.maskDelay)
    readonly property real authInputWidth: Math.max(0, Math.min(360, root.width - 48))
    readonly property color authControlColor: root.lightScheme
            ? Lazer.LazerTheme.bgLight : Lazer.LazerTheme.settingsControlSurface
    readonly property color authTextColor: root.lightScheme
            ? "#211F24" : Lazer.LazerTheme.textPrimary
    readonly property color authDateColor: root.lightScheme
            ? "#5F5A66" : Lazer.LazerTheme.textMuted
    readonly property bool authFailureVisible: root.lockContext
            ? root.lockContext.showFailure : false
    property date now: new Date()
    property bool inputMode: false
    property bool syncingPasswordField: false

    signal releaseRequested()

    // The surface starts opaque with the pre-lock screenshot: the desktop
    // appears uninterrupted until the bands sweep and unveil the wallpaper.
    color: "transparent"

    function startReveal(): void {
        exitStarted = false
        releaseSent = false
        inputMode = false
        syncPasswordField()
        if (reducedMotion) {
            SurfaceLogic.applyRevealImmediately(root, allAnimations())
            return
        }
        SurfaceLogic.stopAll(allAnimations())
        revealWaitTicks = 0
        revealStartTimer.restart()
    }

    function startExit(): void {
        // PROBE-EXIT: temporary unlock-path timing probe, remove after diagnosis.
        console.log("[afloat:lock-exit-probe] startExit t=" + Date.now()
            + " waveProgress=" + waveProgress + " exitStarted=" + exitStarted
            + " reducedMotion=" + reducedMotion)
        if (exitStarted)
            return
        exitStarted = true
        if (reducedMotion) {
            SurfaceLogic.applyExitImmediately(root, allAnimations())
            requestRelease()
            return
        }
        SurfaceLogic.stopAll(allAnimations())
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
        return [enterAnimation, exitAnimation]
    }

    // Enter the inline authentication mode without changing PAM state.
    function enterInputMode(): void {
        inputMode = true
        passwordField.forceActiveFocus()
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
        root.syncPasswordField()
        keyboardOwner.forceActiveFocus()
        return true
    }

    // Synchronize external authentication changes without creating delete ghosts.
    function syncPasswordField(): void {
        if (!root.lockContext || !passwordField)
            return
        var nextText = root.lockContext.currentText == null
                ? "" : String(root.lockContext.currentText)
        if (passwordField.text === nextText)
            return
        syncingPasswordField = true
        passwordField.suppressDeleteFx = true
        passwordField.text = nextText
        passwordField.suppressDeleteFx = false
        syncingPasswordField = false
    }

    // Keep falling deletion feedback masked while preserving its motion.
    function maskPasswordGhosts(): void {
        var ghosts = passwordField.ghostLayerItem.children
        for (var i = 0; i < ghosts.length; i++) {
            if (ghosts[i])
                ghosts[i].text = "\u2022"
        }
    }

    onLockContextChanged: {
        contextConnections.target = lockContext
        syncPasswordField()
    }

    Component.onCompleted: {
        syncPasswordField()
        startReveal()
        keyboardOwner.forceActiveFocus()
    }

    LockBackdrop {
        id: backdrop
        anchors.fill: parent
        snapshotSource: root.snapshotUrl
        wallpaperSource: root.wallpaperPath
        progress: root.waveProgress
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

    // Keep session actions inside this compositor-owned surface.
    LockSessionMenu {
        id: sessionMenu
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 28
        anchors.bottomMargin: 28
        reducedMotion: root.reducedMotion
        sessionService: Services.SessionService
        entranceRevealed: root.foregroundRevealed
        z: 3.5
    }

    Connections {
        target: sessionMenu
        function onOpenChanged() {
            if (!sessionMenu.open)
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
            if (event.key === Qt.Key_Escape && sessionMenu.handleEscape()) {
                event.accepted = true
                return
            }
            if (event.key === Qt.Key_Escape && root.cancelInputMode()) {
                event.accepted = true
                return
            }
            if (!root.lockContext)
                return
            var isSubmit = event.key === Qt.Key_Return || event.key === Qt.Key_Enter
            var isBackspace = event.key === Qt.Key_Backspace
            var isPrintable = event.text && event.text.length === 1
            if (!isSubmit && !isBackspace && !isPrintable)
                return
            root.enterInputMode()
            if (isSubmit) {
                root.lockContext.submit()
                event.accepted = true
            } else if (isBackspace) {
                passwordField.text = passwordField.text.slice(0, -1)
                passwordField.cursorPosition = passwordField.text.length
                event.accepted = true
            } else if (isPrintable) {
                passwordField.text += event.text
                passwordField.cursorPosition = passwordField.text.length
                event.accepted = true
            }
        }
    }

    // Keep the clock and authentication control in one full-screen reveal layer.
    Item {
        id: authSurface
        anchors.fill: parent
        z: 3
        visible: root.foregroundRevealed
        enabled: root.foregroundRevealed

        // Keep the primary clock above the interaction control.
        Column {
            id: timeContent
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -parent.height * 0.18
            spacing: 8

            // Show hours and minutes with the shared rolling digit component.
            BarWidgets.RollingClockTime {
                anchors.horizontalCenter: parent.horizontalCenter
                currentTime: root.now
                digitPixelSize: 48
                digitFontFamily: "monospace"
                digitBold: true
                showSeconds: false
                digitColor: root.authTextColor
                mutedDigitColor: root.authTextColor
                separatorColor: root.authTextColor
                hourTransitionDuration: Lazer.MotionTokens.clockHourFlip
                minuteTransitionDuration: Lazer.MotionTokens.clockMinuteFlip
                transitionEasing: Lazer.MotionTokens.clockFlipEasing
            }

            // Keep the calendar date directly below the primary time.
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(root.now, "yyyy.MM.dd")
                color: root.authDateColor
                font.family: "monospace"
                font.pixelSize: 16
            }
        }

        // Keep the lock entry centered at the bottom in both visual states.
        Rectangle {
            id: authControl
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 56
            width: root.inputMode ? root.authInputWidth : 68
            height: 48
            radius: Lazer.LazerTheme.settingsChoiceRadius
            color: root.authControlColor
            border.width: root.authFailureVisible ? 2 : 1
            border.color: root.authFailureVisible ? Lazer.LazerTheme.osuPink
                                                   : Lazer.LazerTheme.divider
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
            transform: Translate { x: authControl.failureOffset }

            // Fade the lock glyph away as the same rectangle opens for input.
            Item {
                id: lockIconLayer
                anchors.fill: parent
                opacity: root.inputMode ? 0 : 1
                visible: opacity > 0.01
                Behavior on opacity {
                    enabled: !root.reducedMotion
                    NumberAnimation {
                        duration: Lazer.MotionTokens.medium
                        easing.type: Easing.OutQuint
                    }
                }

                // Load the shared lock glyph before applying the theme tint.
                Image {
                    id: lockIconSource
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    source: Qt.resolvedUrl("../lazerbar/icons/lock.svg")
                    fillMode: Image.PreserveAspectFit
                    visible: false
                }

                // Tint the white source glyph for both color schemes.
                MultiEffect {
                    anchors.fill: lockIconSource
                    source: lockIconSource
                    colorization: 1
                    colorizationColor: root.authTextColor
                    Behavior on colorizationColor {
                        enabled: !root.reducedMotion
                        ColorAnimation { duration: Lazer.MotionTokens.fast }
                    }
                }
            }

            // Reuse the launcher field for password masking, caret, and ghosts.
            Lazer.OsuTextField {
                id: passwordField
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                anchors.topMargin: 4
                anchors.bottomMargin: 4
                visible: root.inputMode || opacity > 0.01
                enabled: root.inputMode
                opacity: root.inputMode ? 1 : 0
                clip: true
                echoMode: TextInput.Password
                color: root.authTextColor
                selectionColor: Lazer.LazerTheme.osuPink
                font.family: "monospace"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                verticalAlignment: TextInput.AlignVCenter
                text: ""

                onTextChanged: {
                    if (root.syncingPasswordField || !root.lockContext)
                        return
                    if (root.lockContext.currentText !== text)
                        root.lockContext.currentText = text
                }
                onAccepted: {
                    if (root.lockContext)
                        root.lockContext.submit()
                }
                onGhostCountChanged: root.maskPasswordGhosts()
                Keys.onEscapePressed: event => {
                    event.accepted = root.cancelInputMode()
                }
                Behavior on opacity {
                    enabled: !root.reducedMotion
                    NumberAnimation {
                        duration: Lazer.MotionTokens.medium
                        easing.type: Easing.OutQuint
                    }
                }
            }

            // Keep the reusable caret legible against the active surface.
            Binding {
                target: passwordField.caretItem
                property: "color"
                value: root.authTextColor
            }

            // Show a non-text insertion marker only for an empty focused field.
            Rectangle {
                id: emptyPasswordMarker
                x: passwordField.x + passwordField.cursorRectangle.x
                y: passwordField.y + passwordField.cursorRectangle.y
                    + (passwordField.cursorRectangle.height - height) / 2
                width: 12
                height: 6
                radius: 3
                color: root.authTextColor
                opacity: root.inputMode && passwordField.activeFocus
                    && passwordField.text.length === 0 ? 1 : 0
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
        onStarted: console.log("[afloat:lock-exit-probe] exitAnimation started t=" + Date.now()
            + " from=" + from + " duration=" + duration)
        onFinished: {
            console.log("[afloat:lock-exit-probe] exitAnimation finished t=" + Date.now()
                + " waveProgress=" + root.waveProgress)
            root.requestRelease()
        }
    }

    Connections {
        id: contextConnections
        target: null
        function onUnlocked() {
            root.startExit()
        }

        // A failed conversation must hand keyboard focus straight back so
        // the next attempt can be typed without a pointer.
        function onShowFailureChanged() {
            if (root.lockContext && root.lockContext.showFailure) {
                root.enterInputMode()
                passwordField.forceActiveFocus()
                if (root.reducedMotion)
                    authControl.failureOffset = 0
                else
                    failureAnimation.restart()
            }
        }

        function onCurrentTextChanged() {
            root.syncPasswordField()
        }
    }
}
