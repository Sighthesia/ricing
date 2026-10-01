import QtQuick
import QtTest
import "../../modules/lazerbar" as Lazer
import "../../modules/lazerbar/RippleGlowLogic.js" as Glow

// Cover the shell's glow pulse: the geometry of one global ring, and the
// renderer's job of projecting it into a host and letting the clip mask it.
// The clock lives in RipplePulseService, which needs Quickshell and is covered
// by the root-level tst_glow_pulse.qml harness instead — so here the pulse is a
// plain stand-in the test drives directly, which also makes every geometry
// assertion deterministic instead of timing-dependent.
Item {
    id: host
    width: 800
    height: 600

    // Stand-in for RipplePulseService: the same surface the real one exposes.
    QtObject {
        id: fakePulse
        property int token: 0
        property bool active: false
        property real progress: 1
        property real originScreenX: 0
        property real originScreenY: 0
        property string pulseScreen: ""

        function matchesScreen(screen) {
            return pulseScreen === "" || pulseScreen === String(screen == null ? "" : screen)
        }
    }

    // A 1920x1080 bar, origin at its centre-top: the geometry the shared ring
    // is actually defined in.
    Lazer.RippleGlow {
        id: barGlow
        width: 1920
        height: 48
        pulse: fakePulse
        screenWidth: 1920
        screenHeight: 1080
    }

    // A 360x100 card elsewhere on the same screen. Same ring, different slice.
    Lazer.RippleGlow {
        id: cardGlow
        width: 360
        height: 100
        pulse: fakePulse
        screenWidth: 1920
        screenHeight: 1080
    }

    Lazer.RippleGlow {
        id: blockedGlow
        width: 360
        height: 100
        pulse: fakePulse
        screenWidth: 1920
        screenHeight: 1080
        glowEnabled: false
    }

    Lazer.RippleGlow {
        id: otherScreenGlow
        width: 640
        height: 48
        pulse: fakePulse
        screenName: "DP-1"
        screenWidth: 1920
        screenHeight: 1080
    }

    Lazer.RippleGlow {
        id: detachedGlow
        width: 200
        height: 60
    }

    // Reads the theme tokens through bindings, so a test that injects a
    // palette can watch them settle instead of reading a stale value.
    QtObject {
        id: themeProbe
        property color ring: Lazer.LazerTheme.glowPulseRing
        property color barBg: Lazer.LazerTheme.bgDark
        property color wash: Lazer.LazerTheme.flashWash
    }

    TestCase {
        name: "RippleGlow"
        when: windowShown

        // Start a new pulse, as the service does: bump the token, set the
        // origin, and reopen the clock.
        function pulseAt(x, y, screen) {
            fakePulse.originScreenX = x
            fakePulse.originScreenY = y
            fakePulse.pulseScreen = screen === undefined ? "" : screen
            fakePulse.progress = 0
            fakePulse.token += 1
            fakePulse.active = true
        }

        function seek(fraction) {
            fakePulse.progress = fraction
            fakePulse.active = true
        }

        function init() {
            Lazer.MotionTokens.reducedMotionOverride = false
            fakePulse.active = false
            fakePulse.progress = 1
            fakePulse.originScreenX = 0
            fakePulse.originScreenY = 0
            fakePulse.pulseScreen = ""
        }

        function cleanup() {
            Lazer.MotionTokens.reducedMotionOverride = false
            fakePulse.active = false
            fakePulse.progress = 1
            fakePulse.pulseScreen = ""
        }

        // --- the one ring ---

        function test_coverRadiusReachesTheFarthestCorner() {
            verify(Glow.coverRadius(960, 0, 1920, 1080) > 960)
            verify(Glow.coverRadius(960, 0, 1920, 1080) > 1080)
            compare(Glow.coverRadius(0, 0, 1920, 1080), Math.sqrt(1920 * 1920 + 1080 * 1080))
            compare(Glow.coverRadius(0, 0, 0, 1080), 0)
        }

        // The ring holds the old full-screen weight, in screen pixels, so every
        // host shows the same stroke rather than one fitted to its own height.
        function test_ringStrokeIsScreenScaleAndUnchanged() {
            compare(Glow.ringWidth(12), 14.048)
            compare(Glow.ringWidth(0), 14)
            compare(Glow.ringWidth(100000), Glow.MAX_RING_STROKE)
        }

        function test_travelEndsExactlyWhereTheRingClearsTheScreen() {
            var cover = Glow.coverRadius(960, 0, 1920, 1080)
            var travel = Glow.travelRadius(cover, Glow.MAX_RING_STROKE)
            // Cleared means the ring's inner edge has passed the cover radius,
            // on the last frame. Aiming further made it finish early and left
            // the rest of the clock drawing nothing.
            verify(travel - Glow.ringWidth(2 * travel) / 2 >= cover)
            verify(travel - Glow.ringWidth(2 * travel) / 2 - cover < 1)
        }

        function test_nothingLingersAtTheEndOfTheSweep() {
            var origins = [[960, 0], [0, 0], [5, 24], [1920, 1080], [960, 1080]]
            for (var i = 0; i < origins.length; i++) {
                var cover = Glow.coverRadius(origins[i][0], origins[i][1], 1920, 1080)
                var travel = Glow.travelRadius(cover, Glow.MAX_RING_STROKE)
                var stroke = Glow.ringWidth(2 * travel)
                // Clear on the final frame...
                verify(travel - stroke / 2 >= cover)
                // ...and not before, which would be dead tail.
                var before = Glow.ringDiameter(0.999, travel, 12) / 2
                verify(before - Glow.ringWidth(Glow.ringDiameter(0.999, travel, 12)) / 2 < cover)
            }
        }

        // One origin means one speed: equal progress steps cover equal ground,
        // so the ring never stalls on the way out.
        // The ring is screen-scale by contract, so the sweep has to spend itself
        // near the origin rather than spread evenly over a screen of radius, or
        // a small host is inside the ring for a handful of frames and reads as
        // nothing at all.
        function test_theSweepSpendsItselfNearTheOrigin() {
            var travel = Glow.travelRadius(Glow.coverRadius(5, 24, 1920, 1080), Glow.MAX_RING_STROKE)
            var early = Glow.ringDiameter(0.25, travel, 12) - Glow.ringDiameter(0, travel, 12)
            var late = Glow.ringDiameter(1, travel, 12) - Glow.ringDiameter(0.75, travel, 12)
            verify(early < late)
            // Front-loaded but still monotonic: no frame ever stands still.
            var previous = Glow.ringDiameter(0, travel, 12)
            for (var p = 0.05; p <= 1.0; p += 0.05) {
                var current = Glow.ringDiameter(p, travel, 12)
                verify(current > previous)
                previous = current
            }
            // And it still lands exactly on the display edge as the clock ends.
            compare(Glow.ringDiameter(1, travel, 12), 12 + (2 * travel - 12))
        }

        // The contract behind that curve, stated as the number that was measured
        // failing: on a 1920x1080 output, a 360px notification card has to be
        // inside the ring for a share of the sweep you can actually perceive.
        // Linear travel left it 150ms of a 900ms sweep.
        function test_aCardSizedHostIsLitForAPerceptibleShareOfTheSweep() {
            var travel = Glow.travelRadius(Glow.coverRadius(1888, 130, 1920, 1080),
                                           Glow.MAX_RING_STROKE)
            var cardWidth = 360
            // Where the ring's inner edge has cleared the card for good.
            var progress = 1
            for (var p = 0.01; p <= 1.0; p += 0.01) {
                if (Glow.ringDiameter(p, travel, 12) / 2 >= cardWidth) {
                    progress = p
                    break
                }
            }
            verify(progress > 0.25,
                   "a card-sized host is only inside the ring for "
                   + (progress * 100).toFixed(0) + "% of the sweep")
            // The curve must not be so strong that the ring stalls on screen.
            verify(progress < 0.75)
        }

        // The bands lag the leading edge, the halo further back, so the three
        // layers read as one edge with motion blur behind it.
        function test_bandsLagTheLeadingEdge() {
            var travel = 1000
            verify(Glow.haloDiameter(0.6, travel, 12) < Glow.trailDiameter(0.6, travel, 12))
            verify(Glow.trailDiameter(0.6, travel, 12) < Glow.ringDiameter(0.6, travel, 12))
            compare(Glow.haloDiameter(0.6, travel, 12), Glow.ringDiameter(0.55, travel, 12))
            compare(Glow.haloDiameter(0.01, travel, 12), 12)
        }

        function test_bandWidthsStayBands() {
            verify(Glow.trailWidth(14, 4000, 3000) < Glow.trailWidth(26, 4000, 3000))
            compare(Glow.trailWidth(26, 640, 48), 48 * 0.6)
            verify(Glow.trailWidth(14, 4, 2) >= 16)
            verify(Glow.haloWidth(26) < Glow.trailWidth(26, 4000, 3000))
            verify(Glow.haloWidth(14) >= 12)
        }

        // Nothing in the effect fades: brightness is constant, so the ring has
        // to leave by growing past the screen or it would cut off on screen.
        function test_brightnessIsConstant() {
            compare(Glow.RING_OPACITY, 1)
            compare(Glow.TRAIL_OPACITY, 0.5)
            compare(Glow.HALO_OPACITY, 0.25)
        }

        // --- the renderer as a mask ---

        function test_idleWithoutAPulse() {
            compare(detachedGlow.playing, false)
            compare(detachedGlow.visible, false)
            compare(barGlow.visible, false)
        }

        // The two hosts read the same clock and the same ring, and differ only
        // in where the origin lands inside them. That is the whole contract:
        // a card shows a slice of the ring the bar shows, not a smaller ring.
        function test_everyHostRendersTheSameRing() {
            pulseAt(960, 0, "")
            compare(barGlow.progress, 0)
            compare(cardGlow.progress, 0)
            compare(barGlow.cover, cardGlow.cover)
            compare(barGlow.travelRadius, cardGlow.travelRadius)
            // Same seed, same screen-scale geometry.
            compare(barGlow.originOnScreenX(), cardGlow.originOnScreenX())

            seek(0.5)
            verify(barGlow.progress > 0.4 && barGlow.progress < 0.6)
            compare(barGlow.progress, cardGlow.progress)

            fakePulse.active = false
            compare(barGlow.playing, false)
            compare(barGlow.visible, false)
        }

        // The origin is projected from screen coordinates into each host, so the
        // same ring reaches two surfaces at different places inside them. It is
        // read live, not latched to a token: a trigger that arrives mid-sweep is
        // coalesced rather than restarted, and a card sliding in while the ring
        // is already travelling must reveal the ring where it actually is rather
        // than miss the event.
        function test_originIsProjectedIntoEachHost() {
            // Two surfaces at different places on the same output, as the bar
            // and a notification card are.
            barGlow.hostScreenX = 100
            cardGlow.hostScreenX = 1400
            barGlow.hostScreenY = 0
            cardGlow.hostScreenY = 40

            // The ring starts far to the right of both.
            pulseAt(1200, 30, "")
            wait(0)
            // One ring, one screen origin...
            compare(barGlow.originOnScreenX(), 1200)
            compare(cardGlow.originOnScreenX(), 1200)
            // ...projected through each host's own place on the screen: a point
            // to the right of the bar and far to the left of the card.
            compare(barGlow.originX, 1200 - 100)
            compare(cardGlow.originX, 1200 - 1400)
            verify(barGlow.originX > 0)
            verify(cardGlow.originX < 0)
            compare(barGlow.originY, 30 - 0)
            compare(cardGlow.originY, 30 - 40)

            // A later trigger moves the ring for both hosts at once, and neither
            // has to re-latch anything to see it.
            fakePulse.originScreenX = 300
            fakePulse.token += 1
            wait(0)
            compare(barGlow.originX, 300 - 100)
            compare(cardGlow.originX, 300 - 1400)
        }

        // One shared clock means a pulse triggered anywhere would replay here,
        // so the screen tag is what keeps surfaces on other outputs quiet.
        function test_onlyThePulsesOwnScreenAnswers() {
            fakePulse.pulseScreen = "DP-1"
            pulseAt(0, 0, "DP-1")
            verify(otherScreenGlow.answersPulse)
            verify(otherScreenGlow.visible)
            verify(!barGlow.answersPulse)
            compare(barGlow.visible, false)

            // Untagged — a notification — is every screen's to answer.
            fakePulse.pulseScreen = ""
            verify(otherScreenGlow.answersPulse)
            verify(barGlow.answersPulse)
        }

        function test_disabledHostNeverShows() {
            seek(0.3)
            compare(blockedGlow.playing, true)
            compare(blockedGlow.visible, false)
        }

        // Reduced motion is a landing state, not a half-drawn ring.
        function test_reducedMotionHidesThePulse() {
            Lazer.MotionTokens.reducedMotionOverride = true
            seek(0.3)
            compare(barGlow.progress, 0.3)
            compare(barGlow.visible, false)
        }

        // The ring must out-read the surface it crosses, or the pulse reads as
        // a tint of the bar's own fill. It keeps a hint of the accent hue, so
        // the contract is "near-white", not "exactly white".
        function test_ringColorIsNearWhiteOnTheBuiltInPalette() {
            const ring = Lazer.LazerTheme.glowPulseRing
            verify(Math.min(ring.r, ring.g, ring.b) > 0.75)
            verify(luminance(ring) > 0.7)
        }

        // The real complaint: a wallpaper palette can be dark enough that a
        // plain lighten still sits near the bar's own value, and the pulse
        // then reads as a tint of the background. The ring is a near-white
        // blend of the accent, so it stays the brightest mark on whatever
        // surface it crosses.
        function test_ringColorOutreadsTheBarSurfaceOverADarkPalette() {
            Lazer.LazerTheme.settingsService = {
                appearance: { themeAdaptation: true, presetScheme: "" },
                effectiveColorScheme: "dark"
            }
            // A deliberately dark primary, and a complete palette so the rest
            // of LazerTheme stays resolvable while it is injected. The tokens
            // are bindings and need an event-loop turn to resolve against it;
            // flashWash is the sentinel, since it lightens to a violet over
            // this palette where the built-in fallback is plain white.
            Lazer.LazerTheme.colorService = darkPalette()
            tryVerify(function() { return String(themeProbe.wash) !== "#ffffff" }, 500)
            const ring = themeProbe.ring
            const bar = themeProbe.barBg
            Lazer.LazerTheme.settingsService = null
            Lazer.LazerTheme.colorService = null
            tryVerify(function() { return String(themeProbe.wash) === "#ffffff" }, 500)
            verify(!Lazer.LazerTheme.adapt)

            verify(Math.min(ring.r, ring.g, ring.b) > 0.75)
            verify(luminance(ring) > luminance(bar) * 5)
        }

        function luminance(color) {
            return 0.2126 * color.r + 0.7152 * color.g + 0.0722 * color.b
        }

        // Every token LazerTheme reads off the palette; a partial object would
        // leave the other colors undefined and spam the run with warnings.
        function darkPalette() {
            return {
                mPrimary: "#3A2CA8",
                mSurface: "#18171C",
                mOnSurface: "#FFFFFF",
                mOnSurfaceVariant: "#B8B4BC",
                mTertiary: "#00FFA2",
                mPrimaryContainer: "#302A42",
                mOutline: "#2E2C32",
                mSurfaceContainerLow: "#25222E",
                mSurfaceContainerHigh: "#282532",
                mSurfaceContainerHighest: "#322E3F"
            }
        }
    }
}
