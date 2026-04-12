pragma Singleton

import Quickshell
import QtQuick
// Owns settings-panel structure tokens so settings components stop borrowing
// unrelated feature values and can evolve as one visual family.
Singleton {
    id: root

    readonly property int rowWidth: Math.round(296 * Theme.uiScale)
    readonly property int rowHeight: Math.round(34 * Theme.uiScale)
    readonly property int groupHeaderHeight: Math.round(28 * Theme.uiScale)
    readonly property int labelWidth: Math.round(60 * Theme.uiScale)
    readonly property int panelPadding: Math.round(12 * Theme.uiScale)
    readonly property int rowGap: Math.max(4, Math.round(8 * Theme.uiScale))

    readonly property int highlightInset: Math.max(2, Math.round(4 * Theme.uiScale))
    readonly property int highlightRadius: Math.max(4, Math.round(4 * Theme.uiScale))
    readonly property int accentStripWidth: Math.max(2, Math.round(3 * Theme.uiScale))
    readonly property int accentStripRadius: Math.max(1, Math.round(1 * Theme.uiScale))

    readonly property int fieldRadius: Math.max(4, Math.round(4 * Theme.uiScale))
    readonly property int fieldVerticalInset: Math.max(6, Math.round(8 * Theme.uiScale))
    readonly property int fieldPaddingH: Math.max(4, Math.round(6 * Theme.uiScale))
    readonly property int fieldPaddingV: Math.max(2, Math.round(2 * Theme.uiScale))
    readonly property int compactFieldWidth: Math.round(100 * Theme.uiScale)
    readonly property int swatchSize: Math.round(20 * Theme.uiScale)

    readonly property int sliderReadoutWidth: Math.round(44 * Theme.uiScale)
    readonly property int sliderTrackHeight: Math.max(4, Math.round(4 * Theme.uiScale))
    readonly property int sliderHitHeight: Math.max(16, Math.round(20 * Theme.uiScale))
    readonly property int sliderHandleSize: Math.max(10, Math.round(14 * Theme.uiScale))

    readonly property int switchWidth: Math.round(42 * Theme.uiScale)
    readonly property int switchHeight: Math.round(24 * Theme.uiScale)
    readonly property int switchKnobSize: Math.max(12, Math.round(18 * Theme.uiScale))
    readonly property int switchInset: Math.max(2, Math.round(3 * Theme.uiScale))

    readonly property int segmentedMinWidth: Math.round(120 * Theme.uiScale)
    readonly property int segmentedHeight: Math.round(28 * Theme.uiScale)
    readonly property int segmentedRadius: Math.round(segmentedHeight / 2)
    readonly property int segmentedInset: Math.max(2, Math.round(2 * Theme.uiScale))
    readonly property int segmentedGap: Math.max(2, Math.round(2 * Theme.uiScale))
    readonly property int segmentedMinOptionWidth: Math.round(48 * Theme.uiScale)
    readonly property int segmentedOptionPaddingH: Math.max(10, Math.round(18 * Theme.uiScale))

    readonly property int pickerDropdownGap: Math.max(4, Math.round(4 * Theme.uiScale))
    readonly property int pickerSearchHeight: Math.max(20, rowHeight - Math.max(4, Math.round(6 * Theme.uiScale)))
    readonly property int pickerPreviewPaddingStart: Math.max(6, Math.round(8 * Theme.uiScale))
    readonly property int pickerPreviewPaddingEnd: Math.max(4, Math.round(6 * Theme.uiScale))
    readonly property int pickerLabelGap: Math.max(4, Math.round(4 * Theme.uiScale))
    readonly property int pickerMaxVisibleRows: 6

    readonly property int sidebarWidth: Math.round(108 * Theme.uiScale)
    readonly property int sidebarOuterPadding: Math.max(6, Math.round(8 * Theme.uiScale))
    readonly property int sidebarTopPadding: Math.max(8, Math.round(12 * Theme.uiScale))
    readonly property int sidebarItemGap: Math.max(1, Math.round(2 * Theme.uiScale))
    readonly property int sidebarSubItemGap: Math.max(1, Math.round(1 * Theme.uiScale))
    readonly property int sidebarChevronMargin: Math.max(6, Math.round(8 * Theme.uiScale))
    readonly property int sidebarContentGap: Math.max(4, Math.round(6 * Theme.uiScale))
    readonly property int sidebarSubHighlightInset: Math.max(6, Math.round(8 * Theme.uiScale))
    readonly property int sidebarSubLabelInset: Math.max(14, Math.round(20 * Theme.uiScale))
    readonly property int sidebarSurfaceRadius: Math.max(4, Math.round(Theme.cornerRadius - 4))

    readonly property int presetSectionGap: rowGap
    readonly property int presetListHeight: Math.round(86 * Theme.uiScale)
    readonly property int presetListGap: Math.max(4, Math.round(6 * Theme.uiScale))
    readonly property int presetCardWidth: Math.round(66 * Theme.uiScale)
    readonly property int presetCardHeight: Math.round(74 * Theme.uiScale)
    readonly property int presetPreviewHeight: Math.round(52 * Theme.uiScale)
    readonly property int presetCardRadius: Math.max(4, Math.round(6 * Theme.uiScale))
    readonly property int presetAccentHeight: Math.max(3, Math.round(4 * Theme.uiScale))
    readonly property int presetAccentRadius: Math.max(2, Math.round(2 * Theme.uiScale))
    readonly property int presetSwatchInset: Math.max(8, Math.round(10 * Theme.uiScale))
    readonly property int presetSwatchGap: Math.max(4, Math.round(5 * Theme.uiScale))
    readonly property int presetSwatchSize: Math.max(6, Math.round(8 * Theme.uiScale))
    readonly property int presetLabelGap: Math.max(2, Math.round(2 * Theme.uiScale))
    readonly property int presetWheelStep: Math.round(80 * Theme.uiScale)
    readonly property int behaviorOptionGap: Math.max(4, Math.round(4 * Theme.uiScale))
    readonly property int behaviorOptionWidth: Math.round(52 * Theme.uiScale)
}
