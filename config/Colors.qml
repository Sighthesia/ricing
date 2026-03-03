pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // Dark minimalist palette (from bar-design.md §八)
    readonly property color background:     "#1a1a1a"
    readonly property color surface:        "#252525"
    readonly property color highlight:      "#7aa2f7"
    readonly property real  highlightAlpha: 0.15
    readonly property color text:           "#c0caf5"
    readonly property color textMuted:      "#565f89"
    readonly property color border:         "#3b4261"

    // FIXME: matugen integration — watch a color JSON file for dynamic palette
}
