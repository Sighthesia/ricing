import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import ".."
import "../../lazerbar"

// StatusNotifier tray icons with activate and secondary actions.
Item {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    implicitWidth: trayRow.implicitWidth
    implicitHeight: LazerTheme.barWidgetHeight

    // Opt-in hover intent publication for BarPopupHost (per-delegate).
    signal popupRequested(var intent)
    signal popupCloseRequested()
    signal popupAnchorUpdate(var intent)

    // Track current hovered delegate for anchor updates when the tray moves.
    property var hoveredTrayModel: null
    property Item hoveredTrayDelegate: null

    // Build hover intent for a specific tray delegate.
    function resolveIconSource(source) {
        var normalized = String(source || "").trim()
        if (normalized === "" || normalized.indexOf(":") >= 0)
            return normalized
        if (normalized.charAt(0) === "." || normalized.charAt(0) === "/")
            return Qt.resolvedUrl(normalized)
        return String(Quickshell.iconPath(normalized, true) || "")
    }

    function buildTrayIntent(modelData, delegateItem) {
        var centerX = 0
        try { centerX = delegateItem.mapToGlobal(delegateItem.width / 2, delegateItem.height / 2).x } catch (e) {
            try { centerX = delegateItem.mapToItem(root, delegateItem.width / 2, 0).x + root.mapToGlobal(0, 0).x } catch (e2) { centerX = 0 }
        }
        if (!isFinite(centerX)) centerX = 0
        var titleText = (delegateItem && delegateItem.label) ? delegateItem.label : (modelData.title || modelData.tooltipTitle || modelData.id || "Tray item")
        var iconSrc = resolveIconSource((delegateItem && delegateItem.iconSource)
                ? delegateItem.iconSource : (modelData.icon || ""))
        var summaryText = modelData.tooltipTitle || modelData.tooltipSubTitle || ""
        return {
            widgetId: root.widgetId,
            instanceKey: root.instanceKey,
            screenName: root.screenName,
            title: titleText,
            iconSource: iconSrc,
            summary: summaryText,
            actionKind: "tray",
            anchorX: centerX,
            payload: {
                trayModel: modelData,
                trayItem: modelData,
                title: titleText,
                iconSource: iconSrc,
                onActivate: function() { try { modelData.activate() } catch (e) {} },
                onSecondaryActivate: function() { try { modelData.secondaryActivate() } catch (e) {} }
            }
        }
    }

    onXChanged: if (hoveredTrayDelegate) popupAnchorUpdate(buildTrayIntent(hoveredTrayModel, hoveredTrayDelegate))
    onWidthChanged: if (hoveredTrayDelegate) popupAnchorUpdate(buildTrayIntent(hoveredTrayModel, hoveredTrayDelegate))

    Row {
        id: trayRow

        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: SystemTray.items && SystemTray.items.values
                   ? SystemTray.items.values : []

            // One hover square per tray item; icons stay theme-provided.
            delegate: Item {
                id: trayIcon

                required property var modelData

                readonly property bool hovered: iconHover.hovered
                readonly property string label:
                    modelData.title || modelData.tooltipTitle || modelData.id || "Tray item"
                readonly property string iconSource: {
                    var icon = modelData ? (modelData.icon || "") : ""
                    // SNI icons may carry a non-theme path suffix that the
                    // image provider cannot resolve without conversion.
                    var pathSplit = icon.indexOf("?path=")
                    if (pathSplit < 0)
                        return root.resolveIconSource(icon)
                    var name = icon.substring(0, pathSplit)
                    var dir = icon.substring(pathSplit + 6)
                    return root.resolveIconSource("file://" + dir + "/"
                            + name.substring(name.lastIndexOf("/") + 1))
                }

                width: LazerTheme.barWidgetHeight
                height: LazerTheme.barWidgetHeight
                Accessible.role: Accessible.Button
                Accessible.name: label

                Rectangle {
                    anchors.fill: parent
                    radius: 0
                    color: trayIcon.hovered ? LazerTheme.hoverFill : "transparent"

                    Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                }

                IconImage {
                    anchors.centerIn: parent
                    width: LazerTheme.barGlyphSize
                    height: LazerTheme.barGlyphSize
                    asynchronous: true
                    backer.fillMode: Image.PreserveAspectFit
                    source: trayIcon.iconSource
                    // Failed loads stay invisible instead of rendering blank.
                    opacity: status === Image.Ready ? 1 : 0
                }

                HoverHandler {
                    id: iconHover
                    objectName: "trayHoverHandler"
                    onHoveredChanged: {
                        if (hovered) {
                            root.hoveredTrayModel = trayIcon.modelData
                            root.hoveredTrayDelegate = trayIcon
                            root.popupRequested(root.buildTrayIntent(trayIcon.modelData, trayIcon))
                        } else {
                            if (root.hoveredTrayDelegate === trayIcon) {
                                root.hoveredTrayModel = null
                                root.hoveredTrayDelegate = null
                                root.popupCloseRequested()
                            }
                        }
                    }
                }

                // Update anchor while the delegate or bar layout moves.
                onXChanged: if (iconHover.hovered) root.popupAnchorUpdate(root.buildTrayIntent(trayIcon.modelData, trayIcon))

                TapHandler {
                    objectName: "trayActivateTap"
                    acceptedButtons: Qt.LeftButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: trayIcon.modelData.activate()
                }

                TapHandler {
                    objectName: "traySecondaryTap"
                    acceptedButtons: Qt.RightButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: trayIcon.modelData.secondaryActivate()
                }
            }
        }
    }
}
