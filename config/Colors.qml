pragma Singleton

import Quickshell
import QtQuick
import qs.services

Singleton {
    id: root

    // Colors are driven by SettingsService; inline defaults are only used
    // for the sub-frame window before settings load (invisible to users).
    readonly property color background:     SettingsService.data.appearance.backgroundColor
    readonly property color surface:        SettingsService.data.appearance.surfaceColor
    readonly property color highlight:      SettingsService.data.appearance.accentColor
    readonly property real  highlightAlpha: 0.15
    readonly property color text:           SettingsService.data.appearance.textColor
    readonly property color textMuted:      SettingsService.data.appearance.textMutedColor
    readonly property color border:         SettingsService.data.appearance.borderColor

    // FIXME: matugen integration — watch a color JSON file for dynamic palette
}
