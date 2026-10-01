import QtQuick
import Quickshell
import "./services" as Services
import "./modules/lazerbar" as Lazer

// Two notifications in a row.
//
// The single-card and bus contracts live in tst_glow_pulse.qml; what needs the
// real stack is the question of whether the *second* card ever gets a ring when
// it lands shortly after the first. A hand-placed card cannot answer that: the
// delegate path, the ListView's placement and the stack's own geometry are the
// thing under suspicion, so the harness mounts the actual stack and appends a
// real second row to the model.
Item {
    id: root

    property int failures: 0
    property int phase: 0
    property int tokenAtFirstRow: 0
    property int tokenAtSecondRow: 0

    function check(label, cond) {
        if (cond) {
            console.log("PASS:", label)
            return true
        }
        root.failures++
        console.log("FAIL:", label)
        return false
    }

    function finish() {
        console.log("Totals: " + (root.failures === 0 ? "all passed" : root.failures + " failed"))
        // The local Quickshell host exposes Qt.quit() without an exit code.
        Qt.quit()
    }

    // Where this harness's stack stands in, in screen coordinates. A
    // right-anchored notification host would report its own window-local zero
    // instead, which is the whole reason the hosts state this themselves.
    readonly property real hostX: 1400
    readonly property real hostY: 60

    // The model starts with one row; the second notification arrives later, the
    // way two messages do in real use.
    ListModel {
        id: rows
        ListElement { notifId: 1; appName: "A"; summary: "first"; body: ""; icon: "" }
    }

    Component {
        id: stackFactory

        Lazer.LazerNotificationStack {
            x: root.hostX
            y: root.hostY
            popupModel: rows
            glowPulse: Services.RipplePulseService
            glowEnabled: true
            screenWidth: 1920
            screenHeight: 1080
            hostScreenX: root.hostX
            hostScreenY: root.hostY
        }
    }

    property var stack: null
    // How long each card spent with the ring actually inside it, in ms. A card
    // is only painted while the ring's radius is smaller than the card, so this
    // is the number that decides whether a pass reads as a sweep or as nothing.
    property real firstLitMs: 0
    property real secondLitMs: 0

    // --- phase 2: the second notification lands ---

    function checkSecondCard() {
        const first = root.stack ? root.stack.cardAt(0) : null
        const second = root.stack ? root.stack.cardAt(1) : null
        root.check("the stack has two live cards", !!first && !!second)
        if (!first || !second) {
            root.phase = 9
            return
        }

        // The second card must be the thing that started this sweep. If it never
        // triggered, the ring on screen belongs to the first card and the second
        // one is dark however far the ring reaches.
        root.check("the second card triggered the sweep",
                   root.tokenAtSecondRow > root.tokenAtFirstRow)
        root.check("the second card was the one painted",
                   root.secondLitMs > 0)

        // How long each card was actually lit. The ring is sized against the
        // screen, so on a 360px card it is only inside for a fraction of the
        // sweep — and that fraction is the whole difference between a sweep and
        // a blink. Measured at 150ms out of 900ms, which is about seven frames
        // and read as nothing at all; hence a floor rather than a report.
        const sweep = Services.RipplePulseService.duration
        console.log("lit: first " + root.firstLitMs.toFixed(0) + "ms, second "
                    + root.secondLitMs.toFixed(0) + "ms of a " + sweep + "ms sweep")
        root.check("a card is lit for a perceptible share of the sweep",
                   root.secondLitMs >= sweep * 0.22,
                   "second card lit " + root.secondLitMs.toFixed(0) + "ms")
    }

    // A card is painted only while the ring is still inside it.
    function litFor() {
        if (!root.stack)
            return
        const first = root.stack.cardAt(0)
        const second = root.stack.cardAt(1)
        if (first && first.glowPlaying && first.glowRadius < first.width)
            root.firstLitMs += 40
        if (second && second.glowPlaying && second.glowRadius < second.width)
            root.secondLitMs += 40
    }

    Timer {
        interval: 40
        running: true
        repeat: true
        onTriggered: {
            // Mount the stack only once the earlier phases are done: its cards
            // trigger the shared pulse on entry, which would otherwise restart
            // the clock the other phases are watching.
            if (root.phase === 0) {
                root.stack = stackFactory.createObject(root)
                if (!root.stack) {
                    console.log("FAIL: the stack could not be mounted")
                    root.failures++
                    root.finish()
                    root.phase = 9
                    return
                }
                root.phase = 1
                return
            }
            // Wait for the first row's delegate to place itself and trigger.
            if (root.phase === 1) {
                const first = root.stack.cardAt(0)
                if (!first || !Services.RipplePulseService.active)
                    return
                root.check("the first card triggered the sweep",
                           Services.RipplePulseService.originScreenX > 0)
                root.tokenAtFirstRow = Services.RipplePulseService.token
                root.phase = 2
                return
            }
            if (root.phase >= 2)
                root.litFor()
            // The second message arrives once the first ring is well out across
            // the screen, so this is the mid-sweep case rather than a re-trigger
            // of a sweep that had not started.
            if (root.phase === 2) {
                if (Services.RipplePulseService.progress < 0.35)
                    return
                rows.append({ notifId: 2, appName: "B", summary: "second", body: "", icon: "" })
                root.phase = 3
                return
            }
            if (root.phase === 3) {
                const first = root.stack.cardAt(0)
                const second = root.stack.cardAt(1)
                if (!second || !second.openState)
                    return
                root.tokenAtSecondRow = Services.RipplePulseService.token
                // Checked here, while the pulse is still in flight: by the time
                // the sweep has run out the card has correctly stopped painting,
                // and asserting then would only be measuring the wrong moment.
                root.check("the second card is rendering the pulse", second.glowPlaying)
                const inner = second.width - second.cardRadius
                root.check("the ring lands on the second card, not past it",
                           second.glowOriginX >= inner - 1
                           && second.glowOriginX <= second.width)
                // Aimed at the second card's own entry edge, and below the first
                // card: the two are stacked, so only where the ring started tells
                // them apart. Asked here, while the rings are in flight, because
                // once they retire there is no origin left to ask about.
                const secondMidY = root.hostY + second.y + second.height / 2
                root.check("the sweep moved down to the second card",
                           Services.RipplePulseService.originScreenY >= secondMidY - 2)
                root.check("and away from the first",
                           Services.RipplePulseService.originScreenY
                           > root.hostY + first.height)
                // And it joined the first card's ring rather than replacing it:
                // asked here because once the rings retire there is nothing left
                // to count.
                root.check("its ring joined the one already crossing",
                           Services.RipplePulseService.rings.length >= 2)
                root.phase = 4
                return
            }
            // Let the second card's own sweep run out before measuring, or the
            // numbers only describe how long the harness happened to wait.
            if (root.phase === 4) {
                if (Services.RipplePulseService.active)
                    return
                root.phase = 5
            }
            if (root.phase === 5) {
                root.checkSecondCard()
                root.finish()
                root.phase = 9
            }
        }
    }
}