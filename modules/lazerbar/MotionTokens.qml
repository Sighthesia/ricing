pragma Singleton
import QtQuick

// Keep all interaction motion on one explicit timing system.
QtObject {
    property bool reducedMotionOverride: false
    readonly property bool reducedMotion: reducedMotionOverride

    readonly property int instant: 70
    readonly property int fast: 100
    readonly property int medium: 160
    readonly property int slow: 240
    readonly property int page: 320
    readonly property int backdropEnter: 120

    // osu!lazer WaveContainer APPEAR/DISAPPEAR durations: body and backdrop
    // waves share one duration; their easings differ at the call site
    // (body OutQuint, waves OutSine / InSine).
    readonly property int waveEnter: 800
    readonly property int waveExit: 500
    // Backdrop waves run shorter than the body so the fan stays ahead of the
    // fast-starting panel: with equal durations the OutQuint panel lands early
    // and swallows the lower (darker) layers mid-transition.
    readonly property int waveBackdropEnter: 600

    // Lock-screen content: the clock, the lock control and the power row enter
    // and leave on a stagger rather than as one block, so the surface reads as
    // a wave crossing three layers instead of everything moving together. Each
    // block reads its own delayed start of one shared span, and the two
    // directions read that span in opposite orders, so they are two waves rather
    // than one played backwards.
    //
    // Both directions are pure position moves — nothing fades in or out. The
    // travel is the same journey in both directions: a block starts and ends
    // completely below the surface's bottom edge, so an entrance rises off that
    // edge to its place and an exit drops back through it. The distance is
    // therefore derived per block from its own geometry (see
    // LockSurface.travelBelow); a shared number cannot work, since the clock has
    // to cross most of the output while the bottom row barely clears its own
    // height.
    //
    // `lockContentTravel` covers that whole cross-output distance, so it is
    // longer than a small-surface move; `lockContentSpan` adds the stagger tail
    // of the two blocks that start last.
    readonly property int lockContentTravel: 520
    // Delay step between neighbouring blocks.
    readonly property int lockContentStagger: 100
    readonly property int lockContentStaggerSpan: 2 * lockContentStagger
    readonly property int lockContentSpan: lockContentTravel + lockContentStaggerSpan

    // Wallpaper swaps are large-surface reveals; keep them calm but not slow.
    readonly property int wallpaperSwap: 480
    // Exit desktop decoding happens after authentication and before the closing
    // wave may start. Keep that bounded wait outside the motion duration so a
    // slow synchronous image decode cannot make the lock release mid-wave.
    readonly property int lockExitDesktopWait: 1200
    // The boot reveal is a separate contract from a live switch. Its DURATION is
    // DymicShell's: 3000ms, its `Math.round(3000 / speedFactor)` at the default
    // speedFactor of 1.0 (DymicShell/modules/background/BackgroundWindow.qml).
    // A long open is deliberate — it lets the shell finish mounting underneath
    // the circle instead of being caught mid-reveal.
    //
    // Its CURVE is a local choice, not a port: InQuad, which starts slow and
    // accelerates all the way out with no deceleration tail. DymicShell's
    // InOutSine eases back off at the end, which reads as settling; this one
    // commits. Startup deliberately also skips DymicShell's fixed 150ms black
    // hold — this shell waits for the wallpaper's own pixels instead of a
    // guessed delay, and re-adding a fixed hold would undo that.
    // Reference: DymicShell, MIT.
    readonly property int wallpaperBootReveal: 3000
    readonly property int wallpaperBootRevealEasing: Easing.InQuad
    readonly property int waveRoute: 160
    readonly property int settingsSlide: 600
    readonly property int settingsContentDelay: 200
    readonly property int settingsSidebarFade: 500
    readonly property int settingsSidebarStagger: 40
    readonly property int settingsSidebarCollapse: 300

    // Settings overlay timings remain explicit so the host geometry never animates.
    readonly property int settingsEnter: 320
    readonly property int settingsExit: 240
    readonly property int settingsScrim: 180
    readonly property int settingsCategory: 160

    // Settings control timings follow osu!lazer's Nub/Slider/Outline contracts.
    readonly property int nubMorph: 200
    readonly property int nubHover: 40
    readonly property int nubGlow: 800
    readonly property int sliderNubMove: 250
    readonly property int sliderTickBumpReturn: 220
    readonly property int clickFlashDuration: 800
    readonly property int clickFlashEasing: Easing.OutQuint
    // Spectrum beat-wave sweep across its host surface.
    readonly property int beatWave: 400
    // Surface-scoped glow pulse (the pre-lazer full-screen ripple, re-hosted on
    // the notification card and the bar). Shorter than the old 1800ms screen
    // sweep: it now crosses one small surface, not the display.
    readonly property int glowSweep: 700
    // Flip-clock rolling digits ported from the pre-lazer bar (main branch
    // RollingClockTime.qml): slow gliding rolls paced at the old
    // Motion.color.transitionDuration (300) x 8/4/1 with OutCubic easing.
    readonly property int clockHourFlip: 2400
    readonly property int clockMinuteFlip: 1200
    readonly property int clockSecondFlip: 300
    readonly property int clockFlipEasing: Easing.OutCubic
    // Tray icons wear the text transition's numbers: a leaving icon drops and
    // dissolves on the delete-ghost clock, an arriving one fades in on the scan
    // reveal. Each icon's slot opens before its ink starts (MotionTokens.fast)
    // and closes after the ink is gone (MotionTokens.slow), so a neighbouring
    // icon can never slide across a half-drawn one.
    readonly property int trayIconEnter: 140
    readonly property int trayIconExit: 200
    // Window hint slots and workspace icons use compact list motion.
    // Match MarqueeLabel's scan reveal and removed-glyph ghost.
    readonly property int windowListReveal: 140
    readonly property int windowListFall: 200
    // Exit uses the menu's scale/fade recipe; live slots wait before closing over it.
    readonly property int windowGhostExit: slow
    readonly property int windowGhostSlotDelay: fast
    readonly property real windowGhostScale: popupFromScale
    readonly property real windowGhostOffset: overlayFromY
    readonly property int windowListFallEasing: Easing.InQuad
    readonly property int windowListFadeEasing: Easing.Linear
    readonly property int windowListRevealEasing: Easing.OutQuad
    readonly property int windowHintEnter: 140
    readonly property int windowHintExit: 200
    readonly property int windowHintMove: 240
    readonly property real windowHintInset: 10
    readonly property int workspaceIconEnter: 140
    readonly property int workspaceIconExit: 200
    readonly property int workspaceIconMove: 240
    readonly property int motionFrame: 16
    readonly property real motionFollowRate: 0.2
    // Per-position cascade step for a batch of tray icons.
    readonly property int trayIconStagger: 24

    readonly property int controlCommit: 120
    readonly property int tooltipIn: 120
    readonly property int tooltipOut: 160
    readonly property int dropdownExpand: 140
    readonly property int dropdownItem: 60

    readonly property var outSoft: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
    readonly property var outStd: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
    readonly property var inStd: [0.4, 0.0, 1.0, 1.0, 1.0, 1.0]
    readonly property var inOut: [0.4, 0.0, 0.2, 1.0, 1.0, 1.0]

    readonly property real hoverScale: 1.015
    readonly property real pressScale: 0.985
    readonly property real sliderTickBumpScale: 1.015
    readonly property real clickFlashOpacity: 0.3
    // Popup surfaces deform (scale+slide) from/to this factor while the bar
    // occludes them; opacity stays constant.
    readonly property real popupFromScale: 0.7
    readonly property real popupFromY: -4
    readonly property real overlayFromY: 8
    readonly property real buttonNudge: 1
    readonly property real backdropOpacity: 0.55
    readonly property real disabledOpacity: 0.45
}
