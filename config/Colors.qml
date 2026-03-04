pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.services

Singleton {
    id: root

    // Colors are driven by SettingsService; inline defaults are only used
    // for the sub-frame window before settings load (invisible to users).
    readonly property color background:
        _usingMatugen ? _mc("background",         SettingsService.data.appearance.backgroundColor)
                      : SettingsService.data.appearance.backgroundColor

    readonly property color surface:
        _usingMatugen ? _mc("surface_container",  SettingsService.data.appearance.surfaceColor)
                      : SettingsService.data.appearance.surfaceColor

    readonly property color highlight:
        _usingMatugen ? _mc("primary",            SettingsService.data.appearance.accentColor)
                      : SettingsService.data.appearance.accentColor

    readonly property real  highlightAlpha: 0.15

    readonly property color text:
        _usingMatugen ? _mc("on_surface",         SettingsService.data.appearance.textColor)
                      : SettingsService.data.appearance.textColor

    readonly property color textMuted:
        _usingMatugen ? _mc("on_surface_variant", SettingsService.data.appearance.textMutedColor)
                      : SettingsService.data.appearance.textMutedColor

    readonly property color border:
        _usingMatugen ? _mc("outline_variant",    SettingsService.data.appearance.borderColor)
                      : SettingsService.data.appearance.borderColor

    // Parsed matugen output JSON; null when file absent or invalid.
    property var _matugenColors: null

    readonly property bool _usingMatugen:
        SettingsService.data.appearance.matugenEnabled && _matugenColors !== null

    readonly property bool _dark: SettingsService.data.appearance.darkMode

    FileView {
        id: matugenColorsView
        path: SettingsService.configDir + "matugen-colors.json"
        watchChanges: true
        onFileChanged: this.reload()
        onLoaded: {
            try {
                root._matugenColors = JSON.parse(this.text())
            } catch (e) {
                root._matugenColors = null
            }
        }
        onLoadFailed: { root._matugenColors = null }
    }

    // Safely access a matugen color key; returns fallback if key is missing.
    function _mc(key, fallback) {
        if (!_matugenColors || !_matugenColors.colors) return fallback
        const node = _dark ? _matugenColors.colors.dark : _matugenColors.colors.light
        return (node && node[key]) ? node[key] : fallback
    }
}
