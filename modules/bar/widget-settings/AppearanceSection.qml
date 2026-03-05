import QtQuick
import qs.config

// Appearance configuration section.
// Individual per-widget colour/radius overrides have been removed pending a
// unified global<->local config architecture. This component is kept as a
// placeholder for future implementation.
Item {
    id: root

    required property string instanceKey

    implicitHeight: placeholder.implicitHeight + 16
    implicitWidth: 200

    Text {
        id: placeholder
        anchors.centerIn: parent
        text: "外观配置（规划中）"
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeSmall
        color: Colors.textMuted
        opacity: 0.5
    }
}
