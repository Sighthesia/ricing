pragma Singleton
import QtQuick

// Centralize shared motion defaults by interaction category.
QtObject {
    id: root

    // Keep the dockzone hover spring aligned with the current hand-feel.
    property QtObject hover: QtObject {
        readonly property real spring: 6.5
        readonly property real damping: 0.88
        readonly property real mass: 1.0
        readonly property real epsilon: 0.01
    }

    // Drive the center island expand/collapse with a heavier, smoother spring.
    // Higher mass yields more even per-frame displacement than the hover spring,
    // and direction-aware damping makes expansion lively while collapse settles
    // cleanly. Tuned against the reference dynamic-island feel.
    property QtObject islandExpand: QtObject {
        readonly property real spring: 5.0
        readonly property real mass: 3.0
        readonly property real dampingExpand: 0.7
        readonly property real dampingCollapse: 0.8
        readonly property real epsilon: 0.01
    }

    // Group common number transition timings used across visible surfaces.
    property QtObject number: QtObject {
        readonly property int shortDuration: 100
        readonly property int shortEasing: Easing.OutCubic

        readonly property int snugDuration: 120
        readonly property int snugEasing: Easing.OutCubic

        readonly property int enterDuration: 140
        readonly property int enterEasing: Easing.OutCubic

        readonly property int settleDuration: 150
        readonly property int settleEasing: Easing.OutQuad

        readonly property int contentDuration: 180
        readonly property int contentEasing: Easing.OutCubic

        readonly property int surfaceDuration: 250
        readonly property int surfaceEasing: Easing.InOutQuad

        readonly property int colorDuration: 300
        readonly property int colorEasing: Easing.OutCubic

        readonly property int crossfadeDuration: 400
        readonly property int crossfadeEasing: Easing.OutCubic
    }

    // Keep color transitions calm and uniform across token updates.
    property QtObject color: QtObject {
        readonly property int transitionDuration: 300
        readonly property int transitionEasing: Easing.OutCubic
    }

    // Match popup entry/exit to the bar's floating surface language.
    property QtObject popup: QtObject {
        readonly property int opacityDuration: 120
        readonly property int opacityEasing: Easing.OutQuad
        readonly property int scaleDuration: 150
        readonly property int scaleEasing: Easing.OutBack
        readonly property real scaleOvershoot: 0.3
    }
}
