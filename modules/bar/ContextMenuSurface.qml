import QtQuick
import qs.config
import qs.modules.bar

// Shared surface for bar-styled context menus.
Item {
    id: root

    property real contentMargin: 0
    default property alias content: shell.content

    FloatingShellSurface {
        id: shell

        anchors.fill: parent
        contentMargin: root.contentMargin
    }
}
