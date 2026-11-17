import QtQuick
import QtQuick.Effects
import QtQuick.Window
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
    // The plate is the launcher's boxed loading ring: that plate is 44px with
    // CornerRadius = edge/4 (LazerLoadingRingLogic.BOX_RADIUS_RATIO), and this
    // tile uses the same two numbers so the two round rectangles read as one
    // shape family. The glyph keeps that ring's own 0.6 scale on the plate.
    readonly property int actionTileSize: 160
    readonly property real actionTileRadius: actionTileSize * 0.25
    readonly property int glyphSize: Math.round(actionTileSize * 0.6)
    // The gap under the plate is its own number, not the column's: a name that
    // floats a full row-spacing below the tile reads as a caption of the screen
    // rather than as this tile's name.
    readonly property int labelGap: 12
    // Rasterise the glyph at the size it is actually painted at, on this
    // display's ratio. A vector icon loaded at its own 24px default and scaled
    // up to 96 is a 4x upscale, which is what made it soft at this size.
    readonly property real glyphRasterSize: root.glyphSize * Math.max(1, Screen.devicePixelRatio)
    readonly property int contentMaxWidth: 640
    readonly property int contentMargin: 32
    readonly property int contentSpacing: 20
    readonly property int footerMargin: 32
    // Input debounce, not motion: the Enter that activated the launcher row is
    // still in flight when this cover opens, and its auto-repeat would confirm a
    // shutdown before the question had been read. Nothing else is gated by it.
    readonly property int armingDelay: 250

    // ---- State ---------------------------------------------------------
    // True for the first armingDelay milliseconds of an opening; see armingDelay.
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
    // The action names itself; there is no question line. A prompt that asks
    // "Shut down?" above the one control that can only mean "shut down" says
    // the same thing twice, and the arming delay is what actually prevents a
    // mistimed key — not wording.
    readonly property string headline: root.actionLabel
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
    // The shell's own glyph set, not a second icon library: this cover is a
    // screen of the bar's shell, so its marks are the same white-stroke SVGs the
    // bar and the lock surface draw.
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
        root.armed = false
        armTimer.restart()
        root._actionAttempted = false
        root._rejectedText = ""

        if (root.phase === "closed") {
            root.bodyProgress = 0
            root.waveProgress = 0
            root.backdropProgress = 0
        }
        // Drop any composition the search editor was holding: this cover takes
        // the keyboard away from it, and an input method left mid-composition
        // replays the abandoned preedit into the editor when focus comes back —
        // which arrives as an Escape the launcher then reads as "close".
        Qt.inputMethod.reset()
        root.phase = "opening"
        openBackdrop.restart()
        openBody.restart()
        openWaves.restart()
        root.forceActiveFocus()
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
        // The same arming window guards a click: the pointer press that opened
        // the cover is not a confirmed answer either.
        if (!root.armed || !root.interactive || root.actionRunning)
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
        // The same reset on the way out, before the editor takes the keyboard
        // back: the cover never left a half-typed composition behind it.
        Qt.inputMethod.reset()
        root.phase = "closed"
        root.bodyProgress = 0
        root.waveProgress = 0
        root.backdropProgress = 0
        root.armed = false
        root.closed()
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
        case Qt.Key_Return:
        case Qt.Key_Enter:
            // The press that opened the cover is still arriving; see armingDelay.
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

            // The action itself: one tile holding its glyph, with the action's
            // name underneath. The tile is the answer — there is no second button
            // to choose between, so nothing here needs a selection state.
            Item {
                width: contentColumn.width
                height: plate.height + root.labelGap + labelText.implicitHeight

                // The plate: the launcher loading ring's rounded rectangle at the
                // same size and corner ratio, so the cover's control and the
                // shell's spinner read as one shape. It is the layout element, so
                // the name below it sits this close and no closer.
                Rectangle {
                    id: plate

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root.actionTileSize
                    height: root.actionTileSize
                    opacity: root.actionRunning ? MotionTokens.disabledOpacity : 1
                    radius: root.actionTileRadius
                    // `settingsSection`, not `settingsControlSurface`: the
                    // control rung sits within a hair of the curtain in the
                    // dark scheme, so the plate read as its own outline. This
                    // is the same one-step lift a section takes inside a panel.
                    color: tileHover.hovered ? LazerTheme.settingsCardHover
                                             : LazerTheme.settingsSection
                    border.width: 1
                    border.color: tileHover.hovered ? LazerTheme.focusRing
                                                    : LazerTheme.divider

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                    Behavior on border.color { ColorAnimation { duration: MotionTokens.fast } }
                }

                // Tinted so the white stroke set reads on either scheme.
                Image {
                    id: glyph
                    anchors.centerIn: plate
                    width: root.glyphSize
                    height: root.glyphSize
                    sourceSize.width: root.glyphRasterSize
                    sourceSize.height: root.glyphRasterSize
                    source: root.glyphSource
                    fillMode: Image.PreserveAspectFit
                    visible: false
                }

                MultiEffect {
                    anchors.fill: glyph
                    source: glyph
                    colorization: 1
                    colorizationColor: LazerTheme.osuPink
                }

                // Shared click flash: a flat wash that never changes the hit
                // target, drawn on the plate rather than the invisible target.
                ClickFlash {
                    id: flash
                    z: 10
                    anchors.fill: plate
                    radius: root.actionTileRadius
                }

                // The pointer target is deliberately larger than the plate, and
                // invisible: a target the size of the plate punishes every press
                // that is not dead centre. It is centred on the plate and takes no
                // part in the layout, so it cannot push the name away.
                Item {
                    id: actionTarget

                    anchors.centerIn: plate
                    width: root.actionTileSize * 2
                    height: root.actionTileSize * 2
                    enabled: !root.actionRunning

                    Accessible.role: Accessible.Button
                    Accessible.name: root.actionLabel

                    HoverHandler { id: tileHover }

                    // A click goes through the same arming window as Enter, so the
                    // press that opened the cover cannot confirm it either.
                    TapHandler {
                        onTapped: {
                            if (!actionTarget.enabled || !root.armed)
                                return
                            flash.restart()
                            root.confirm()
                        }
                    }
                }

                // The action's name under the plate.
                Text {
                    id: labelText
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: plate.bottom
                    anchors.topMargin: root.labelGap
                    text: root.headline
                    color: LazerTheme.textPrimary
                    font.pixelSize: 24
                    font.weight: Font.DemiBold
                }
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
        }

        // Bottom line: the two keys that answer. Enter confirms, Esc backs out;
        // there is nothing to move between, so no third legend.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.footerMargin
            spacing: 20
            opacity: root.contentReveal

            PowerKeyHint { keys: ["Enter"]; caption: Services.Tr.q("common.confirm") }
            PowerKeyHint { keys: ["Esc"]; caption: Services.Tr.q("common.cancel") }
        }
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
    // A command that asks nothing (sleep) has no key to wait for: it runs the
    // moment the window closes, so the cover is never an unanswerable question.
    Timer {
        id: armTimer
        interval: root.armingDelay
        repeat: false
        onTriggered: {
            root.armed = true
            if (!root.requiresConfirmation)
                root.confirm()
        }
    }
}
