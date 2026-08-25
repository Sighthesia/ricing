pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "./" as Services

// Expose Material You color tokens loaded from colors.json with animated transitions.
QtObject {
    id: root

    // Suppress transition animations until first load completes
    property bool skipTransition: true

    // --- M3 Color Properties ---
    property color mPrimary: defaults.mPrimary
    property color mOnPrimary: defaults.mOnPrimary
    property color mSecondary: defaults.mSecondary
    property color mOnSecondary: defaults.mOnSecondary
    property color mTertiary: defaults.mTertiary
    property color mOnTertiary: defaults.mOnTertiary
    property color mError: defaults.mError
    property color mOnError: defaults.mOnError
    property color mSurface: defaults.mSurface
    property color mOnSurface: defaults.mOnSurface
    property color mSurfaceVariant: defaults.mSurfaceVariant
    property color mOnSurfaceVariant: defaults.mOnSurfaceVariant
    property color mPrimaryContainer: defaults.mPrimaryContainer
    property color mSurfaceContainerLow: defaults.mSurfaceContainerLow
    property color mSurfaceContainerHigh: defaults.mSurfaceContainerHigh
    property color mSurfaceContainerHighest: defaults.mSurfaceContainerHighest
    property color mOutline: defaults.mOutline
    property color mShadow: defaults.mShadow

    // --- Transition Behaviors ---
    Behavior on mPrimary { enabled: !root.skipTransition; ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing } }
    Behavior on mOnPrimary { enabled: !root.skipTransition; ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing } }
    Behavior on mSecondary { enabled: !root.skipTransition; ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing } }
    Behavior on mOnSecondary { enabled: !root.skipTransition; ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing } }
    Behavior on mTertiary { enabled: !root.skipTransition; ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing } }
    Behavior on mOnTertiary { enabled: !root.skipTransition; ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing } }
    Behavior on mError { enabled: !root.skipTransition; ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing } }
    Behavior on mOnError { enabled: !root.skipTransition; ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing } }
    Behavior on mSurface { enabled: !root.skipTransition; ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing } }
    Behavior on mOnSurface { enabled: !root.skipTransition; ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing } }
    Behavior on mSurfaceVariant { enabled: !root.skipTransition; ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing } }
    Behavior on mOnSurfaceVariant { enabled: !root.skipTransition; ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing } }
    Behavior on mPrimaryContainer { enabled: !root.skipTransition; ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing } }
    Behavior on mSurfaceContainerLow { enabled: !root.skipTransition; ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing } }
    Behavior on mSurfaceContainerHigh { enabled: !root.skipTransition; ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing } }
    Behavior on mSurfaceContainerHighest { enabled: !root.skipTransition; ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing } }
    Behavior on mOutline { enabled: !root.skipTransition; ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing } }
    Behavior on mShadow { enabled: !root.skipTransition; ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing } }

    // Apply loaded colors from adapter (imperative assignment triggers Behavior).
    // Use Qt.colorEqual guard: unset color properties default to transparent (#00000000),
    // so we fall back to defaults only when the adapter value is fully transparent.
    function applyColors() {
        var d = Services.SettingsService.appearance.colorScheme === "light"
                ? adapter.light : adapter.dark
        root.mPrimary = Qt.colorEqual(d.primary, "transparent") ? defaults.mPrimary : d.primary
        root.mOnPrimary = Qt.colorEqual(d.on_primary, "transparent") ? defaults.mOnPrimary : d.on_primary
        root.mSecondary = Qt.colorEqual(d.secondary, "transparent") ? defaults.mSecondary : d.secondary
        root.mOnSecondary = Qt.colorEqual(d.on_secondary, "transparent") ? defaults.mOnSecondary : d.on_secondary
        root.mTertiary = Qt.colorEqual(d.tertiary, "transparent") ? defaults.mTertiary : d.tertiary
        root.mOnTertiary = Qt.colorEqual(d.on_tertiary, "transparent") ? defaults.mOnTertiary : d.on_tertiary
        root.mError = Qt.colorEqual(d.error, "transparent") ? defaults.mError : d.error
        root.mOnError = Qt.colorEqual(d.on_error, "transparent") ? defaults.mOnError : d.on_error
        root.mSurface = Qt.colorEqual(d.surface, "transparent") ? defaults.mSurface : d.surface
        root.mOnSurface = Qt.colorEqual(d.on_surface, "transparent") ? defaults.mOnSurface : d.on_surface
        root.mSurfaceVariant = Qt.colorEqual(d.surface_variant, "transparent") ? defaults.mSurfaceVariant : d.surface_variant
        root.mOnSurfaceVariant = Qt.colorEqual(d.on_surface_variant, "transparent") ? defaults.mOnSurfaceVariant : d.on_surface_variant
        root.mPrimaryContainer = Qt.colorEqual(d.primary_container, "transparent") ? defaults.mPrimaryContainer : d.primary_container
        root.mSurfaceContainerLow = Qt.colorEqual(d.surface_container_low, "transparent") ? defaults.mSurfaceContainerLow : d.surface_container_low
        root.mSurfaceContainerHigh = Qt.colorEqual(d.surface_container_high, "transparent") ? defaults.mSurfaceContainerHigh : d.surface_container_high
        root.mSurfaceContainerHighest = Qt.colorEqual(d.surface_container_highest, "transparent") ? defaults.mSurfaceContainerHighest : d.surface_container_highest
        root.mOutline = Qt.colorEqual(d.outline, "transparent") ? defaults.mOutline : d.outline
        root.mShadow = Qt.colorEqual(d.shadow, "transparent") ? defaults.mShadow : d.shadow
    }

    // Apply an already-generated palette immediately while ColorService refreshes the cache.
    property Connections _schemeConnection: Connections {
        target: Services.SettingsService.appearance
        function onColorSchemeChanged() { root.applyColors() }
    }

    // Debounce reload for atomic file replacements
    property Timer _reloadTimer: Timer {
        interval: 200
        onTriggered: colorsFile.reload()
    }

    // --- Default dark palette ---
    property QtObject defaults: QtObject {
        readonly property color mPrimary: "#c8bfff"
        readonly property color mOnPrimary: "#2f1f7a"
        readonly property color mSecondary: "#c8c3dc"
        readonly property color mOnSecondary: "#312c47"
        readonly property color mTertiary: "#ecb8c8"
        readonly property color mOnTertiary: "#4a2532"
        readonly property color mError: "#ffb4ab"
        readonly property color mOnError: "#690005"
        readonly property color mSurface: "#1c1b1f"
        readonly property color mOnSurface: "#e6e1e5"
        readonly property color mSurfaceVariant: "#49454f"
        readonly property color mOnSurfaceVariant: "#cac4d0"
        readonly property color mPrimaryContainer: "#4a4277"
        readonly property color mSurfaceContainerLow: "#242228"
        readonly property color mSurfaceContainerHigh: "#2f2c33"
        readonly property color mSurfaceContainerHighest: "#3a373f"
        readonly property color mOutline: "#938f99"
        readonly property color mShadow: "#000000"
    }

    // --- FileView watching colors.json ---
    property FileView _colorsFile: FileView {
        id: colorsFile
        path: Quickshell.cacheDir + "/colors.json"
        watchChanges: true
        printErrors: false

        onFileChanged: root._reloadTimer.restart()

        onLoaded: {
            applyColors()
            if (root.skipTransition) {
                Qt.callLater(function() { root.skipTransition = false })
            }
        }

        onLoadFailed: {
            // Use defaults on missing/corrupt file
            if (root.skipTransition) {
                Qt.callLater(function() { root.skipTransition = false })
            }
        }

        JsonAdapter {
            id: adapter
            // Read the nested "dark" object from colors.json via JsonObject.
            // Property names must match JSON keys exactly (snake_case).
            property JsonObject dark: JsonObject {
                property color primary
                property color on_primary
                property color secondary
                property color on_secondary
                property color tertiary
                property color on_tertiary
                property color error
                property color on_error
                property color surface
                property color on_surface
                property color surface_variant
                property color on_surface_variant
                property color primary_container
                property color surface_container_low
                property color surface_container_high
                property color surface_container_highest
                property color outline
                property color shadow
            }
            property JsonObject light: JsonObject {
                property color primary
                property color on_primary
                property color secondary
                property color on_secondary
                property color tertiary
                property color on_tertiary
                property color error
                property color on_error
                property color surface
                property color on_surface
                property color surface_variant
                property color on_surface_variant
                property color primary_container
                property color surface_container_low
                property color surface_container_high
                property color surface_container_highest
                property color outline
                property color shadow
            }
        }
    }
}
