import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import ".."
import "../../lazerbar"
import "../../../services" as Services

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
                        return icon
                    var name = icon.substring(0, pathSplit)
                    var dir = icon.substring(pathSplit + 6)
                    return "file://" + dir + "/" + name.substring(name.lastIndexOf("/") + 1)
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
                }

                // Hover opens this item's DBus menu in the shared popup host.
                WidgetHoverPopup {
                    kind: "tray"
                    payload: trayIcon.modelData
                    enabled: trayIcon.modelData && trayIcon.modelData.hasMenu
                }

                // Menu-only items surface their menu on any press intent.
                function requestMenu() {
                    if (!trayIcon.modelData || !trayIcon.modelData.hasMenu)
                        return
                    var anchorX = trayIcon.mapToItem(null, 0, 0).x
                    Services.BarPopupService.open("tray", anchorX, trayIcon.modelData)
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: {
                        if (trayIcon.modelData.onlyMenu && trayIcon.modelData.hasMenu) {
                            trayIcon.requestMenu()
                            return
                        }
                        trayIcon.modelData.activate()
                    }
                }

                // Right click prefers the full menu; fall back to the SNI
                // secondary action when the item ships no menu.
                TapHandler {
                    acceptedButtons: Qt.RightButton
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: {
                        if (trayIcon.modelData.hasMenu) {
                            trayIcon.requestMenu()
                            return
                        }
                        trayIcon.modelData.secondaryActivate()
                    }
                }
            }
        }
    }
}
