pragma Singleton

import Quickshell
import QtQuick
import qs.config

// Feature-local visual tokens for SuperIsland cards, overlay deck, and hint surfaces.
Singleton {
    // Window hint tokens keep the hint layout and preview sizing centralized.
    readonly property int windowHintStagePadH: Math.max(14, Math.round(18 * Theme.uiScale))
    readonly property int windowHintStagePadV: Math.max(14, Math.round(18 * Theme.uiScale))
    readonly property int windowHintRowGap: Math.max(10, Math.round(12 * Theme.uiScale))
    readonly property int windowHintCapsuleGap: Math.max(4, Math.round(5 * Theme.uiScale))
    readonly property int windowHintWorkspaceColumnGap: Math.max(6, Math.round(8 * Theme.uiScale))
    readonly property int windowHintWorkspaceSideWidth: Math.round(164 * Theme.uiScale)
    readonly property int windowHintWorkspacePrimaryWidth: Math.round(300 * Theme.uiScale)
    readonly property int windowHintTitleSideWidth: Math.round(132 * Theme.uiScale)
    readonly property int windowHintTitlePrimaryWidth: Math.round(292 * Theme.uiScale)
    readonly property int windowHintWorkspaceSideHeight: Math.max(24, Theme.barWidget.pillHeight + Theme.barWidget.contentPaddingV)
    readonly property int windowHintWorkspacePrimaryHeight: Math.max(54, Theme.barWidget.pillHeight + Theme.barWidget.contentPaddingV * 7)
    readonly property int windowHintTitleCapsuleHeight: Math.max(30, Theme.fontSizeBody + Theme.barWidget.badgePaddingV * 6)
    readonly property int windowHintMinPreviewWidth: Math.round(320 * Theme.uiScale)
    readonly property int windowHintMaxPreviewWidth: Math.round(560 * Theme.uiScale)
    readonly property int windowHintNotchRadius: Math.max(10, Math.round(16 * Theme.uiScale))
    readonly property int windowHintExclusivePushPadding: Math.max(0, Theme.widgetSpacing)

    // Expanded deck tokens keep the shell chrome geometry easy to tune.
    readonly property int expandedDeckMargin: 12
    readonly property int expandedDeckSpacing: 10
    readonly property int expandedDeckNavWidth: Math.round(420 * Theme.uiScale)
    readonly property int expandedDeckNavHeight: 30
    readonly property int expandedDeckSessionWidth: Math.round(102 * Theme.uiScale)
    readonly property int expandedDeckCloseSize: 28

    // Overlay geometry tokens keep the attached seam shape readable.
    readonly property real overlayTopRadiusCornerFactor: 0.55
    readonly property real overlayTopRadiusPillFactor: 0.28
    readonly property real overlayDetachedRadiusCornerFactor: 1.0
    readonly property real overlayDetachedRadiusPillFactor: 0.42
    readonly property int overlayInwardCornerDepthBase: 18
    readonly property real overlayInwardCornerDepthTension: 0.3
    readonly property int overlayRevealLift: Math.max(8, Theme.barWidget.contentPaddingV * 4)
    readonly property real overlayAttachmentOverlap: 1
    readonly property int superIslandControlCenterBodyHeight: Math.round(528 * Theme.uiScale)

    // Idle clock tokens keep the clock strip spacing consistent.
    readonly property int idleClockClockClusterSpacing: 4
    readonly property int idleClockDigitGroupSpacing: 4
    readonly property int idleClockDigitSpacing: -1
    readonly property int idleClockColonColumnSpacing: 2
    readonly property int idleClockColonDotSize: 3

    // Media card tokens keep the expanded metadata stack aligned.
    readonly property int mediaExpandedMetadataSpacing: Math.max(2, Theme.barWidget.contentPaddingV)
}
