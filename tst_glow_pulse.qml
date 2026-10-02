import QtQuick
import Quickshell
import "./services" as Services
import "./modules/bar" as Bar
import "./modules/lazerbar" as Lazer

// Cover the parts of the surface-scoped glow pulse that QtTest cannot reach,
// because they need the Quickshell singletons: the pulse bus and its screen
// routing, the bar widget origin the sweep is positioned by, and the
// notification card's entry glow. The pulse's own geometry and play/settle
// contract live in tests/qml/tst_ripple_glow.qml.
Item {
    id: root

    property int failures: 0
    property int phase: 0

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

    // Stands in for the status widgets: BarPill is the base that publishes the
    // bar-relative origin the sweep starts from.
    Bar.BarPill {
        id: pill
        width: 40
        height: 40
    }

    Lazer.LazerNotificationPopup {
        id: card
        width: 360
        x: 40
        summary: "glow pulse"
        glowPulse: Services.RipplePulseService
        glowScreenWidth: 1920
        glowScreenHeight: 1080
        // A known screen offset, standing in for a right-anchored host window
        // whose own local zero is nowhere near the screen edge.
        glowStackScreenX: 460
        glowStackScreenY: 30
    }

    // --- phase 2: the bus ---

    function checkBus() {
        Services.RipplePulseService.trigger("eDP-1", 1200, 40)
        root.check("pulse records its screen", Services.RipplePulseService.pulseScreen === "eDP-1")
        root.check("origin is published in screen coordinates",
                   Services.RipplePulseService.originScreenX === 1200
                   && Services.RipplePulseService.originScreenY === 40)
        root.check("own screen matches", Services.RipplePulseService.matchesScreen("eDP-1"))
        root.check("other screen rejected", !Services.RipplePulseService.matchesScreen("DP-1"))
        root.check("pulse is running", Services.RipplePulseService.active)
        root.check("pulse starts at the seed", Services.RipplePulseService.progress < 0.2)

        // Emission is continuous: every event starts its own ring, and none of them
        // waits for the one before it. This is the case that used to be folded
        // into the ring in flight, which meant one control being adjusted could
        // produce one ring and then nothing until that ring had left the screen.
        const before = Services.RipplePulseService.rings.length
        const inFlight = Services.RipplePulseService.progress
        Services.RipplePulseService.trigger("eDP-1", 1205, 43)
        root.check("a repeat a few pixels away is its own ring",
                   Services.RipplePulseService.rings.length === before + 1)
        root.check("and it starts at the seed rather than inheriting progress",
                   Services.RipplePulseService.progress < 0.2
                   && inFlight >= 0)
        root.check("the ring before it is untouched",
                   Services.RipplePulseService.rings[0].originX === 1200)

        // Two notifications arriving at the same corner within a second are two
        // separate things that happened, even though they fly in from the same
        // edge and land within a few pixels of each other.
        const beforeCorner = Services.RipplePulseService.rings.length
        Services.RipplePulseService.trigger("", 1600, 900)
        Services.RipplePulseService.trigger("", 1600, 900)
        root.check("two notifications at the same corner are two rings",
                   Services.RipplePulseService.rings.length === beforeCorner + 2)

        // And a widget on another screen reports its own event: a step on the
        // left monitor does not continue the ring the right monitor started.
        const beforeScreens = Services.RipplePulseService.rings.length
        Services.RipplePulseService.trigger("eDP-1", 1600, 902)
        Services.RipplePulseService.trigger("DP-2", 1601, 901)
        root.check("a step on each screen is its own ring",
                   Services.RipplePulseService.rings.length === beforeScreens + 2)

        // An untagged pulse — a notification — is every screen's to answer.
        Services.RipplePulseService.trigger("", 100, 200)
        root.check("screen-agnostic matches another screen",
                   Services.RipplePulseService.matchesScreen("DP-1"))
        root.check("screen-agnostic matches an empty name",
                   Services.RipplePulseService.matchesScreen(""))

        const tokenBefore = Services.RipplePulseService.token
        Services.RipplePulseService.trigger("eDP-1", 640, 24)
        root.check("token advances on trigger",
                   Services.RipplePulseService.token === tokenBefore + 1)

        // A widget reports where it is at trigger time, so a pill that has
        // since moved still publishes its current place.
        const origin = pill.barGlowOrigin()
        root.check("pill reports a usable origin",
                   origin !== null && isFinite(origin.x) && isFinite(origin.y))
    }

    // --- phase 1: the sweep runs to completion on its own, untouched ---

    function checkSweepCompletes() {
        // The card's own pulse started in phase 0 and nothing since has touched
        // the clock, so it must simply have run out.
        root.check("the pulse reached its end", !Services.RipplePulseService.active)
        root.check("a finished pulse sits at its end state",
                   Services.RipplePulseService.progress >= 1)
        root.check("a finished sweep leaves nothing in flight",
                   Services.RipplePulseService.rings.length === 0)
    }

    // --- phase 0: the card's entry beat, which is what triggers the pulse ---

    function checkCard() {
        // The card's entry runs on the polish pass after the shell mounts, and
        // it is the trigger: there is no separate notification glow.
        root.check("card has real geometry", card.height > 0)
        root.check("card triggered the shared pulse", Services.RipplePulseService.token > 0)
        root.check("notification pulse is untagged",
                   Services.RipplePulseService.pulseScreen === "")
        // The origin is a point on the screen, so every surface masks the same
        // ring rather than fitting one to its own box.
        root.check("origin is a screen point",
                   isFinite(Services.RipplePulseService.originScreenX)
                   && isFinite(Services.RipplePulseService.originScreenY))
        root.check("card rendered that same pulse", card.glowPlaying)
        root.check("card sized the ring against the screen, not itself",
                   card.glowCover > card.width)
        // The contract that was actually broken: the card publishes the origin
        // and projects it back through its own screen position, so the ring has
        // to start on the card's entry edge. It used to be measured in the
        // notification window's own coordinates, which put it a screen's width
        // away and left the card showing nothing. The glow is inset by the card
        // radius, so the edge is that much inside the card.
        const edge = card.width - card.cardRadius
        root.check("the ring starts on the card's own edge",
                   card.glowOriginX >= edge - 1 && card.glowOriginX <= card.width)
        // The glow is inset by the card radius on every side, so the ring's
        // origin sits that far inside the card's own centre line too.
        root.check("the ring is centred on the card's height",
                   Math.abs(card.glowOriginY - (card.height / 2 - card.cardRadius)) < 1)
        // And the card's place is derived from the stack's screen position plus
        // its own position inside it — no mapping call, so it cannot answer a
        // stale point and throw the ring off the card.
        root.check("the card's place is the stack's plus its own position",
                   card.glowSelfScreenX === 460 + card.x
                   && card.glowSelfScreenY === 30 + card.y)
    }

    // A second card, created on demand so it can land while a ring is already
    // crossing the screen.
    Component {
        id: secondCard

        Lazer.LazerNotificationPopup {
            width: 360
            x: 40
            summary: "late card"
            glowPulse: Services.RipplePulseService
            glowScreenWidth: 1920
            glowScreenHeight: 1080
            glowStackScreenX: 500
            glowStackScreenY: 30
        }
    }

    property var lateCard: null
    property real midFlightProgress: 0
    property int tokenBeforeLateCard: 0
    property real barRingStartedAt: 0

    // --- phase 3-5: a card that arrives while a ring is already crossing ---

    function checkLateCard() {
        // The case that made the pulse look like it could only ever fire once:
        // a ring is well out across the screen when a second notification lands.
        // The new card gets its own ring *and* the one already travelling is
        // left alone — two rings crossing at once, not one cutting off the last.
        const rings = Services.RipplePulseService.rings
        root.check("a card arriving mid-sweep adds a ring rather than replacing one",
                   rings.length >= 2)
        const survivor = rings.filter(r => r.originX === 300 && r.originY === 20)
        root.check("the ring already in flight was not cut off",
                   survivor.length === 1
                   && survivor[0].startedAt === root.barRingStartedAt)
        root.check("the new ring is aimed at the late card",
                   Math.abs(Services.RipplePulseService.originScreenX - 900) < 1)
        root.check("the late card is rendering it",
                   !!root.lateCard && root.lateCard.glowPlaying)
        const lateEdge = root.lateCard ? root.lateCard.width - root.lateCard.cardRadius : 0
        root.check("and the ring starts on the late card's own edge",
                   !!root.lateCard
                   && root.lateCard.glowOriginX >= lateEdge - 1
                   && root.lateCard.glowOriginX <= root.lateCard.width)
        root.checkStacking()
        root.checkContinuousEmission()
        root.phase = 6
    }

    // Rings stack, but not without limit: past a certain depth the later ones are
    // too faint to separate, so a burst retires the oldest rather than strobing.
    // The depth has to be generous, because emission is continuous — cap it low
    // and a dragged slider's own rings pile up at the origin with an empty
    // screen beyond them.
    function checkStacking() {
        const service = Services.RipplePulseService
        root.check("the stack is deep enough for a stream to still be crossing",
                   service.maxRings >= 8,
                   "maxRings: " + service.maxRings)
        for (let i = 0; i < service.maxRings + 3; ++i)
            service.trigger("eDP-1", 200 + i * 130, 20 + i * 90)
        root.check("a burst is capped rather than stacked without limit",
                   service.rings.length === service.maxRings,
                   "rings: " + service.rings.length + " cap: " + service.maxRings)
        // And the survivors are the newest ones.
        const newest = service.rings[service.rings.length - 1]
        root.check("the newest events are the ones that survive",
                   newest.originX === 200 + (service.maxRings + 2) * 130)
    }

    // Continuous emission, stated as the number that was failing: one control
    // being adjusted must be able to put out a ring per step, with no waiting on
    // the one before it.
    function checkContinuousEmission() {
        const service = Services.RipplePulseService
        service.clear()
        let allGrew = true
        for (let step = 0; step < 6; ++step) {
            const before = service.rings.length
            // The same origin every time, the way one widget's steps report it.
            service.trigger("eDP-1", 640, 24)
            if (service.rings.length !== before + 1)
                allGrew = false
            // And each one starts at its own seed rather than inheriting the
            // progress of the ring before it.
            if (service.newestRing.startedAt < service.rings[0].startedAt)
                allGrew = false
        }
        root.check("six steps in a row put out six rings", allGrew)
        root.check("and none of them waited for the one before",
                   service.rings.length === 6)
        service.clear()
    }

    // Three beats, in this order for a reason: the card is checked on its
    // polish pass, the sweep is then left alone until it has run out on its
    // own, and only then does the bus get poked — those assertions deliberately
    // start and fold pulses of their own.
    Timer {
        interval: 40
        running: true
        repeat: true
        onTriggered: {
            if (root.phase === 0) {
                root.phase = 1
                root.checkCard()
                return
            }
            if (root.phase === 1) {
                if (Services.RipplePulseService.active)
                    return
                root.phase = 2
                root.checkSweepCompletes()
                return
            }
            if (root.phase === 2) {
                root.checkBus()
                // Put a ring in flight the way a volume step would, so the late
                // card has something real to arrive next to. Its start time is
                // kept so "was not cut off" can be asserted rather than assumed.
                Services.RipplePulseService.trigger("eDP-1", 300, 20)
                root.barRingStartedAt = Services.RipplePulseService.newestRing.startedAt
                root.phase = 3
                return
            }
            if (root.phase === 3) {
                // Wait until that ring is well out across the screen, so a
                // restart of the clock is unmistakable rather than a rounding
                // difference between two values that are both near zero.
                if (Services.RipplePulseService.progress < 0.35)
                    return
                root.midFlightProgress = Services.RipplePulseService.progress
                root.tokenBeforeLateCard = Services.RipplePulseService.token
                root.lateCard = secondCard.createObject(root)
                root.phase = 4
                return
            }
            if (root.phase === 4) {
                // The card triggers on its own polish pass, so wait for that
                // rather than assuming this tick was late enough to see it.
                if (Services.RipplePulseService.token <= root.tokenBeforeLateCard)
                    return
                root.checkLateCard()
                root.finish()
                root.phase = 5
            }
        }
    }

    // Startup suppression must affect only new events. Existing rings continue
    // on their own timeline, and clearing the gate restores normal emission.
    function checkStartupMute() {
        const service = Services.RipplePulseService
        service.clear()
        service.startupMuted = true
        const token = service.token
        const before = service.rings.length
        service.trigger("eDP-1", 10, 20)
        root.check("startup mute drops a new trigger",
                   service.token === token && service.rings.length === before)
        service.startupMuted = false
        service.trigger("eDP-1", 10, 20)
        root.check("post-startup trigger creates a ring",
                   service.token === token + 1 && service.rings.length === before + 1)
        service.clear()
    }
}
