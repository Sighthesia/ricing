pragma Singleton

import Quickshell
import QtQuick
import qs.config

// Shared surface and panel tokens for floating cards, popups, and compact
// dashboard cards that should read as one visual family.
Singleton {
    readonly property int shellInset: Math.max(4, Math.round(4 * Theme.uiScale))
    readonly property int shellPadding: Math.max(8, Math.round(12 * Theme.uiScale))
    readonly property int shellGap: Math.max(6, Math.round(8 * Theme.uiScale))
    readonly property int shellEdgeMargin: Math.max(8, Math.round(12 * Theme.uiScale))
    readonly property int shellRadius: Theme.cornerRadius
    readonly property real shellSurfaceAlpha: 0.88
    readonly property real shellBorderAlpha: 0.72
    readonly property real shellInnerBorderAlpha: 0.04

    readonly property int panelInset: shellInset
    readonly property int panelPadding: shellPadding
    readonly property int panelGap: shellGap
    readonly property int popupEdgeMargin: shellEdgeMargin

    readonly property int compactWidth: Math.round(280 * Theme.uiScale)
    readonly property int compactGap: Math.max(8, Math.round(10 * Theme.uiScale))
    readonly property int compactRadius: Math.max(8, Math.round(12 * Theme.uiScale))
    readonly property int compactInset: Math.max(8, Math.round(10 * Theme.uiScale))
    readonly property int compactIconSize: Math.round(34 * Theme.uiScale)
    readonly property int compactActionHeight: Math.round(42 * Theme.uiScale)

    readonly property int popupCardWidth: Math.round(360 * Theme.uiScale)
    readonly property int popupStackInset: Math.max(6, Math.round(8 * Theme.uiScale))
    readonly property int historyPanelWidth: Math.round(400 * Theme.uiScale)
    readonly property int historyPanelHeight: Math.round(480 * Theme.uiScale)
    readonly property int historyBadgeSize: Math.round(28 * Theme.uiScale)
    readonly property int largePanelWidth: Math.round(640 * Theme.uiScale)
    readonly property int largePanelHeight: Math.round(392 * Theme.uiScale)
    readonly property int largePanelGap: Math.max(10, Math.round(12 * Theme.uiScale))
    readonly property int largePanelInset: Math.max(10, Math.round(12 * Theme.uiScale))
    readonly property int dayGridGap: Math.max(6, Math.round(8 * Theme.uiScale))
    readonly property int dayCellHeight: Math.round(44 * Theme.uiScale)
    readonly property int dayCellRadius: Math.max(8, Math.round(10 * Theme.uiScale))

    readonly property int overlayNavWidth: Math.round(264 * Theme.uiScale)
    readonly property int overlayNavHeight: Math.round(30 * Theme.uiScale)
    readonly property int overlayNavSegmentMinWidth: Math.round(82 * Theme.uiScale)
    readonly property int overlayNavSegmentHeight: Math.round(28 * Theme.uiScale)
    readonly property int overlayNavRadius: Math.max(8, Math.round(10 * Theme.uiScale))
    readonly property int overlayNavPaddingH: Math.max(8, Math.round(8 * Theme.uiScale))
    readonly property int overlayNavSpacing: Math.max(4, Math.round(5 * Theme.uiScale))

    readonly property int menuWidth: 160
    readonly property int menuRowHeight: Theme.barHeight - Theme.barPadding

    readonly property int notificationCardWidth: popupCardWidth
    readonly property int notificationCardPadding: panelPadding
    readonly property int notificationCardRadius: shellRadius

    readonly property real panelSurfaceAlpha: shellSurfaceAlpha
    readonly property real panelBorderAlpha: shellBorderAlpha
    readonly property real historyItemSurfaceAlpha: 0.6
    readonly property real hoverHighlightAlpha: 0.12
}
