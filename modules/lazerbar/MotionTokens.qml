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

    // Match osu!lazer's full-screen wave and side-panel timing contracts.
    readonly property int waveEnter: 800
    readonly property int waveExit: 500
    // Backdrop waves lead the body so they stay visible while content slides over them.
    readonly property int waveBackdropEnter: 600

    // Wallpaper swaps are large-surface reveals; keep them calm but not slow.
    readonly property int wallpaperSwap: 480
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
