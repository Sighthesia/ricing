pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

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
    property color mOutline: defaults.mOutline
    property color mShadow: defaults.mShadow

    // --- Transition Behaviors ---
    Behavior on mPrimary { enabled: !root.skipTransition; ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on mOnPrimary { enabled: !root.skipTransition; ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on mSecondary { enabled: !root.skipTransition; ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on mOnSecondary { enabled: !root.skipTransition; ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on mTertiary { enabled: !root.skipTransition; ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on mOnTertiary { enabled: !root.skipTransition; ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on mError { enabled: !root.skipTransition; ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on mOnError { enabled: !root.skipTransition; ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on mSurface { enabled: !root.skipTransition; ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on mOnSurface { enabled: !root.skipTransition; ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on mSurfaceVariant { enabled: !root.skipTransition; ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on mOnSurfaceVariant { enabled: !root.skipTransition; ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on mOutline { enabled: !root.skipTransition; ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }
    Behavior on mShadow { enabled: !root.skipTransition; ColorAnimation { duration: 300; easing.type: Easing.OutCubic } }

    // Apply loaded colors from adapter (imperative assignment triggers Behavior)
    function applyColors() {
        root.mPrimary = adapter.mPrimary || defaults.mPrimary
        root.mOnPrimary = adapter.mOnPrimary || defaults.mOnPrimary
        root.mSecondary = adapter.mSecondary || defaults.mSecondary
        root.mOnSecondary = adapter.mOnSecondary || defaults.mOnSecondary
        root.mTertiary = adapter.mTertiary || defaults.mTertiary
        root.mOnTertiary = adapter.mOnTertiary || defaults.mOnTertiary
        root.mError = adapter.mError || defaults.mError
        root.mOnError = adapter.mOnError || defaults.mOnError
        root.mSurface = adapter.mSurface || defaults.mSurface
        root.mOnSurface = adapter.mOnSurface || defaults.mOnSurface
        root.mSurfaceVariant = adapter.mSurfaceVariant || defaults.mSurfaceVariant
        root.mOnSurfaceVariant = adapter.mOnSurfaceVariant || defaults.mOnSurfaceVariant
        root.mOutline = adapter.mOutline || defaults.mOutline
        root.mShadow = adapter.mShadow || defaults.mShadow
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
            property color mPrimary
            property color mOnPrimary
            property color mSecondary
            property color mOnSecondary
            property color mTertiary
            property color mOnTertiary
            property color mError
            property color mOnError
            property color mSurface
            property color mOnSurface
            property color mSurfaceVariant
            property color mOnSurfaceVariant
            property color mOutline
            property color mShadow
        }
    }
}
