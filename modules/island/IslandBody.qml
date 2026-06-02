import QtQuick
import "../bar" as Bar
import "../workspace-hint" as WorkspaceHint
import "../../services" as Services

// Animated island body: expands from collapsed clock to full launcher panel.
// Delegates the spring-morphing attached-island silhouette (ears, blur strips,
// blur lead, body clip) to AttachedIslandSurface and only owns the collapsed
// vs expanded content and its interaction handlers.
Item {
    id: root

    required property string screenName
    property bool _spectrumRegistered: false

    // Geometry constants.
    readonly property int collapsedW: 220
    readonly property int collapsedH: Services.BarLayoutService.barHeight
    readonly property int expandedW: 480
    readonly property int expandedH: 420
    readonly property int earRadius: 24
    readonly property int collapsedHorizontalPadding: 16
    readonly property int hoverWLift: 12
    readonly property int hoverHLift: 4
    readonly property int hoverRadiusLift: 2
    readonly property color surfaceColor: Qt.alpha(Services.Color.mSurface, Services.SettingsService.panelSurfaceOpacity)
    readonly property var centerWidgets: Services.BarLayoutService.sectionWidgets("center")
    readonly property bool showManagedCenterWidgets: !Services.IslandService.expanded
        && root.centerWidgets.length > 0
    readonly property bool showCenterSpectrum: root.showManagedCenterWidgets
        && !Services.IslandService.windowHintActive
    readonly property real collapsedContentWidth: collapsedRow.implicitWidth > 0
        ? collapsedRow.implicitWidth + collapsedHorizontalPadding
        : collapsedW
    // When a transient message is active the collapsed body grows downward to
    // fit the message card (clock stays in the top row); height tracks the card.
    readonly property real messageContentHeight: Services.TransientMessageService.active
        ? Math.max(collapsedH, collapsedRow.implicitHeight + 12)
        : collapsedH

    // Window-hint extension geometry, sized to the live stage. When the hint is
    // held without the launcher, the island grows to wrap the full vertical
    // workspace stage; when the launcher is also open, the island keeps its
    // expanded size and only the title row overlays the launcher's lower half.
    readonly property bool hintLauncherConflict: Services.IslandService.expanded
        && Services.IslandService.windowHintActive
    readonly property int windowHintW: hintStage.stageWidth + 32
    readonly property int windowHintH: hintStage.stageHeight + 24

    // Target dimensions driven by island state and passive hover intent;
    // fed into the surface which owns the spring deformation. Launcher expansion
    // takes priority; the window hint only extends the resting island.
    property int targetW: Services.IslandService.expanded
        ? expandedW
        : (Services.IslandService.windowHintActive
            ? windowHintW
            : collapsedContentWidth + (hoverHandler.hovered ? hoverWLift : 0))
    property int targetH: Services.IslandService.expanded
        ? expandedH
        : (Services.IslandService.windowHintActive
            ? windowHintH
            : messageContentHeight + (hoverHandler.hovered ? hoverHLift : 0))
    property int targetR: Services.IslandService.expanded
        ? 24
        : (Services.IslandService.windowHintActive
            ? 24
            : 14 + (hoverHandler.hovered ? hoverRadiusLift : 0))

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

    Component.onCompleted: syncSpectrumRegistration()
    Component.onDestruction: {
        if (root._spectrumRegistered)
            Services.SpectrumService.unregisterComponent("island-center:" + root.screenName)
    }
    onShowCenterSpectrumChanged: syncSpectrumRegistration()

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

        // --- Collapsed content: center widgets or fallback clock ---
        Item {
            id: collapsedContent
            anchors.fill: parent
            // Fade the clock/center widgets out whenever the body morphs into
            // either the launcher or the window-hint stage, so the collapsed
            // content never overlaps the extended panel.
            opacity: (Services.IslandService.expanded || Services.IslandService.windowHintActive) ? 0 : 1
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
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
                anchors.topMargin: Math.max(0, (root.collapsedH - childHeightHint) / 2)
                readonly property real childHeightHint: Math.max(
                    collapsedContentLoader.height, 18)
                spacing: 8

                // Wrap the collapsed center content so the spectrum can size to the managed widget block.
                Item {
                    id: collapsedContentFrame

                    anchors.top: parent.top
                    width: collapsedContentLoader.width
                    height: collapsedContentLoader.height

                    // Keep the spectrum behind the managed center widgets inside the collapsed island band.
                    Item {
                        anchors.fill: parent
                        visible: root.showCenterSpectrum && width > 0 && height > 0 && (opacity > 0.01 || !Services.SpectrumService.isIdle)
                        z: -1
                        clip: true
                        opacity: Services.SpectrumService.isIdle ? 0 : 1

                        Behavior on opacity {
                            NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
                        }

                        Bar.DockzoneSpectrum {
                            anchors.fill: parent
                            anchors.margins: 6
                            values: Services.SpectrumService.values
                        }
                    }

                    Loader {
                        id: collapsedContentLoader

                        anchors.top: parent.top
                        sourceComponent: root.showManagedCenterWidgets ? managedCenterWidgets : fallbackClock
                    }
                }

                // Transient message card beside the clock; zero size when idle.
                TransientMessageBand {
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

        // --- Expanded content: search + results ---
        Item {
            id: expandedContent
            anchors.fill: parent
            anchors.margins: 16
            anchors.topMargin: 12
            opacity: Services.IslandService.expanded ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            IslandLauncher {
                anchors.fill: parent
                visible: parent.visible
            }
        }

        // --- Window-hint extension: the workspace stage rendered inside the
        // island body. In the launcher-conflict case only the title row shows
        // (titleRowOnly) and overlays the launcher's lower half; otherwise the
        // full vertical workspace stage fills the extended body. ---
        Item {
            id: windowHintContent
            anchors.fill: parent
            opacity: Services.IslandService.windowHintActive ? 1 : 0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            WorkspaceHint.WorkspaceHintStageView {
                id: hintStage

                // Center the stage; align it to the bottom of the body during
                // the launcher conflict so the title row sits below the launcher.
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.hintLauncherConflict
                    ? parent.height - height - 12
                    : (parent.height - height) / 2
                width: stageWidth
                height: stageHeight

                hintData: Services.WindowHintService.activeHint
                active: Services.IslandService.windowHintActive
                titleRowOnly: root.hintLauncherConflict
                stageTargetY: 12
                screenWidth: Screen.width
            }
        }

        // Keep left-click expansion on the whole collapsed island surface.
        MouseArea {
            anchors.fill: parent
            enabled: !Services.IslandService.expanded
                && !Services.BarLayoutService.settingsMode
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: Services.IslandService.toggle()
        }

        // Right-click opens the center layout menu across the collapsed island.
        MouseArea {
            anchors.fill: parent
            enabled: !Services.IslandService.expanded && !root.showManagedCenterWidgets
            acceptedButtons: Qt.RightButton
            onClicked: (mouse) => {
                var scenePos = root.mapToItem(null, mouse.x, mouse.y)
                Services.BarLayoutService.openContextMenu(scenePos.x, "", "", root.screenName)
            }
        }
    }
}
