pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // Animation tokens (from bar-design.md §二)
    readonly property QtObject anim: QtObject {
        // Enter: elastic bounce-in for stage entrance, settings ON
        readonly property int enterDuration: 500
        readonly property int enterType: Easing.OutElastic
        readonly property real enterAmplitude: 0.8
        readonly property real enterPeriod: 0.4

        // Exit: exponential snap-out for departure, settings OFF
        readonly property int exitDuration: 220
        readonly property int exitType: Easing.InExpo

        // Move: smooth cubic for position shifts, drag fly-back
        readonly property int moveDuration: 320
        readonly property int moveType: Easing.InOutCubic

        // Highlight: quick pulse for attention flash
        readonly property int highlightDuration: 180
        readonly property int highlightType: Easing.OutQuad
    }

    // Stagger delay per widget index (ms)
    readonly property int staggerDelay: 40

    // Typography
    readonly property string fontFamily: "LXGW WenKai GB Screen"
    readonly property string fontMono: "JetBrainsMono Nerd Font"
    readonly property int fontSizeIcon: 16
    readonly property int fontSizeBody: 14
    readonly property int fontSizeSmall: 10

    // Dimensions
    readonly property real cornerRadius: 10
    readonly property real barHeight: 36
    readonly property real barPadding: 8
    readonly property real widgetPadding: 12
    readonly property real widgetSpacing: 6
    readonly property real iconPadding: 4

    // Drag feedback
    readonly property real dragScale: 1.05
    readonly property real dragOpacity: 0.9
    readonly property int pulseInterval: 3000
}
