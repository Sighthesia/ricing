pragma Singleton

import Quickshell
import QtQuick
import qs.services

Singleton {
    id: root

    // Animation tokens — duration scaled by speedFactor (>1 = faster, <1 = slower)
    readonly property QtObject anim: QtObject {
        // Enter: elastic bounce-in for stage entrance, settings ON
        readonly property int enterDuration:
            Math.round(500 / SettingsService.data.animation.speedFactor)
        readonly property int enterType: Easing.OutElastic
        readonly property real enterAmplitude: 0.8
        readonly property real enterPeriod: 0.4

        // Exit: exponential snap-out for departure, settings OFF
        readonly property int exitDuration:
            Math.round(220 / SettingsService.data.animation.speedFactor)
        readonly property int exitType: Easing.InExpo

        // Move: smooth cubic for position shifts, drag fly-back
        readonly property int moveDuration:
            Math.round(320 / SettingsService.data.animation.speedFactor)
        readonly property int moveType: Easing.InOutCubic

        // Highlight: quick pulse for attention flash
        readonly property int highlightDuration:
            Math.round(180 / SettingsService.data.animation.speedFactor)
        readonly property int highlightType: Easing.OutQuad
    }

    // Stagger delay per widget index (ms)
    readonly property int staggerDelay:
        Math.round(40 / SettingsService.data.animation.speedFactor)

    // UI scale multiplier — changes all structural element sizes uniformly
    readonly property real uiScale: SettingsService.data.appearance.uiScale

    // Typography — bound to settings; font sizes scaled by uiScale
    readonly property string fontFamily:  SettingsService.data.appearance.fontFamily
    readonly property string fontMono:    SettingsService.data.appearance.fontMono
    readonly property int fontSizeIcon:   Math.round(SettingsService.data.appearance.fontSizeIcon  * uiScale)
    readonly property int fontSizeBody:   Math.round(SettingsService.data.appearance.fontSizeBody  * uiScale)
    readonly property int fontSizeSmall:  Math.round(SettingsService.data.appearance.fontSizeSmall * uiScale)

    // Dimensions — bound to settings
    readonly property real cornerRadius:  SettingsService.data.appearance.cornerRadius
    readonly property real barHeight:     SettingsService.data.bar.height
    readonly property real barPadding:    SettingsService.data.bar.padding
    readonly property real widgetPadding: 12        // structural constant, not user-facing
    readonly property real widgetSpacing: SettingsService.data.bar.widgetSpacing
    readonly property real iconPadding:   4         // structural constant, not user-facing

    // Settings panel structural tokens — keeps all settings components visually consistent;
    // all values scale with uiScale so the panel grows/shrinks proportionally.
    readonly property int  settingsRowHeight:         Math.round(34 * uiScale)
    readonly property int  settingsGroupHeaderHeight: Math.round(28 * uiScale)
    readonly property int  settingsLabelWidth:        Math.round(60 * uiScale)
    readonly property int  settingsPanelPadding:      Math.round(12 * uiScale)

    // Drag feedback — visual-only, not user-facing
    readonly property real dragScale:    1.05
    readonly property real dragOpacity:  0.9
    readonly property int pulseInterval: 3000
}
