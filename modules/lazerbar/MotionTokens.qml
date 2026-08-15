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

    readonly property var outSoft: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]
    readonly property var outStd: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
    readonly property var inStd: [0.4, 0.0, 1.0, 1.0, 1.0, 1.0]
    readonly property var inOut: [0.4, 0.0, 0.2, 1.0, 1.0, 1.0]

    readonly property real hoverScale: 1.015
    readonly property real pressScale: 0.985
    readonly property real popupFromScale: 0.98
    readonly property real popupFromY: -4
    readonly property real overlayFromY: 8
    readonly property real buttonNudge: 1
    readonly property real backdropOpacity: 0.55
    readonly property real disabledOpacity: 0.45
}
