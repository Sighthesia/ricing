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
    readonly property int expandedW: Math.min(620, Screen.width - 48)
    readonly property int expandedH: Math.min(620, Screen.height - 96)
    readonly property int expandedWidgetClearance: Math.max(root.collapsedH, root.messageContentHeight) + 12
    readonly property int expandedInnerGap: 12
    readonly property int expandedNavHeight: 42
    readonly property color surfaceColor: Qt.alpha(Services.Color.mSurface, Services.SettingsService.panelSurfaceOpacity)
    readonly property var centerWidgets: Services.BarLayoutService.sectionWidgets("center")
    readonly property bool showManagedCenterWidgets: root.centerWidgets.length > 0
    readonly property bool showCenterSpectrum: root.showManagedCenterWidgets
        && !Services.IslandService.windowHintActive
        && !Services.IslandService.expanded
    readonly property bool launcherPageVisible: Services.IslandService.expanded
        && Services.IslandService.panelPage === "launcher"
    readonly property bool settingsCenterVisible: Services.IslandService.expanded
        && Services.IslandService.panelPage === "settings-center"
    readonly property bool notificationsPageVisible: Services.IslandService.expanded
        && Services.IslandService.panelPage === "notifications"
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
    readonly property real collapsedRevealProgress: root.showManagedCenterWidgets
        && !Services.IslandService.expanded
        && !Services.IslandService.windowHintActive
        ? Math.max(0, Math.min(1, (root.collapsedWidthProgress - 0.98) / 0.02))
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
    readonly property real centerWidgetPickerW: centerWidgetPickerMeasure.implicitWidth
    readonly property real centerWidgetPickerH: centerWidgetPickerMeasure.implicitHeight
    readonly property real centerWidgetPickerClipInset: Math.max(6, surface.bodyRadius * 0.45)

    // Window-hint extension geometry, sized to the live stage. When the hint is
    // held without the launcher, the island grows to wrap the full vertical
    // workspace stage; when the launcher is also open, the island keeps its
    // expanded size and only the title row overlays the launcher's lower half.
    readonly property bool hintLauncherConflict: Services.IslandService.expanded
        && Services.IslandService.windowHintActive
    readonly property int windowHintW: Math.min(hintStage.stageWidth + 32, Screen.width - root.earRadius * 2)
    readonly property int windowHintH: root.collapsedH + hintStage.stageHeight + 24

    // Target dimensions reuse the expanded island body instead of a second panel.
    property int targetW: Services.IslandService.expanded
        ? expandedW
        : (root.hostsCenterWidgetPicker
        ? centerWidgetPickerW
        : (root.hostsCenterContextMenu
        ? Math.max(collapsedCapsuleWidth, centerContextMenuW)
        : (Services.IslandService.windowHintActive
        ? windowHintW
        : collapsedCapsuleWidth)))
    property int targetH: Services.IslandService.expanded
        ? expandedH
        : (root.hostsCenterWidgetPicker
        ? collapsedH + centerWidgetPickerH + 8 + centerWidgetPickerClipInset
        : (root.hostsCenterContextMenu
        ? Math.max(messageContentHeight, collapsedH) + centerContextMenuH + 8 + centerContextMenuClipInset
        : (Services.IslandService.windowHintActive
        ? windowHintH
        : messageContentHeight + (hoverHandler.hovered ? hoverHLift : 0))))
    property int targetR: Services.IslandService.expanded
        ? 24
        : (root.hostsCenterWidgetPicker
        ? 14
        : (root.hostsCenterContextMenu
        ? 14
        : (Services.IslandService.windowHintActive
        ? 24
        : 14 + (hoverHandler.hovered ? hoverRadiusLift : 0))))

    // Size mirrors the surface's animated geometry so external consumers
    // (IslandWindow hit region) keep tracking the live island bounds.
    width: surface.width
    height: surface.height
    implicitWidth: width
    implicitHeight: height

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

    Component.onCompleted: {
        syncSpectrumRegistration()
        Services.IslandService.setCenterSurfaceWidth(root.screenName, width)
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
                opacity: root.collapsedRevealProgress

                Behavior on opacity {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }

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

                    Component.onCompleted: if (Services.IslandService.expanded) forceActiveFocus()

                    Connections {
                        target: Services.IslandService

                        function onExpandedChanged() {
                            if (Services.IslandService.expanded)
                                expandedContent.forceActiveFocus()
                        }
                    }

                    Keys.onEscapePressed: Services.IslandService.close()

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

            // Keep the mode switcher inside the expanded panel header.
            Rectangle {
                id: expandedModeStrip

                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width, 420)
                height: root.expandedNavHeight
                radius: Math.round(height / 2)
                color: Qt.rgba(Services.Color.mOnSurface.r, Services.Color.mOnSurface.g, Services.Color.mOnSurface.b, MenuVisuals.hoverOpacity)
                border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.7)
                border.width: 1

                // Lay out the three pages as a segmented control.
                Row {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    IslandPanelNavButton {
                        width: (parent.width - 8) / 3
                        height: parent.height
                        label: "启动器"
                        selected: root.launcherPageVisible
                        firstSegment: true
                        onClicked: Services.IslandService.showLauncher()
                    }

                    IslandPanelNavButton {
                        width: (parent.width - 8) / 3
                        height: parent.height
                        label: "设置中心"
                        selected: root.settingsCenterVisible
                        onClicked: Services.IslandService.showSettingsCenter()
                    }

                    IslandPanelNavButton {
                        width: (parent.width - 8) / 3
                        height: parent.height
                        label: "通知中心"
                        selected: root.notificationsPageVisible
                        lastSegment: true
                        onClicked: Services.IslandService.showNotifications()
                    }
                }
            }

            // Keep the current page below the switcher inside the same panel shell.
            Item {
                anchors.top: expandedModeStrip.bottom
                anchors.topMargin: root.expandedInnerGap
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                Loader {
                    anchors.fill: parent
                    sourceComponent: root.launcherPageVisible
                        ? launcherPanelPage
                        : (root.settingsCenterVisible
                            ? settingsCenterPage
                            : notificationsCenterPage)

                    onLoaded: {
                        if (item && root.launcherPageVisible && item.focusSearch) {
                            item.focusSearch()
                        }
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
}
