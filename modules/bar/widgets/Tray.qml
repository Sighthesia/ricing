import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "../../../services" as Services

// System tray icon row. Hovering an icon that exposes a DBus menu expands the
// tray dockzone downward to host the menu (rendered by BarSection inside the
// dockzone body); left-click activates, right-click triggers the secondary
// action.
Item {
    id: root

    implicitWidth: trayRow.implicitWidth + 16
    implicitHeight: 30

    // Close the menu shortly after the pointer leaves both the icons and the
    // menu card, giving time to cross the small gap between bar and menu.
    Timer {
        id: closeTimer

        interval: 220
        onTriggered: {
            if (!Services.TrayMenuService.pointerInMenu)
                Services.TrayMenuService.close()
        }
    }

    // Cancel the pending close as soon as the pointer lands on the menu card.
    Connections {
        target: Services.TrayMenuService

        function onPointerInMenuChanged() {
            if (Services.TrayMenuService.pointerInMenu)
                closeTimer.stop()
            else if (Services.TrayMenuService.visible)
                closeTimer.restart()
        }
    }

    Row {
        id: trayRow

        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: SystemTray.items

            // Individual tray icon.
            Item {
                id: iconItem

                required property var modelData

                width: 22
                height: 22
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    anchors.margins: 1
                    source: iconItem.modelData.icon
                    sourceSize: Qt.size(20, 20)
                    smooth: true
                }

                // Open this item's menu (if any) anchored to the icon center.
                function openMenu() {
                    var centerX = iconItem.mapToItem(null, iconItem.width / 2, 0).x
                    Services.TrayMenuService.open(centerX, iconItem.modelData.menu)
                }

                // Passive hover detection: HoverHandler coexists with the wrapper's
                // right-click TapHandler instead of being starved of hover events by it.
                HoverHandler {
                    id: iconHover

                    // Hover drives the menu: open on enter, schedule close on leave.
                    onHoveredChanged: {
                        if (hovered) {
                            closeTimer.stop()
                            if (iconItem.modelData.hasMenu)
                                iconItem.openMenu()
                            else if (Services.TrayMenuService.visible)
                                closeTimer.restart()
                        } else {
                            closeTimer.restart()
                        }
                    }
                }

                // Clicks only; hover is owned by the HoverHandler above.
                MouseArea {
                    id: iconArea

                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: event => {
                        if (event.button === Qt.LeftButton)
                            iconItem.modelData.activate()
                        else if (event.button === Qt.RightButton)
                            iconItem.modelData.secondaryActivate()
                    }
                }
            }
        }
    }
}
