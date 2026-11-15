import QtQuick
import QtQuick.Effects
import "../../services" as Services

// Full-screen confirmation cover for the launcher's session commands.
//
// It is painted by the launcher window itself, above the wave surface, because
// two layer-shell surfaces in one layer cannot be ordered against each other:
// the cover has to sit above the wave it interrupts, so it has to be a layer of
// that same surface rather than a window of its own. It is a cover and not a
// panel — for as long as a destructive command waits for an answer the whole
// screen belongs to the question.
//
// The choreography is the launcher wave's own, reused rather than re-invented:
// the same four-band `WaveRevealLayers` sweep over `LazerTheme.wavePalette`, the
// same opaque body rising from two screen heights and swallowing the bands
// (`WaveSurfaceHost.body`), the same `MotionTokens` wave timings and easings.
// The question itself is read off that body's progress, so the cover keeps no
// clock of its own and can never drift from the curtain carrying it.
Item {
    id: root

    // ---- Contract the launcher surface drives ---------------------------
    property string actionId: ""
    property bool requiresConfirmation: true
    property string phase: "closed"
    property var sessionService: null
    readonly property bool active: phase !== "closed"

    signal closed()

    // ---- Geometry ------------------------------------------------------
    readonly property int glyphSize: 56
    readonly property int contentMaxWidth: 640
    readonly property int contentMargin: 32
    readonly property int contentSpacing: 24
    readonly property int buttonWidth: 180
    readonly property int buttonSpacing: 16
    readonly property int footerMargin: 32
    // Input debounce, not motion: the Enter that activated the launcher row is
    // still in flight when this cover opens, and its auto-repeat would confirm a
    // shutdown before the question had been read. Nothing else is gated by it.
    readonly property int armingDelay: 250

    // ---- State ---------------------------------------------------------
    property string selection: "confirm"
    // False for the first armingDelay milliseconds of an opening; see armingDelay.
    property bool armed: false
    property real bodyProgress: 0
    property real waveProgress: 0
    property real backdropProgress: 0
    // Set once this cover has asked the service to run something. Until then the
    // service's last message belongs to an earlier action and is not shown.
    property bool _actionAttempted: false
    // A refusal this cover has to report itself: execute() returning false sets
    // no service message, so without this the question would sit there silently.
    property string _rejectedText: ""

    readonly property bool interactive: phase === "opening" || phase === "open"
    readonly property bool actionRunning: root.sessionService
            ? root.sessionService.running === true : false
    readonly property string actionLabel: root.actionId === ""
            ? "" : Services.Tr.q("lock.action." + root.actionId)
    // Sleep asks nothing: the action's own name is the whole message and the
    // status line below reports how it is going.
    readonly property string headline: root.requiresConfirmation
            ? Services.Tr.q("lock.confirm", { action: root.actionLabel })
            : root.actionLabel
    readonly property bool statusIsError: root._rejectedText !== ""
            || (root.sessionService
                ? String(root.sessionService.errorText || "") !== "" : false)
    readonly property string statusText: {
        if (!root._actionAttempted)
            return ""
        // A refusal of our own is the freshest fact: `execute()` returning false
        // leaves the service's previous message untouched, and showing that
        // instead would blame the wrong action.
        if (root._rejectedText !== "")
            return root._rejectedText
        if (root.sessionService) {
            const error = String(root.sessionService.errorText || "")
            if (error !== "")
                return error
            const result = String(root.sessionService.resultText || "")
            if (result !== "")
                return result
        }
        if (root.actionRunning)
            return Services.Tr.q("lock.action.requested", { action: root.actionLabel })
        return ""
    }
    // The action's own glyph, out of the shell's stroke set.
    readonly property url glyphSource: {
        switch (root.actionId) {
        case "suspend": return Qt.resolvedUrl("icons/suspend.svg")
        case "reboot": return Qt.resolvedUrl("icons/reboot.svg")
        case "shutdown": return Qt.resolvedUrl("icons/power.svg")
        case "logout": return Qt.resolvedUrl("icons/logout.svg")
        }
        return ""
    }
    // The curtain is nearly home before the question starts landing, so the text
    // arrives as part of the body's gesture instead of on a second animation.
    readonly property real contentReveal: Math.max(0, Math.min(1, (root.bodyProgress - 0.7) / 0.3))

    visible: root.active && root.actionId !== ""
    enabled: root.visible
    focus: root.active
    // Above every launcher layer this cover interrupts, including the exit-card
    // layer above the wave.
    z: 200

    // ---- Driving functions ---------------------------------------------

    // Signature is the launcher surface's contract; QML spells parameter types
    // after the name, so `open(id: string, needsConfirmation: bool)`.
    function open(id: string, needsConfirmation: bool): void {
        const next = String(id || "")
        if (next === "")
            return

        openBody.stop()
        openWaves.stop()
        closeBody.stop()
        closeWaves.stop()

        root.actionId = next
        root.requiresConfirmation = needsConfirmation === true
        // Confirm is preselected: the lock screen's arm-then-confirm rhythm puts
        // the destructive answer under the key the user already pressed, and the
        // arming window is what stops that from being an accident.
        root.selection = "confirm"
        root.armed = false
        armTimer.restart()
        root._actionAttempted = false
        root._rejectedText = ""

        if (root.phase === "closed") {
            root.bodyProgress = 0
            root.waveProgress = 0
            root.backdropProgress = 0
        }
        root.phase = "opening"
        openBackdrop.restart()
        openBody.restart()
        openWaves.restart()
        root.forceActiveFocus()

        // Sleeping asks nothing, so it runs straight through the cover.
        if (!root.requiresConfirmation)
            root.confirm()
    }

    function close(): void {
        if (!root.interactive)
            return
        openBody.stop()
        openWaves.stop()
        armTimer.stop()
        root.phase = "closing"
        closeBackdrop.restart()
        closeBody.restart()
        closeWaves.restart()
    }

    // Run the pending action once. The service owns the command; this cover only
    // gates the double-press and keeps the outcome visible.
    function confirm(): void {
        if (!root.interactive || root.actionRunning)
            return
        root._rejectedText = ""
        root._actionAttempted = true
        if (root.sessionService && root.sessionService.execute(root.actionId) === true)
            return
        // Nothing started — unknown, unavailable, or already in flight — so no
        // service message is coming and the cover has to say it.
        root._rejectedText = Services.Tr.q("lock.actionFailed")
    }

    function finishClose() {
        root.phase = "closed"
        root.bodyProgress = 0
        root.waveProgress = 0
        root.backdropProgress = 0
        root.armed = false
        root.closed()
    }

    // Only a question has two answers; the sleep path has nothing to move between.
    function selectAnswer(answer) {
        if (!root.requiresConfirmation)
            return
        root.selection = answer
    }

    function handleKey(event) {
        // Exclusive while up: no key may reach the launcher behind the curtain.
        event.accepted = true
        if (!root.interactive)
            return
        switch (event.key) {
        case Qt.Key_Escape:
            root.close()
            break
        case Qt.Key_Left:
            root.selectAnswer("cancel")
            break
        case Qt.Key_Right:
            root.selectAnswer("confirm")
            break
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            root.selectAnswer(root.selection === "confirm" ? "cancel" : "confirm")
            break
        case Qt.Key_Return:
        case Qt.Key_Enter:
            // The press that opened the cover is still arriving; see armingDelay.
            if (!root.armed || !root.requiresConfirmation)
                break
            if (root.selection === "cancel")
                root.close()
            else
                root.confirm()
            break
        }
    }

    Keys.onPressed: event => root.handleKey(event)

    // Hold the keyboard for the whole life of the cover: the wave host restores
    // focus to its opener when its own closing animation ends, which lands after
    // this cover opened on the sleep path.
    onActiveFocusChanged: {
        if (root.active && root.visible && !root.activeFocus)
            root.forceActiveFocus()
    }

    // ---- Layers --------------------------------------------------------

    // Dim the launcher underneath before the bands arrive.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.backdropProgress * MotionTokens.backdropOpacity
    }

    // The shared four-band sweep, full-bleed because this cover is full-screen.
    WaveRevealLayers {
        progress: root.waveProgress
        palette: LazerTheme.wavePalette
    }

    // Swallow pointer and wheel input the cover does not use, so nothing behind
    // the curtain can be scrolled or clicked through the dimmed area.
    MouseArea {
        anchors.fill: parent
        enabled: root.active
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onWheel: wheel => wheel.accepted = true
    }

    // The opaque curtain. It travels two screen heights like the launcher's own
    // body, so the bands sweep visibly first and the cover follows and swallows
    // them; reduced motion keeps the fade and drops the travel.
    Rectangle {
        id: body
        z: 5
        x: 0
        y: MotionTokens.reducedMotion ? 0 : root.height * 2 * (1 - root.bodyProgress)
        width: root.width
        height: root.height
        radius: 0
        color: LazerTheme.overlayContentSurface
        opacity: MotionTokens.reducedMotion ? root.bodyProgress : 1

        // The question block, centred on the curtain and riding its progress.
        Column {
            id: contentColumn
            anchors.centerIn: parent
            width: Math.max(0, Math.min(parent.width - 2 * root.contentMargin, root.contentMaxWidth))
            spacing: root.contentSpacing
            opacity: root.contentReveal
            transform: Translate {
                y: MotionTokens.reducedMotion ? 0 : MotionTokens.overlayFromY * (1 - root.contentReveal)
            }

            // Action glyph, tinted so the white stroke set reads on either scheme.
            Item {
                width: contentColumn.width
                height: root.glyphSize

                Image {
                    id: glyph
                    anchors.centerIn: parent
                    width: root.glyphSize
                    height: root.glyphSize
                    source: root.glyphSource
                    fillMode: Image.PreserveAspectFit
                    visible: false
                }

                MultiEffect {
                    anchors.fill: glyph
                    source: glyph
                    colorization: 1
                    colorizationColor: LazerTheme.textPrimary
                }
            }

            // The question itself: the confirmation prompt, or the action's name
            // when it needs no confirmation.
            Text {
                width: contentColumn.width
                text: root.headline
                color: LazerTheme.textPrimary
                font.pixelSize: 24
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            // Running / result / failure line. Laid out even when empty: a line
            // that appeared later would shift the centred block under the pointer.
            Text {
                width: contentColumn.width
                text: root.statusText
                color: root.statusIsError ? LazerTheme.osuPink : LazerTheme.textMuted
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
            }

            // The two answers. Absent on the sleep path, which asks nothing.
            Item {
                width: contentColumn.width
                height: buttonRow.height
                visible: root.requiresConfirmation

                Row {
                    id: buttonRow
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: root.buttonSpacing

                    // Backing out is never destructive, so it carries no warning.
                    ChoiceButton {
                        width: root.buttonWidth
                        height: LazerTheme.settingsControlHeight
                        text: Services.Tr.q("common.cancel")
                        highlighted: root.selection === "cancel"
                        onActivated: root.close()
                    }

                    // The destructive answer: pink border, and refused while the
                    // service is already running the command.
                    ChoiceButton {
                        width: root.buttonWidth
                        height: LazerTheme.settingsControlHeight
                        text: Services.Tr.q("common.confirm")
                        destructive: true
                        highlighted: root.selection === "confirm"
                        enabled: !root.actionRunning
                        opacity: enabled ? 1 : MotionTokens.disabledOpacity
                        onActivated: root.confirm()
                    }
                }
            }
        }

        // Bottom line: the keys this cover answers to, drawn as keys. A sentence
        // spelled out in prose makes the reader find the key inside it; keycaps
        // read as keys at a glance.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.footerMargin
            spacing: 20
            opacity: root.contentReveal

            PowerKeyHint { keys: ["Enter"]; caption: Services.Tr.q("common.confirm") }
            PowerKeyHint { keys: ["Esc"]; caption: Services.Tr.q("common.cancel") }
            PowerKeyHint { keys: ["←", "→"]; caption: Services.Tr.q("power.switch") }
        }
    }

    // One answer button. Surface, hover wash, focus ring and click flash are the
    // settings panel's own patterns, reused instead of re-drawn here.
    component ChoiceButton: Item {
        id: choice

        property string text: ""
        // The confirm answer is destructive: its label says so before hover or
        // focus adds anything.
        property bool destructive: false
        // Keyboard selection, not `Item.focus`: the cover owns the focus item
        // and every key, so the answers are marked rather than focused.
        property bool highlighted: false
        readonly property bool hovered: hover.hovered

        signal activated()

        Accessible.role: Accessible.Button
        Accessible.name: choice.text

        function activate() {
            if (!choice.enabled)
                return
            flash.restart()
            choice.activated()
        }

        // Control surface at rest, the shared hover wash while pointed at.
        Rectangle {
            anchors.fill: parent
            radius: LazerTheme.settingsChoiceRadius
            color: choice.hovered ? LazerTheme.hoverFill : LazerTheme.settingsControlSurface
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        // One ring, two states: a hairline that defines the surface at rest, the
        // focus ring once the answer is selected. The destructive answer used to
        // carry a pink ring of its own, which put two rings on the same rectangle
        // whenever it was selected and left a second selected-looking frame
        // whenever it was not; the danger now rides the label instead.
        Rectangle {
            anchors.fill: parent
            radius: LazerTheme.settingsChoiceRadius
            color: "transparent"
            border.width: choice.highlighted ? 1.5 : 1
            border.color: choice.highlighted ? LazerTheme.focusRing : LazerTheme.divider
            enabled: false

            Behavior on border.width { NumberAnimation { duration: MotionTokens.fast } }
            Behavior on border.color { ColorAnimation { duration: MotionTokens.fast } }
        }

        Text {
            anchors.centerIn: parent
            text: choice.text
            color: choice.destructive ? LazerTheme.osuPink : LazerTheme.textPrimary
            font.pixelSize: 14
            font.weight: Font.DemiBold

            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        // Shared click flash: a flat wash that never changes the hit target.
        ClickFlash {
            id: flash
            z: 10
            anchors.fill: parent
            radius: LazerTheme.settingsChoiceRadius
        }

        HoverHandler { id: hover; enabled: choice.enabled }
        TapHandler { enabled: choice.enabled; onTapped: choice.activate() }
    }

    // ---- Motion --------------------------------------------------------
    //
    // The wave host's numbers, straight: the body lands on OutQuint while the
    // bands run shorter on OutQuad so the fan stays ahead of the panel, and both
    // leave on the same exit duration with the body leading.

    NumberAnimation {
        id: openBody
        target: root
        property: "bodyProgress"
        to: 1
        duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveEnter
        easing.type: Easing.OutQuint
        onFinished: if (root.phase === "opening") root.phase = "open"
    }
    NumberAnimation {
        id: openWaves
        target: root
        property: "waveProgress"
        to: 1
        duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveBackdropEnter
        easing.type: Easing.OutQuad
    }
    NumberAnimation {
        id: closeBody
        target: root
        property: "bodyProgress"
        to: 0
        duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveExit
        easing.type: Easing.InQuad
        onFinished: if (root.phase === "closing") root.finishClose()
    }
    NumberAnimation {
        id: closeWaves
        target: root
        property: "waveProgress"
        to: 0
        duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.waveExit
        easing.type: Easing.InSine
    }
    // The dim is a short separate beat, so the screen darkens before the bands
    // move and lifts first on the way out.
    NumberAnimation {
        id: openBackdrop
        target: root
        property: "backdropProgress"
        to: 1
        duration: MotionTokens.reducedMotion ? MotionTokens.fast : MotionTokens.backdropEnter
        easing.type: Easing.BezierSpline
        easing.bezierCurve: MotionTokens.outSoft
    }
    NumberAnimation {
        id: closeBackdrop
        target: root
        property: "backdropProgress"
        to: 0
        duration: MotionTokens.fast
        easing.type: Easing.BezierSpline
        easing.bezierCurve: MotionTokens.outSoft
    }

    // Blocks the Enter that opened the cover, then hands Enter back to the user.
    Timer {
        id: armTimer
        interval: root.armingDelay
        repeat: false
        onTriggered: root.armed = true
    }
}
