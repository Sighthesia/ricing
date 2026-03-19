pragma Singleton

import Quickshell
import QtQuick
import qs.services

Singleton {
    id: root

    // Animation tokens — duration scaled by speedFactor (>1 = faster, <1 = slower)
    readonly property QtObject anim: QtObject {
        readonly property string _barMotionPreset:
            SettingsService.data.barMotion.preset === "soft"
            || SettingsService.data.barMotion.preset === "balanced"
            || SettingsService.data.barMotion.preset === "snappy"
                ? SettingsService.data.barMotion.preset
                : "balanced"
        readonly property real _barMotionPresetSpeedFactor:
            _barMotionPreset === "soft" ? 0.82 : (_barMotionPreset === "snappy" ? 1.24 : 1.0)
        readonly property real _barMotionPresetTravelFactor:
            _barMotionPreset === "soft" ? 0.78 : (_barMotionPreset === "snappy" ? 1.26 : 1.0)
        readonly property real _barMotionPresetPulseFactor:
            _barMotionPreset === "soft" ? 0.72 : (_barMotionPreset === "snappy" ? 1.18 : 1.0)
        readonly property real _barMotionPresetRecoilFactor:
            _barMotionPreset === "soft" ? 0.72 : (_barMotionPreset === "snappy" ? 1.26 : 1.0)
        readonly property real _barMotionIntensity:
            Math.max(SettingsService.barMotionIntensityMin,
                Math.min(SettingsService.barMotionIntensityMax,
                    SettingsService.data.barMotion.intensity))
        readonly property real _barMotionEffectiveSpeedMultiplier:
            Math.max(0.01,
                SettingsService.data.barMotion.speedMultiplier * _barMotionPresetSpeedFactor)

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

        // Spring: elastic-feel settle for expressive Super Island expansion/collapse
        readonly property int springDuration:
            Math.round(360 / SettingsService.data.animation.speedFactor)
        readonly property int springType: Easing.OutBack
        readonly property real springOvershoot: 1.18

        // Pulse spring: subtle rebound so attention flashes feel lively without wobble
        readonly property int pulseSpringDuration:
            Math.round(180 / SettingsService.data.animation.speedFactor)
        readonly property int pulseSpringType: Easing.OutBack
        readonly property real pulseSpringOvershoot: 1.08

        readonly property int barExpandPreloadDuration:
            Math.max(1, Math.round(pulseSpringDuration
                / _barMotionEffectiveSpeedMultiplier))
        readonly property int barExpandOvershootDuration:
            Math.max(1, Math.round(springDuration
                / _barMotionEffectiveSpeedMultiplier))
        readonly property int barExpandSettleDuration:
            Math.max(1, Math.round(moveDuration
                / _barMotionEffectiveSpeedMultiplier))
        readonly property real barExpandExpandPreloadRatio:
            0.06 * _barMotionIntensity * _barMotionPresetTravelFactor
        readonly property real barExpandExpandOvershootRatio:
            0.12 * _barMotionIntensity * _barMotionPresetTravelFactor
        readonly property real barExpandCollapsePreloadRatio:
            0.05 * _barMotionIntensity * _barMotionPresetTravelFactor
        readonly property real barExpandCollapseOvershootRatio:
            0.08 * _barMotionIntensity * _barMotionPresetTravelFactor
        readonly property real barExpandExpandPulsePreloadOpacity:
            Math.max(0, 0.08 * _barMotionIntensity * _barMotionPresetPulseFactor)
        readonly property real barExpandExpandPulseOvershootOpacity:
            Math.max(0, 0.18 * _barMotionIntensity * _barMotionPresetPulseFactor)
        readonly property real barExpandCollapsePulsePreloadOpacity:
            Math.max(0, 0.10 * _barMotionIntensity * _barMotionPresetPulseFactor)
        readonly property real barExpandCollapsePulseOvershootOpacity:
            Math.max(0, 0.05 * _barMotionIntensity * _barMotionPresetPulseFactor)
        readonly property real barExpandExpandPulsePreloadScale:
            1 + 0.02 * _barMotionIntensity * _barMotionPresetPulseFactor
        readonly property real barExpandExpandPulseOvershootScale:
            1 + 0.08 * _barMotionIntensity * _barMotionPresetPulseFactor
        readonly property real barExpandCollapsePulsePreloadScale:
            1 + 0.03 * _barMotionIntensity * _barMotionPresetPulseFactor
        readonly property real barExpandCollapsePulseOvershootScale:
            Math.max(0, 1 - 0.03 * _barMotionIntensity * _barMotionPresetRecoilFactor)
        readonly property bool barExpandPulseEnabled: SettingsService.data.barMotion.pulseEnabled
        readonly property real barExpandPulseSettleOpacity: 0
        readonly property real barExpandPulseSettleScale: 1
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

    // Bar widget structural tokens — reusable micro-layout values shared by
    // bar components so internal spacing scales consistently with uiScale.
    readonly property QtObject barWidget: QtObject {
        readonly property int contentPaddingH:  Math.round(10 * uiScale)
        readonly property int contentPaddingV:  Math.max(3, Math.round(3 * uiScale))
        readonly property int primaryIconSize:  Math.round(16 * uiScale)
        readonly property int compactIconSize:  Math.round(13 * uiScale)
        readonly property int iconSpacing:      Math.round(3 * uiScale)
        readonly property int pillSpacing:      Math.round(8 * uiScale)
        readonly property int pillPaddingH:     Math.round(8 * uiScale)
        readonly property int iconLabelSpacing: Math.round(6 * uiScale)
        readonly property int focusPulsePadding: Math.round(4 * uiScale)
        readonly property int stackGap:         Math.round(6 * uiScale)
        readonly property int badgePaddingH:    Math.round(6 * uiScale)
        readonly property int badgePaddingV:    Math.round(4 * uiScale)
        readonly property int indicatorDotSize: Math.round(7 * uiScale)
        readonly property int pillHeight:       Math.max(1, Math.round(root.barHeight - root.iconPadding * 2))
        readonly property int compactMediaArtworkSize: primaryIconSize + contentPaddingV * 2
        readonly property int mediaCompactMinWidth: Math.round(192 * uiScale)
        readonly property int mediaCompactMaxTitleWidth: Math.round(164 * uiScale)
        readonly property real mediaCompactArtistWidthRatio: 0.38
        readonly property int mediaProgressThickness: Math.max(4, Math.round(4 * uiScale))
        readonly property int mediaExpandedProgressThickness: Math.max(6, Math.round(6 * uiScale))
        readonly property int mediaFlashControlGap: Math.round(8 * uiScale)
        readonly property int mediaFlashButtonSize: Math.round(26 * uiScale)
        readonly property int mediaFlashSecondaryButtonSize: Math.round(22 * uiScale)
        readonly property int mediaFlashPrimaryButtonSize: Math.round(28 * uiScale)
        readonly property int mediaFlashClusterGap: Math.round(6 * uiScale)
        readonly property int mediaFlashProgressMinWidth: Math.round(72 * uiScale)
        readonly property int mediaPanelArtworkSize: Math.round(112 * uiScale)
        readonly property int mediaPanelWidth: Math.round(360 * uiScale)
        readonly property real mediaPanelArtistMaxWidthRatio: 0.3
        readonly property int mediaPanelVisualizerHeight:
            Math.max(mediaExpandedProgressThickness * 4, contentPaddingV * 4)
        readonly property int mediaPanelControlsTopSpacing: contentPaddingV
        readonly property int mediaStaggerBaseDelay:
            Math.max(1, Math.round(root.staggerDelay * 1.75))
        readonly property int mediaStaggerStep:
            Math.max(1, Math.round(root.staggerDelay * 1.5))
        readonly property int mediaStaggerExitStep:
            Math.max(1, Math.round(root.staggerDelay * 0.875))
        readonly property int mediaStaggerHeroEnterOffset: Math.round(18 * uiScale)
        readonly property int mediaStaggerProgressEnterOffset: Math.round(22 * uiScale)
        readonly property int mediaStaggerControlsEnterOffset: Math.round(26 * uiScale)
        readonly property int mediaStaggerHeroExitOffset: Math.round(10 * uiScale)
        readonly property int mediaStaggerProgressExitOffset: Math.round(12 * uiScale)
        readonly property int mediaStaggerControlsExitOffset: Math.round(14 * uiScale)
        readonly property int mediaStaggerHeroExitDelay: 0
        readonly property int mediaVisualizerBarWidth: Math.max(2, Math.round(3 * uiScale))
        readonly property int mediaVisualizerBarGap: Math.max(1, Math.round(2 * uiScale))
        readonly property real mediaVisualizerBarOpacity: 0.42
        readonly property real mediaSurfaceOverlayOpacity: 0.5
        readonly property real mediaFallbackIconOpacity: 0.82
        readonly property real mediaTransientAccentOpacityMultiplier: 0.4
        readonly property real mediaFlashMinScale: 0.96
        readonly property real mediaFlashScaleRange: 0.04
        readonly property real mediaFlashButtonRadiusRatio: 0.38
        readonly property real mediaFlashSecondarySurfaceOpacity: 0.06
        readonly property real mediaFlashDisabledButtonOpacity: 0.45
        readonly property real mediaFlashSecondaryIconOpacity: 0.9
        readonly property real mediaFlashDisabledIconOpacity: 0.5
        readonly property real mediaFlashLabelOpacity: 0.72
        readonly property real mediaFlashPrimaryHighlightOpacity: 0.14
        readonly property real mediaFlashSecondaryHighlightOpacity: 0.12
        readonly property real mediaFlashPrimaryRippleOpacity: 0.2
        readonly property real mediaFlashSecondaryRippleOpacity: 0.28
        readonly property int mediaFlashCompactSecondaryButtonSize:
            Math.max(18, mediaFlashSecondaryButtonSize - 2)
        readonly property int mediaFlashCompactPrimaryButtonSize:
            Math.max(24, mediaFlashPrimaryButtonSize - 2)
        readonly property int mediaFlashCompactSecondaryIconSize:
            Math.max(12, compactIconSize - 1)
        readonly property int mediaFlashCompactPrimaryIconSize:
            Math.max(15, primaryIconSize - 1)
        readonly property real mediaContentSwapIncomingStart: 0.18
        readonly property real mediaContentSwapIncomingRange: 0.82
    }

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
