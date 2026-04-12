pragma Singleton

import Quickshell
import QtQuick
import qs.config

// Owns launcher-specific geometry so the overlay can evolve independently from
// settings and shared card surfaces.
Singleton {
    readonly property int panelWidth: Math.round(640 * Theme.uiScale)
    readonly property int panelHeight: Math.round(480 * Theme.uiScale)
    readonly property int panelInset: Math.max(4, Math.round(4 * Theme.uiScale))

    readonly property int headerHeight: Math.round(44 * Theme.uiScale)
    readonly property int headerPadding: Math.max(8, Math.round(12 * Theme.uiScale))
    readonly property int headerGap: Math.max(6, Math.round(8 * Theme.uiScale))
    readonly property int modeBadgeHeight: Math.round(22 * Theme.uiScale)
    readonly property int modeBadgePaddingH: Math.max(10, Math.round(14 * Theme.uiScale))

    readonly property int resultRowHeight: Math.round(46 * Theme.uiScale)
    readonly property int resultInset: Math.max(8, Math.round(10 * Theme.uiScale))
    readonly property int resultGap: Math.max(6, Math.round(8 * Theme.uiScale))
    readonly property int resultIconSize: Math.round(20 * Theme.uiScale)
    readonly property int resultTextGap: Math.max(2, Math.round(2 * Theme.uiScale))
    readonly property int resultTitleSize: Theme.fontSizeSmall + 1
}
