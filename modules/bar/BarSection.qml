import "."
import "./tray" as Tray
import "../../services" as Services
import "../../services/barlayout/BarLayoutSections.js" as BarLayoutSections
import QtQuick

// Render a single ordered section inside a shared attached-island surface.
Item {
    id: root

    required property string sectionName
    required property string screenName
    required property real screenX
    required property real screenY
    required property real screenWidth
    required property real screenHeight
    property real blurSourceOffsetX: 0
    property real sectionPushOffsetX: 0
    property bool floatingValidationIntent: false
    readonly property var sectionModel: Services.BarLayoutService.sectionWidgets(sectionName)
    readonly property bool hasSectionContent: root.sectionModel.length > 0
    readonly property bool canOpenWidgetPicker: Services.BarLayoutService.layoutReady
    readonly property var blurParts: surfaceLoader.item ? surfaceLoader.item.blurParts : []
    readonly property real residualPushOffsetX: surfaceLoader.item ? surfaceLoader.item.residualPushOffsetX : 0
    readonly property bool hostsContextMenu: Services.BarLayoutService.contextMenuVisible
        && !Services.BarLayoutService.widgetPickerVisible
        && Services.BarLayoutService.contextMenuScreenName === root.screenName
        && Services.BarLayoutService.contextMenuSection === root.sectionName
    readonly property bool hostsWidgetPicker: Services.BarLayoutService.widgetPickerVisible
        && Services.BarLayoutService.widgetPickerScreenName === root.screenName
        && Services.BarLayoutService.widgetPickerSection === root.sectionName
    readonly property bool hostsWidgetSettings: Services.BarLayoutService.widgetSettingsVisible
        && Services.BarLayoutService.widgetSettingsScreenName === root.screenName
        && Services.BarLayoutService.widgetSettingsSection === root.sectionName
    readonly property string surfaceState: root.sectionName === "center"
        ? ((root.hasSectionContent || root.hostsContextMenu || root.hostsWidgetPicker || root.hostsWidgetSettings)
            ? (root.floatingValidationIntent ? "floating" : "attached")
            : "hidden")
        : ((root.hasSectionContent || root.hostsContextMenu || root.hostsWidgetPicker || root.hostsWidgetSettings) ? "attached" : "hidden")
    property var _dockzoneExpandHeights: ({})
    property real dockzoneContentExpandHeight: 0

    implicitHeight: surfaceLoader.item ? surfaceLoader.item.implicitHeight : Services.BarLayoutService.barHeight
    implicitWidth: root.hasSectionContent
        ? (surfaceLoader.item ? surfaceLoader.item.implicitWidth : 0)
        : (root.canOpenWidgetPicker ? 72 : 0)
    width: implicitWidth
    height: implicitHeight

    function reportWidgetDockzoneExpandHeight(instanceKey, expandHeight) {
        if (!instanceKey)
            return

        var nextMap = Object.assign({}, root._dockzoneExpandHeights)
        var resolvedHeight = Math.max(0, expandHeight || 0)
        if (resolvedHeight > 0)
            nextMap[instanceKey] = resolvedHeight
        else
            delete nextMap[instanceKey]

        root._dockzoneExpandHeights = nextMap

        var nextHeight = 0
        var keys = Object.keys(nextMap)
        for (var index = 0; index < keys.length; index += 1)
            nextHeight = Math.max(nextHeight, nextMap[keys[index]])

        root.dockzoneContentExpandHeight = nextHeight
    }

    // Preserve a small hit target so an empty dockzone can still reopen the widget picker.
    MouseArea {
        anchors.fill: parent
        enabled: !root.hasSectionContent && root.canOpenWidgetPicker
        acceptedButtons: Qt.RightButton
        hoverEnabled: enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: (mouse) => {
            var barPos = root.mapToItem(root.parent, mouse.x, mouse.y)
            var barContent = root.parent

            while (barContent && !barContent.openWidgetContextMenu) {
                barContent = barContent.parent
            }

            if (barContent && barContent.openWidgetContextMenu) {
                var scenePos = root.mapToItem(null, mouse.x, mouse.y)
                Services.TrayMenuService.close()
                barContent.openWidgetContextMenu("", "", scenePos.x, root.screenName, scenePos.x)
            }
        }
    }

    // Route every section through the unified surface owner.
    Loader {
        id: surfaceLoader

        active: true
        sourceComponent: surfaceShell
    }

    // Unified path: owner-managed surface with section-aware model-driven rendering.
    Component {
        id: surfaceShell

        Item {
            id: surfaceRoot
            readonly property var blurParts: dockzone.blurParts
            readonly property real residualPushOffsetX: dockzone.residualPushOffsetX

            implicitWidth: dockzone.implicitWidth
            implicitHeight: dockzone.implicitHeight
            width: implicitWidth
            height: implicitHeight

            function syncCenterFloatingValidationIntent() {
                if (root.sectionName !== "center")
                    return;

                var hasLocalPointerIntent = false;

                for (var i = 0; i < sectionRow.children.length; ++i) {
                    var child = sectionRow.children[i];
                    if (child && child.localPointerIntent) {
                        hasLocalPointerIntent = true;
                        break;
                    }
                }

                root.floatingValidationIntent = hasLocalPointerIntent;
            }

            Component.onCompleted: syncCenterFloatingValidationIntent()

            // Track section hover passively so child mouse areas do not retrigger it.
            HoverHandler {
                id: sectionHoverHandler

                enabled: root.hasSectionContent
            }

            DockzoneSurfaceRoot {
                id: dockzone

                section: root.sectionName
                screenName: root.screenName
                screenX: root.screenX
                screenY: root.screenY
                screenWidth: root.screenWidth
                screenHeight: root.screenHeight
                windowX: surfaceRoot.x + root.x
                blurSourceOffsetX: root.blurSourceOffsetX
                sectionPushOffsetX: root.sectionPushOffsetX
                surfaceHeight: Services.BarLayoutService.barHeight
                contentWidth: sectionRow.implicitWidth
                contentHeight: sectionRow.implicitHeight
                surfaceState: root.surfaceState
                hoverIntent: sectionHoverHandler.hovered
                anchors.fill: parent

                // Host the tray DBus menu by expanding this dockzone downward
                // (island-style) when the menu is open and its anchor icon lives
                // in this section. The body grows by the menu height and widens
                // to the menu width; the menu renders in the body below the icon
                // row. expandHeight/expandWidth are zero for every other section
                // and when closed, so normal dockzones are unaffected.
                readonly property real rowScreenLeft: sectionRow.mapToItem(null, 0, 0).x
                readonly property real rowScreenRight: sectionRow.mapToItem(null, sectionRow.width, 0).x
                readonly property bool hostsTrayMenu: root.hasSectionContent
                    && Services.TrayMenuService.visible
                    && Services.TrayMenuService.anchorX >= rowScreenLeft - 24
                    && Services.TrayMenuService.anchorX <= rowScreenRight + 24
                readonly property bool hostsContextMenu: root.hostsContextMenu && !hostsTrayMenu
                // Natural menu size measured by a hidden, unclipped instance so
                // it is independent of the clipped render tree below (whose size
                // is driven by the Loader, not the content).
                readonly property real menuW: trayMenuMeasure.implicitWidth
                readonly property real menuH: trayMenuMeasure.implicitHeight
                readonly property real contextMenuW: contextMenuMeasure.implicitWidth
                readonly property real contextMenuH: contextMenuMeasure.implicitHeight
                readonly property real widgetPickerW: widgetPickerMeasure.implicitWidth
                readonly property real widgetPickerH: widgetPickerMeasure.implicitHeight
                // Keep the menu a little inside the lower glass contour during
                // the expand so foreground text/icons cannot peek through the
                // transparent rounded corners before the body reaches full size.
                readonly property real menuClipInset: Math.max(10, dockzone.bodyRadius * 0.75)
                // The widget picker is a much taller body than the context menu,
                // so keep its lower clip guard shallower to reduce dead space.
                readonly property real pickerClipInset: Math.max(6, dockzone.bodyRadius * 0.45)
                readonly property real widgetSettingsW: widgetSettingsMeasure.implicitWidth
                readonly property real widgetSettingsH: widgetSettingsMeasure.implicitHeight
                readonly property real activeMenuW: hostsTrayMenu ? menuW : (hostsContextMenu ? contextMenuW : (hostsWidgetPicker ? widgetPickerW : widgetSettingsW))
                readonly property real activeMenuH: hostsTrayMenu ? menuH : (hostsContextMenu ? contextMenuH : (hostsWidgetPicker ? widgetPickerH : widgetSettingsH))
                readonly property real contentExpandH: root.dockzoneContentExpandHeight
                readonly property real menuAnchorX: Services.BarLayoutService.contextMenuX
                    - surfaceRoot.mapToItem(null, 0, 0).x

                // Measure the tray menu without clipping so the host can expand first.
                Tray.TrayMenuView {
                    id: trayMenuMeasure
                    visible: false
                    enabled: false
                    rootHandle: Services.TrayMenuService.menuHandle
                }

                // Measure the context menu without clipping so the host can expand first.
                BarContextMenuView {
                    id: contextMenuMeasure
                    visible: false
                    enabled: false
                }

                // Measure the widget picker without clipping so the host can expand first.
                WidgetPickerView {
                    id: widgetPickerMeasure
                    visible: false
                    enabled: false
                }

                // Measure the widget settings without clipping so the host can expand first.
                WidgetSettingsView {
                    id: widgetSettingsMeasure
                    visible: false
                    enabled: false
                }

                expandHeight: (hostsTrayMenu || hostsContextMenu || root.hostsWidgetPicker || root.hostsWidgetSettings)
                    ? (activeMenuH + 8 + (root.hostsWidgetPicker ? dockzone.pickerClipInset : dockzone.menuClipInset))
                    : contentExpandH
                expandWidth: (hostsTrayMenu || hostsContextMenu || root.hostsWidgetPicker || root.hostsWidgetSettings) ? activeMenuW : 0

                Behavior on expandHeight {
                    SpringAnimation {
                        spring: Services.Motion.islandExpand.spring
                        mass: Services.Motion.islandExpand.mass
                        damping: Services.Motion.islandExpand.dampingExpand
                        epsilon: Services.Motion.islandExpand.epsilon
                    }
                }
                Behavior on expandWidth {
                    SpringAnimation {
                        spring: Services.Motion.islandExpand.spring
                        mass: Services.Motion.islandExpand.mass
                        damping: Services.Motion.islandExpand.dampingExpand
                        epsilon: Services.Motion.islandExpand.epsilon
                    }
                }

                // Tray DBus menu rendered inside the expanded body, beneath the
                // icon row. The view owns its own viewport clipping, so the host
                // passes down the currently visible body width and height.
                Loader {
                    id: trayMenuLoader

                    active: dockzone.hostsTrayMenu || opacity > 0.01
                    z: 2
                    x: parent.bodyX + (parent.bodyWidth - width) / 2 + (root.sectionName === "right" ? parent.bodyShrinkX : (root.sectionName === "left" ? -parent.bodyShrinkX : 0))
                    y: parent.bodyY + parent.topBandHeight
                    width: Math.min(dockzone.menuW, dockzone.pushedBodyWidth)
                    height: Math.max(0, dockzone.bodyHeight - parent.topBandHeight - dockzone.menuClipInset)
                    opacity: dockzone.hostsTrayMenu ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Services.Motion.popup.opacityDuration
                            easing.type: Services.Motion.popup.opacityEasing
                        }
                    }

                    sourceComponent: Tray.TrayMenuView {
                        rootHandle: Services.TrayMenuService.menuHandle
                        viewportWidth: trayMenuLoader.width
                        viewportHeight: trayMenuLoader.height
                    }

                    // Keep the menu open while the pointer rests on it.
                    HoverHandler {
                        id: trayMenuHover
                        onHoveredChanged: Services.TrayMenuService.pointerInMenu = hovered
                    }
                }

                // Bar context menu rendered inside the expanded body beneath the
                // dockzone row so it shares the tray-style host surface.
                Loader {
                    id: contextMenuLoader

                    active: dockzone.hostsContextMenu || opacity > 0.01
                    z: 2
                    y: parent.bodyY + parent.topBandHeight
                    width: dockzone.pushedBodyWidth
                    height: Math.max(0, dockzone.bodyHeight - parent.topBandHeight - dockzone.menuClipInset)
                    opacity: dockzone.hostsContextMenu ? 1 : 0
                    x: parent.bodyX + (parent.bodyWidth - width) / 2 + (root.sectionName === "right" ? parent.bodyShrinkX : (root.sectionName === "left" ? -parent.bodyShrinkX : 0))

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Services.Motion.popup.opacityDuration
                            easing.type: Services.Motion.popup.opacityEasing
                        }
                    }

                    sourceComponent: BarContextMenuView {
                        viewportWidth: contextMenuLoader.width
                        viewportHeight: contextMenuLoader.height
                    }
                }

                // Widget picker rendered inside the expanded body beneath the
                // dockzone row so insertion browsing reuses the same host surface.
                Loader {
                    id: widgetPickerLoader

                    active: root.hostsWidgetPicker || opacity > 0.01
                    z: 2
                    y: parent.bodyY + parent.topBandHeight
                    width: dockzone.pushedBodyWidth
                    height: Math.max(0, dockzone.bodyHeight - parent.topBandHeight - dockzone.pickerClipInset)
                    opacity: root.hostsWidgetPicker ? 1 : 0
                    x: parent.bodyX + (parent.bodyWidth - width) / 2 + (root.sectionName === "right" ? parent.bodyShrinkX : (root.sectionName === "left" ? -parent.bodyShrinkX : 0))

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Services.Motion.popup.opacityDuration
                            easing.type: Services.Motion.popup.opacityEasing
                        }
                    }

                    sourceComponent: WidgetPickerView {
                        viewportWidth: widgetPickerLoader.width
                        viewportHeight: widgetPickerLoader.height
                    }
                }

                // Widget settings rendered inside the expanded body beneath the
                // dockzone row so its controls feel attached to the bar.
                Loader {
                    id: widgetSettingsLoader

                    active: dockzone.hostsWidgetSettings || opacity > 0.01
                    z: 2
                    y: parent.bodyY + parent.topBandHeight
                    width: dockzone.pushedBodyWidth
                    height: Math.max(0, dockzone.bodyHeight - parent.topBandHeight - dockzone.menuClipInset)
                    opacity: dockzone.hostsWidgetSettings ? 1 : 0
                    x: parent.bodyX + (parent.bodyWidth - width) / 2 + (root.sectionName === "right" ? parent.bodyShrinkX : (root.sectionName === "left" ? -parent.bodyShrinkX : 0))

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Services.Motion.popup.opacityDuration
                            easing.type: Services.Motion.popup.opacityEasing
                        }
                    }

                    sourceComponent: WidgetSettingsView {
                        viewportWidth: widgetSettingsLoader.width
                        viewportHeight: widgetSettingsLoader.height
                    }
                }


                // Lay out widgets for this section in order.
                Item {
                    id: sectionClip

                    z: 1
                    x: parent.visualBodyX
                    y: parent.bodyY
                    width: parent.pushedBodyWidth
                    height: parent.topBandHeight + dockzone.contentExpandH
                    clip: true

                    // Lay out widgets in the moving body while clipping to its visible width.
                    Row {
                        id: sectionRow

                        x: parent.parent.bodyX + (parent.parent.bodyWidth - width) / 2 + (root.sectionName === "right" ? parent.parent.bodyShrinkX : (root.sectionName === "left" ? -parent.parent.bodyShrinkX : 0)) - sectionClip.x
                        y: (parent.parent.topBandHeight - height) / 2
                        spacing: BarLayoutSections.widgetSpacing

                        // Instantiate each managed widget in sequence.
                        Repeater {
                            model: root.sectionModel.length

                            // Keep each widget wrapper as the delegate so its implicit size drives the row.
                            BarWidgetWrapper {
                                required property int index

                                screenName: root.screenName
                                widgetEntry: root.sectionModel[index]
                                widgetSource: Qt.resolvedUrl(widgetEntry.source)

                                onLocalPointerIntentChanged: surfaceRoot.syncCenterFloatingValidationIntent()
                                onDockzoneExpandHeightChanged: root.reportWidgetDockzoneExpandHeight(widgetInstanceKey, dockzoneExpandHeight)
                                Component.onCompleted: root.reportWidgetDockzoneExpandHeight(widgetInstanceKey, dockzoneExpandHeight)
                                Component.onDestruction: root.reportWidgetDockzoneExpandHeight(widgetInstanceKey, 0)
                            }

                        }

                    }
                }

            }

        }

    }

}
