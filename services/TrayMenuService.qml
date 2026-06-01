pragma Singleton
import QtQuick

// Hold shared open-state for the hover-driven system tray menu so a tray icon
// and the floating menu window can communicate without a parent relationship.
QtObject {
    id: root

    // Whether the tray menu surface should currently be shown.
    property bool visible: false
    // Bar-window-local X (== screen X, both windows span full width) of the hovered icon center.
    property real anchorX: 0
    // The hovered tray item's DBusMenu handle (QsMenuHandle), bound into QsMenuOpener.
    property var menuHandle: null
    // True while the pointer is over the menu surface, so leaving the icon does not close it.
    property bool pointerInMenu: false

    // Open the menu for a given icon center X with its menu handle. Idempotent:
    // re-hovering the same already-open item only re-anchors, so jitter at the
    // icon edge does not re-trigger the open animation.
    function open(x, handle) {
        if (visible && menuHandle === handle) {
            anchorX = x
            return
        }
        anchorX = x
        menuHandle = handle
        visible = true
    }

    function close() {
        visible = false
        pointerInMenu = false
    }
}
