import QtQuick
import "../bar/MenuVisuals.js" as MenuVisuals
import "../bar" as Bar
import "../settings" as Settings
import "../workspace-hint" as WorkspaceHint
import "../../services" as Services

// Animated island body: expands from collapsed clock to full launcher panel.
// Delegates the spring-morphing attached-island silhouette (ears, blur strips,
// blur lead, body clip) to AttachedIslandSurface and only owns the collapsed
// vs expanded content and its interaction handlers.
Item {
    id: root

    required property string screenName
    required property real screenX
    required property real screenY
    required property real screenWidth
    required property real screenHeight
    property bool _spectrumRegistered: false
    property var _centerWidgetExpandHeights: ({})
    property real centerWidgetExpandHeight: 0

    // Geometry constants.
    readonly property int collapsedW: 220
    readonly property int collapsedH: Services.BarLayoutService.barHeight
    readonly property int earRadius: 24
    readonly property int collapsedHorizontalPadding: 16
    readonly property int hoverWLift: 12
    readonly property int hoverHLift: 4
    readonly property int hoverRadiusLift: 2
    // Hover-driven content scale lift, mirroring the dockzone motion contract:
    // the collapsed body breathes by 3% so hover reads as the same object
    // growing, matching the edge dockzone's motionBlend * 0.03 scale lift.
    readonly property real hoverScaleLift: 0.03
    // Spring-animated hover progress (0..1) so the scale lift eases in/out
    // instead of snapping with the boolean hover state. Mirrors the dockzone
    // _hoverProgress + Motion.hover spring pair.
    property real _hoverProgress: 0
    // Suppress the hover lift once the island leaves the collapsed capsule
    // state (expanded panel, hosted menus, window-hint stage) so the lift
    // only applies to the same collapsed silhouette the edge dockzones lift.
    readonly property bool _collapsedHoverActive: hoverHandler.hovered
        && !Services.IslandService.expanded
        && !root.hostsCenterContextMenu
        && !root.hostsCenterWidgetPicker
        && !root.hostsCenterWidgetSettings
        && !Services.IslandService.windowHintActive

    // Initialize hover progress from the live collapsed-hover state on creation
    // (the existing Component.onCompleted block below folds this in).
    on_CollapsedHoverActiveChanged: root._hoverProgress = root._collapsedHoverActive ? 1 : 0

    Behavior on _hoverProgress {
        SpringAnimation {
            spring: Services.Motion.hover.spring
            damping: Services.Motion.hover.damping
            mass: Services.Motion.hover.mass
            epsilon: Services.Motion.hover.epsilon
        }
    }
    readonly property int expandedW: Math.min(620, Screen.width - 48)
    readonly property int expandedH: Math.min(620, Screen.height - 96)
    // Sum of the overview collage rows (launcher + gaps + cards), so
    // targetH adapts to the actual content instead of reserving 620px
    // and leaving whitespace below the bottom row.
    readonly property real overviewNatHeight: {
        if (!root.overviewPageVisible) return 0
        return launcherCard.height + 10 + topRow.height + 10 + middleRow.height
    }
    readonly property int expandedWidgetClearance: Math.max(root.collapsedH, root.messageContentHeight) + 12
    readonly property int expandedInnerGap: 12
    readonly property int expandedNavHeight: 42
    // Max height of the compact launcher card at the top of the overview,
    // so search results expand downward but do not push the control-center
    // cards entirely out of view.
    readonly property int launcherCardMaxHeight: 250
    readonly property color surfaceColor: Qt.alpha(Services.Color.mSurface, Services.SettingsService.panelSurfaceOpacity)
    readonly property var centerWidgets: Services.BarLayoutService.sectionWidgets("center")
    readonly property bool showManagedCenterWidgets: root.centerWidgets.length > 0
    readonly property bool showCenterSpectrum: root.showManagedCenterWidgets
        && !Services.IslandService.windowHintActive
        && !Services.IslandService.expanded
    readonly property bool launcherPageVisible: Services.IslandService.expanded
        && Services.IslandService.panelPage === "launcher"
    readonly property bool overviewPageVisible: Services.IslandService.expanded
        && Services.IslandService.panelPage === "overview"
    readonly property bool settingsCenterVisible: Services.IslandService.expanded
        && Services.IslandService.panelPage === "settings-center"
    readonly property bool notificationsPageVisible: Services.IslandService.expanded
        && Services.IslandService.panelPage === "notifications"
    readonly property bool mediaPageVisible: Services.IslandService.expanded
        && Services.IslandService.panelPage === "media"
    readonly property bool calendarPageVisible: Services.IslandService.expanded
        && Services.IslandService.panelPage === "calendar"
    readonly property bool weatherPageVisible: Services.IslandService.expanded
        && Services.IslandService.panelPage === "weather"
    readonly property bool hostsCenterContextMenu: Services.BarLayoutService.contextMenuVisible
        && !Services.BarLayoutService.widgetPickerVisible
        && Services.BarLayoutService.contextMenuSection === "center"
        && Services.BarLayoutService.contextMenuScreenName === root.screenName
        && !Services.IslandService.expanded
        && !Services.IslandService.windowHintActive
    readonly property bool hostsCenterWidgetPicker: Services.BarLayoutService.widgetPickerVisible
        && Services.BarLayoutService.widgetPickerSection === "center"
        && Services.BarLayoutService.widgetPickerScreenName === root.screenName
        && !Services.IslandService.expanded
        && !Services.IslandService.windowHintActive
    readonly property bool hostsCenterWidgetSettings: Services.BarLayoutService.widgetSettingsVisible
        && Services.BarLayoutService.widgetSettingsSection === "center"
        && Services.BarLayoutService.widgetSettingsScreenName === root.screenName
        && !Services.IslandService.expanded
        && !Services.IslandService.windowHintActive
    readonly property real collapsedContentWidth: collapsedRow.implicitWidth > 0
        ? collapsedRow.implicitWidth + collapsedHorizontalPadding
        : collapsedW
    readonly property real collapsedContentHeight: Math.max(collapsedRow.implicitHeight, collapsedContentLoader.implicitHeight, 18)
    readonly property real managedContentHeight: Math.max(collapsedH, collapsedRow.implicitHeight + root.centerWidgetExpandHeight)
    // When a transient message is active the collapsed body grows downward to
    // fit the message card (clock stays in the top row); height tracks the card.
    readonly property real messageContentHeight: Services.TransientMessageService.active
        ? Math.max(root.managedContentHeight, collapsedRow.implicitHeight + 12)
        : root.managedContentHeight
    readonly property real collapsedCapsuleWidth: collapsedContentWidth + (hoverHandler.hovered ? hoverWLift : 0)
    readonly property real liveBodyWidth: Math.max(0, root.width - root.earRadius * 2)
    readonly property real collapsedWidthProgress: root.collapsedCapsuleWidth > 0
        ? Math.max(0, Math.min(1, root.liveBodyWidth / root.collapsedCapsuleWidth))
        : 1
    readonly property real expandedWidthProgress: root.expandedW > 0
        ? Math.max(0, Math.min(1, root.liveBodyWidth / root.expandedW))
        : 1
    readonly property real expandedRevealProgress: Services.IslandService.expanded
        ? Math.max(0, Math.min(1, (root.expandedWidthProgress - 0.6) / 0.3))
        : 0
    readonly property real centerContextMenuW: centerContextMenuMeasure.implicitWidth
    readonly property real centerContextMenuH: centerContextMenuMeasure.implicitHeight
    readonly property real centerContextMenuClipInset: Math.max(10, surface.bodyRadius * 0.75)
    readonly property real centerWidgetSettingsW: centerWidgetSettingsMeasure.implicitWidth
    readonly property real centerWidgetSettingsH: centerWidgetSettingsMeasure.implicitHeight
    readonly property real centerWidgetSettingsClipInset: Math.max(10, surface.bodyRadius * 0.75)
    readonly property real centerWidgetPickerW: centerWidgetPickerMeasure.implicitWidth
    readonly property real centerWidgetPickerH: centerWidgetPickerMeasure.implicitHeight
    readonly property real centerWidgetPickerClipInset: Math.max(6, surface.bodyRadius * 0.45)

    // Window-hint extension geometry, sized to the live stage. When the hint is
    // held without the launcher, the island grows to wrap the full vertical
    // workspace stage; when the launcher is also open, the island keeps its
    // expanded size and only the title row overlays the launcher's lower half.
    readonly property bool hintLauncherConflict: Services.IslandService.expanded
        && Services.IslandService.windowHintActive
    readonly property int windowHintW: Math.max(
        root.collapsedContentWidth,
        Math.min(hintStage.stageWidth + 32, Screen.width - root.earRadius * 2)
    )
    readonly property int windowHintH: root.collapsedH + hintStage.stageHeight + 24

    // Target dimensions reuse the expanded island body instead of a second panel.
    property int targetW: Services.IslandService.expanded
        ? expandedW
        : (root.hostsCenterWidgetPicker
        ? centerWidgetPickerW
        : (root.hostsCenterWidgetSettings
        ? Math.max(collapsedCapsuleWidth, centerWidgetSettingsW)
        : (root.hostsCenterContextMenu
        ? Math.max(collapsedCapsuleWidth, centerContextMenuW)
        : (Services.IslandService.windowHintActive
        ? windowHintW
        : collapsedCapsuleWidth))))
    property int targetH: Services.IslandService.expanded
        ? (root.overviewPageVisible
            ? Math.min(expandedH, Math.round(root.overviewNatHeight + root.expandedWidgetClearance + 16))
            : expandedH)
        : (root.hostsCenterWidgetPicker
        ? collapsedH + centerWidgetPickerH + 8 + centerWidgetPickerClipInset
        : (root.hostsCenterWidgetSettings
        ? Math.max(messageContentHeight, collapsedH) + centerWidgetSettingsH + 8 + centerWidgetSettingsClipInset
        : (root.hostsCenterContextMenu
        ? Math.max(messageContentHeight, collapsedH) + centerContextMenuH + 8 + centerContextMenuClipInset
        : (Services.IslandService.windowHintActive
        ? windowHintH
        : messageContentHeight + (hoverHandler.hovered ? hoverHLift : 0)))))
    property int targetR: Services.IslandService.expanded
        ? 24
        : (root.hostsCenterWidgetPicker
        ? 14
        : (root.hostsCenterWidgetSettings
        ? 14
        : (root.hostsCenterContextMenu
        ? 14
        : (Services.IslandService.windowHintActive
        ? 24
        : 14 + (hoverHandler.hovered ? hoverRadiusLift : 0)))))

    // Size mirrors the surface's animated geometry so external consumers
    // (IslandWindow hit region) keep tracking the live island bounds.
    width: surface.width
    height: surface.height
    implicitWidth: width
    implicitHeight: height
    // Hover-driven content scale lift mirrors the edge dockzone motion
    // contract: the collapsed silhouette grows by 3% on hover so the whole
    // body (glass + content) reads as one continuous object breathing, not
    // just the geometry widening. Suppressed outside the collapsed state.
    scale: 1 + root._hoverProgress * root.hoverScaleLift
    transformOrigin: Item.Center

    // Forward the surface blur parts for IslandWindow's blur region tracking.
    readonly property var blurParts: surface.blurParts

    // Forward widget-aware context menu requests from center widget wrappers.
    function openWidgetContextMenu(instanceKey, widgetId, clickX, screenName, widgetCenterX) {
        Services.TrayMenuService.close()
        Services.BarLayoutService.openContextMenu(clickX, instanceKey, widgetId, screenName || root.screenName)
        Services.BarLayoutService.widgetSettingsX = widgetCenterX || clickX
    }

    function syncSpectrumRegistration() {
        if (root.showCenterSpectrum === root._spectrumRegistered)
            return

        if (root.showCenterSpectrum)
            Services.SpectrumService.registerComponent("island-center:" + root.screenName)
        else
            Services.SpectrumService.unregisterComponent("island-center:" + root.screenName)

        root._spectrumRegistered = root.showCenterSpectrum
    }

    function reportCenterWidgetExpandHeight(instanceKey, expandHeight) {
        if (!instanceKey)
            return

        var nextMap = Object.assign({}, root._centerWidgetExpandHeights)
        var resolvedHeight = Math.max(0, expandHeight || 0)
        if (resolvedHeight > 0)
            nextMap[instanceKey] = resolvedHeight
        else
            delete nextMap[instanceKey]

        root._centerWidgetExpandHeights = nextMap

        var nextHeight = 0
        var keys = Object.keys(nextMap)
        for (var index = 0; index < keys.length; index += 1)
            nextHeight = Math.max(nextHeight, nextMap[keys[index]])

        root.centerWidgetExpandHeight = nextHeight
    }

    function focusExpandedPage() {
        if (!Services.IslandService.expanded)
            return

        Qt.callLater(() => {
            if (!Services.IslandService.expanded)
                return

            if (root.launcherPageVisible && detailPageLoader.item && detailPageLoader.item.focusSearchWhenReady) {
                detailPageLoader.item.focusSearchWhenReady()
                return
            }

            expandedContent.forceActiveFocus()
        })
    }

    Component.onCompleted: {
        syncSpectrumRegistration()
        Services.IslandService.setCenterSurfaceWidth(root.screenName, width)
        root._hoverProgress = root._collapsedHoverActive ? 1 : 0
    }
    Component.onDestruction: {
        if (root._spectrumRegistered)
            Services.SpectrumService.unregisterComponent("island-center:" + root.screenName)

        Services.IslandService.setCenterSurfaceWidth(root.screenName, 0)
    }
    onShowCenterSpectrumChanged: syncSpectrumRegistration()
    onWidthChanged: Services.IslandService.setCenterSurfaceWidth(root.screenName, width)

    Connections {
        target: Services.IslandService

        function onExpandedChanged() {
            if (Services.IslandService.expanded)
                Services.IslandService.triggerRipplePulse()
        }
    }

    Connections {
        target: Services.TransientMessageService

        function onActiveChanged() {
            if (Services.TransientMessageService.active)
                Services.IslandService.triggerRipplePulse()
        }
    }

    // Passive hover tracking for the collapsed island geometry.
    HoverHandler {
        id: hoverHandler
    }

    // Shared attached-island silhouette shell; hosts island content in its body.
    AttachedIslandSurface {
        id: surface
        anchors.top: parent.top
        anchors.left: parent.left

        targetBodyWidth: root.targetW
        targetBodyHeight: root.targetH
        targetRadius: root.targetR
        earRadius: root.earRadius
        surfaceColor: root.surfaceColor
        rippleScreenX: root.screenX
        rippleScreenY: root.screenY
        rippleScreenWidth: root.screenWidth
        rippleScreenHeight: root.screenHeight

        // Measure the center context menu without clipping so the island can
        // expand its shared body before rendering the live menu view.
        Bar.BarContextMenuView {
            id: centerContextMenuMeasure
            visible: false
            enabled: false
        }

        // Measure the center widget picker without clipping so the island can
        // expand its shared body before rendering the live picker view.
        Bar.WidgetPickerView {
            id: centerWidgetPickerMeasure
            visible: false
            enabled: false
        }

        // Measure the center widget settings without clipping so the island can
        // expand its shared body before rendering the live settings view.
        Bar.WidgetSettingsView {
            id: centerWidgetSettingsMeasure
            visible: false
            enabled: false
        }

        // --- Collapsed content: center widgets or fallback clock ---
        Item {
            id: collapsedContent
            anchors.fill: parent
            // Keep the dockzone content visible while the window hint expands.
            opacity: 1
            visible: opacity > 0.01
            z: 1

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            // Keep the center spectrum pinned to the island's lower edge instead of following the centered content row.
            Item {
                id: collapsedSpectrumBand

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1
                height: Math.min(parent.height, Math.max(16, root.collapsedH - 12))
                visible: root.showCenterSpectrum && width > 0 && height > 0 && (opacity > 0.01 || !Services.SpectrumService.isIdle)
                z: 0
                clip: true
                opacity: Services.SpectrumService.isIdle ? 0 : 1

                Behavior on opacity {
                    NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
                }

                Bar.DockzoneSpectrum {
                    anchors.fill: parent
                    anchors.leftMargin: 0
                    anchors.rightMargin: 0
                    anchors.topMargin: 8
                    anchors.bottomMargin: 0
                    values: Services.SpectrumService.values
                }
            }

            // Switch collapsed content between the real center widgets and the
            // fallback clock, with the transient message card adjacent so an
            // active message grows the island (layout push, no overlap). The
            // row is pinned to the top band so the clock and the message head
            // align while the body grows downward for long bodies.
            Row {
                id: collapsedRow

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                // Center the row's top item in the bar-height band so the clock
                // stays vertically centered while the body grows downward for
                // long message bodies.
                anchors.topMargin: Math.max(0, (root.collapsedH - root.collapsedContentHeight) / 2)
                spacing: 8
                opacity: 1

                // Wrap the collapsed center content so the spectrum can size to the managed widget block.
                Item {
                    id: collapsedContentFrame

                    anchors.top: parent.top
                    width: collapsedContentLoader.implicitWidth
                    height: collapsedContentLoader.implicitHeight

                    Loader {
                        id: collapsedContentLoader

                        anchors.top: parent.top
                        sourceComponent: root.showManagedCenterWidgets ? managedCenterWidgets : fallbackClock
                    }
                }

                // Transient message card beside the clock; zero size when idle.
                TransientMessageBand {
                    id: transientMessageBand
                    anchors.top: parent.top
                }

                // Notification summary entry: unread badge and opencode shortcut.
                NotificationSummaryDockzone {
                    id: notificationSummary
                    anchors.top: parent.top
                }
            }

            // Render the actual managed center widgets in collapsed mode.
            Component {
                id: managedCenterWidgets

                Row {
                    id: centerWidgetsRow

                    spacing: 8

                    Repeater {
                        model: root.centerWidgets.length

                        Bar.BarWidgetWrapper {
                            required property int index

                            screenName: root.screenName
                            widgetEntry: root.centerWidgets[index]
                            widgetSource: Qt.resolvedUrl(widgetEntry.source)
                            onDockzoneExpandHeightChanged: root.reportCenterWidgetExpandHeight(widgetInstanceKey, dockzoneExpandHeight)
                            Component.onCompleted: root.reportCenterWidgetExpandHeight(widgetInstanceKey, dockzoneExpandHeight)
                            Component.onDestruction: root.reportCenterWidgetExpandHeight(widgetInstanceKey, 0)
                        }
                    }
                }
            }

            // Keep the clock as the fallback when no center widgets exist.
            Component {
                id: fallbackClock

                IslandClock {
                }
            }
        }

        // Render the center context menu inside the island's own expanded body
        // so the menu, blur, and background all come from one surface owner.
        Loader {
            id: centerContextMenuLoader

            active: root.hostsCenterContextMenu || opacity > 0.01
            z: 2
            x: (parent.width - width) / 2
            y: root.collapsedH
            width: parent.width
            height: Math.max(0, parent.height - root.collapsedH - root.centerContextMenuClipInset)
            opacity: root.hostsCenterContextMenu ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Services.Motion.popup.opacityDuration
                    easing.type: Services.Motion.popup.opacityEasing
                }
            }

            sourceComponent: Bar.BarContextMenuView {
                viewportWidth: centerContextMenuLoader.width
                viewportHeight: centerContextMenuLoader.height
            }
        }

        // Render the center widget picker inside the island's own expanded body
        // so picker browsing shares the same surface owner as the center zone.
    Loader {
        id: centerWidgetPickerLoader

            active: root.hostsCenterWidgetPicker || opacity > 0.01
            z: 2
            x: (parent.width - width) / 2
            y: root.collapsedH
            width: parent.width
            height: Math.max(0, parent.height - root.collapsedH - root.centerWidgetPickerClipInset)
            opacity: root.hostsCenterWidgetPicker ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Services.Motion.popup.opacityDuration
                    easing.type: Services.Motion.popup.opacityEasing
                }
            }

        sourceComponent: Bar.WidgetPickerView {
            viewportWidth: centerWidgetPickerLoader.width
            viewportHeight: centerWidgetPickerLoader.height
        }
    }

    // Render the center widget settings inside the island's own expanded body
    // so settings, blur, and background all come from one surface owner.
    Loader {
        id: centerWidgetSettingsLoader

        active: root.hostsCenterWidgetSettings || opacity > 0.01
        z: 2
        x: (parent.width - width) / 2
        y: root.collapsedH
        width: parent.width
        height: Math.max(0, parent.height - root.collapsedH - root.centerWidgetSettingsClipInset)
        opacity: root.hostsCenterWidgetSettings ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Services.Motion.popup.opacityDuration
                easing.type: Services.Motion.popup.opacityEasing
            }
        }

        sourceComponent: Bar.WidgetSettingsView {
            viewportWidth: centerWidgetSettingsLoader.width
            viewportHeight: centerWidgetSettingsLoader.height
        }
    }

        // --- Expanded content: mode switcher + current page inside the same
        // island body, so the expanded panel remains the single visual host. ---
                FocusScope {
                    id: expandedContent
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: root.expandedWidgetClearance
                    anchors.bottomMargin: 16
                    opacity: root.expandedRevealProgress
                    visible: opacity > 0.01
                    focus: Services.IslandService.expanded

                    Component.onCompleted: root.focusExpandedPage()

                    Connections {
                        target: Services.IslandService

                        function onExpandedChanged() {
                            if (Services.IslandService.expanded)
                                root.focusExpandedPage()
                        }

                        function onPanelPageChanged() {
                            root.focusExpandedPage()
                        }
                    }

                    Keys.onEscapePressed: Services.IslandService.close()

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

            // Control-center collage overview: mixed-size glanceable cards
            // arranged in an asymmetric hierarchy — bold clock + toggle grid
            // on top, large media + dense notification in the middle, and a
            // full-width calendar preview at the bottom.
            Item {
                id: overviewPage

                anchors.fill: parent
                visible: root.overviewPageVisible || overviewPage._overviewProgress > 0.01
                enabled: root.overviewPageVisible
                opacity: 1

                // Entrance progress (0→1) drives staggered card cascade so the
                // search bar appears first and the control-center cards trickle
                // in from top to bottom, making the transition feel intentional.
                property real _overviewProgress: 0

                Behavior on _overviewProgress {
                    NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                }

                // Toggle the progress animation when the overview page is shown
                // or hidden.  Uses `enabled` (which tracks root.overviewPageVisible
                // directly) instead of `visible` so the trigger fires even when
                // the fade-out keeps visible=true via _overviewProgress > 0.01.
                onEnabledChanged: {
                    if (root.overviewPageVisible)
                        overviewPage._overviewProgress = 1
                    else
                        overviewPage._overviewProgress = 0
                }

                // Compact search-and-apps launcher at the top of the overview:
                // search bar always visible, results expand downward when the
                // user types — like a start menu integrated into the control
                // center.  The card wrapper (radius 16, gradient, highlight
                // strip, border, hover color) matches the glass visual language
                // of the surrounding overview cards.
                Rectangle {
                    id: launcherCard
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    // Collapse to just the search bar height (40px + 12px margins)
                    // when no query is entered, so the card does not reserve a
                    // large empty area.  Once the user types, the card expands
                    // up to 250 px to show search results inline.
                    height: compactLauncher._localQuery.trim().length === 0
                        ? 52
                        : Math.min(root.launcherCardMaxHeight, Math.max(52, parent.height - y))
                    clip: true
                    radius: 16
                    // Cascade tier 1: the search bar appears first, settling
                    // before the control-center cards start their entrance.
                    opacity: Math.min(1, Math.max(0, (overviewPage._overviewProgress - 0.0) / 0.5))

                    Behavior on height {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                    color: launcherCardHover.hovered
                        ? Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.listHoverOpacity)
                        : Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)
                    border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.4)
                    border.width: 1

                    Behavior on color {
                        ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
                    }

                    Behavior on border.color {
                        ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
                    }

                    // Subtle gradient overlay for glass depth.
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, 0.03) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }

                    // Top-edge glass highlight strip.
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    // Inset container so the launcher's search bar (radius 12)
                    // aligns concentrically inside the card frame (radius 16).
                    Item {
                        anchors.fill: parent
                        anchors.margins: 6

                        IslandLauncher {
                            id: compactLauncher
                            anchors.fill: parent
                            compact: true
                        }
                    }

                    HoverHandler {
                        id: launcherCardHover
                    }
                }

                // Thin glass separator between the search launcher and the
                // control-center card grid.  Anchored mid-gap with a staggered
                // fade-in that trails the launcher card slightly, making the
                // boundary feel designed rather than a plain spacing break.
                Rectangle {
                    anchors.top: launcherCard.bottom
                    anchors.topMargin: 4
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    height: 1
                    color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.12)
                    opacity: Math.min(1, Math.max(0, (overviewPage._overviewProgress - 0.0) / 0.55))
                }

                // Top zone: time+todo card (58 %) beside quick-toggle
                // panel with settings button (42 %).  Cascade tier 2 —
                // reveals after the search bar and separator have settled.
                Row {
                    id: topRow
                    anchors.top: launcherCard.bottom
                    anchors.topMargin: 10
                    width: parent.width
                    height: 130
                    spacing: 10
                    opacity: Math.min(1, Math.max(0, (overviewPage._overviewProgress - 0.0) / 0.65))

                    OverviewClockCard {
                        width: Math.round((parent.width - 10) * 0.58)
                        height: parent.height
                        onClicked: Services.IslandService.openPage("calendar")
                    }

                    OverviewSettingsCard {
                        width: parent.width - Math.round((parent.width - 10) * 0.58) - 10
                        height: parent.height
                        brightnessValue: Services.BrightnessService.brightness
                        onBrightnessClicked: {
                            // Open settings center scrolled to brightness —
                            // pass "亮度" as the initial filter so the correct
                            // row is visible on arrival.
                            Services.IslandService.settingsInitialFilter = "亮度"
                            Services.IslandService.showSettingsCenter()
                        }
                        onOpenSettings: {
                            Services.IslandService.showSettingsCenter()
                        }
                    }
                }

                // Middle zone: large media card (62 %) beside notification
                // preview (38 %).  Cascade tier 3 — starts revealing after the
                // top row is already mid-entrance.
                Row {
                    id: middleRow
                    anchors.top: topRow.bottom
                    anchors.topMargin: 10
                    width: parent.width
                    height: 190
                    spacing: 10
                    opacity: Math.min(1, Math.max(0, (overviewPage._overviewProgress - 0.10) / 0.65))

                    OverviewMediaCard {
                        width: Math.round((parent.width - 10) * 0.62)
                        height: parent.height
                        onClicked: Services.IslandService.openPage("media")
                    }

                    OverviewNotificationCard {
                        width: parent.width - Math.round((parent.width - 10) * 0.62) - 10
                        height: parent.height
                        onClicked: Services.IslandService.showNotifications()
                    }
                }

            }

            // Return from any detail page to the overview layout.
            Rectangle {
                id: detailBackButton

                anchors.top: parent.top
                anchors.left: parent.left
                width: 38
                height: 34
                z: 4
                opacity: root.overviewPageVisible ? 0 : 1
                visible: opacity > 0.01
                enabled: !root.overviewPageVisible
                radius: 14
                color: backMouse.containsMouse
                    ? Qt.rgba(Services.Color.mPrimary.r, Services.Color.mPrimary.g, Services.Color.mPrimary.b, 0.22)
                    : Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)
                border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.55)
                border.width: 1

                Behavior on opacity {
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }

                Behavior on color {
                    ColorAnimation { duration: Services.Motion.color.transitionDuration; easing.type: Services.Motion.color.transitionEasing }
                }

                Services.FluidText {
                    anchors.centerIn: parent
                    text: "‹"
                    color: Services.Color.mOnSurface
                    basePixelSize: 20
                }

                MouseArea {
                    id: backMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Services.IslandService.showOverview()
                }
            }

            // Keep the current page below the switcher inside the same panel shell.
            Item {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                Loader {
                    id: detailPageLoader

                    anchors.fill: parent
                    active: !root.overviewPageVisible
                    sourceComponent: root.launcherPageVisible
                        ? launcherPanelPage
                        : (root.settingsCenterVisible
                            ? settingsCenterPage
                            : (root.notificationsPageVisible
                                ? notificationsCenterPage
                                : (root.mediaPageVisible
                                    ? mediaDetailPage
                                    : (root.calendarPageVisible ? calendarDetailPage : weatherDetailPage))))

                    onLoaded: {
                        root.focusExpandedPage()
                    }
                }
            }
        }

        // --- Window-hint extension: the workspace stage rendered inside the
        // island body. In the launcher-conflict case only the title row shows
        // (titleRowOnly) and overlays the launcher's lower half; otherwise the
        // full vertical workspace stage fills the extended body. ---
        Item {
            id: windowHintContent
            anchors.fill: parent
            anchors.topMargin: root.collapsedH + 12
            opacity: Services.IslandService.windowHintActive || !hintStage.exitComplete ? 1 : 0
            visible: opacity > 0.01
            z: 0

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            WorkspaceHint.WorkspaceHintStageView {
                id: hintStage

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: stageWidth
                height: stageHeight

                hintData: Services.WindowHintService.activeHint
                active: Services.IslandService.windowHintActive
                titleRowOnly: root.hintLauncherConflict
                stageTargetY: 12
                screenWidth: Screen.width
                capsuleEdgeInset: root.earRadius
            }
        }

        // Keep one collapsed-island click layer so left-click expansion and
        // background right-click menu opening do not starve each other.
        MouseArea {
            anchors.fill: parent
            enabled: !Services.IslandService.expanded
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            propagateComposedEvents: true
            onClicked: (mouse) => {
                if (mouse.button === Qt.LeftButton) {
                    if (!Services.BarLayoutService.settingsMode)
                        Services.IslandService.toggle()
                    return
                }

                var scenePos = root.mapToItem(null, mouse.x, mouse.y)
                Services.TrayMenuService.close()
                Services.BarLayoutService.openContextMenu(scenePos.x, "", "", root.screenName)
            }
        }
    }

    // Render the launcher page inside the shared bottom panel.
    Component {
        id: launcherPanelPage

        IslandLauncher {
            anchors.fill: parent
        }
    }

    // Render the settings page inside the shared bottom panel.
    Component {
        id: settingsCenterPage

        Settings.SettingsContent {
            anchors.fill: parent
        }
    }

    // Render the notification center inside the shared bottom panel.
    Component {
        id: notificationsCenterPage

        NotificationCenterView {
            anchors.fill: parent
        }
    }

    // Render the media detail page inside the shared bottom panel.
    Component {
        id: mediaDetailPage

        MediaDetailView {
            anchors.fill: parent
        }
    }

    // Render the calendar placeholder page inside the shared bottom panel.
    Component {
        id: calendarDetailPage

        PlaceholderDetailView {
            anchors.fill: parent
            title: "日历"
            body: "这里会显示今日日程、未来几天概览和待办。"
        }
    }

    // Render the weather placeholder page inside the shared bottom panel.
    Component {
        id: weatherDetailPage

        PlaceholderDetailView {
            anchors.fill: parent
            title: "天气"
            body: "这里会显示温度、降雨、风速和小时预报。"
        }
    }
}
