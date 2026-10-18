import QtQuick
import "../../services" as Services

// Hand the lock surface the clock placement ClockPlacementService has cached
// for this screen and wallpaper.  Nothing is scanned here: the service scans on
// its own schedule so the entrance wave never waits for a Python process, and
// this component only decides whether the cached result applies right now.
Item {
    id: root

    property string wallpaperPath: ""
    property int screenWidth: 0
    property int screenHeight: 0
    property real centerX: 0.5
    property real centerY: 0.5
    property real luminance: 0.5
    property bool ready: false

    // The placement only applies when the feature is switched on in settings
    // *and* the Python runtime behind it exists.  Otherwise `ready` stays false
    // and the surface keeps the clock at its default centre; the settings row
    // that owns the switch is greyed out in that case, so the toggle never
    // claims to work while nothing moves.
    readonly property bool autoPlacement:
        Services.SettingsService.appearance.lockClockAutoPlacement === true
    readonly property bool runtimeReady: Services.ClockPlacementService.ready
    readonly property bool active: root.autoPlacement && root.runtimeReady
    readonly property var placement: root.active
        ? Services.ClockPlacementService.placement(root.screenWidth, root.screenHeight,
                                                   root.wallpaperPath)
        : null

    signal analysisApplied()

    function clamp(value, minimum, maximum) {
        return Math.max(minimum, Math.min(maximum, Number(value)))
    }

    function applyPlacement(): void {
        if (!root.placement) {
            root.ready = false
            return
        }
        root.centerX = root.clamp(root.placement.center_x, 0.06, 0.94)
        root.centerY = root.clamp(root.placement.center_y, 0.10, 0.90)
        root.luminance = root.clamp(root.placement.luminance, 0, 1)
        root.ready = true
        root.analysisApplied()
    }

    // A miss is not an error: the service may still be warming up, and asking
    // again is what turns a cold cache into a placement.
    function requestPlacement(): void {
        if (!root.active)
            return
        Services.ClockPlacementService.request(root.screenWidth, root.screenHeight,
                                               root.wallpaperPath)
    }

    onPlacementChanged: root.applyPlacement()
    onActiveChanged: {
        if (root.active) {
            root.applyPlacement()
            root.requestPlacement()
        } else {
            root.ready = false
        }
    }
    onScreenWidthChanged: root.requestPlacement()
    onScreenHeightChanged: root.requestPlacement()
    onWallpaperPathChanged: {
        root.applyPlacement()
        root.requestPlacement()
    }
    Component.onCompleted: {
        root.applyPlacement()
        root.requestPlacement()
    }
}
