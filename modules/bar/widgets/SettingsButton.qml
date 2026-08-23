import QtQuick
import ".."
import "../../lazerbar"
import "../../../services" as Services

// Gear button routed to the shell settings center.
BarPill {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    // Route through the shared bridge so the overlay owner window opens the
    // panel on whichever screen owns this bar instance.
    onClicked: SettingsOverlayBridge.requestOpen()


    implicitWidth: LazerTheme.barWidgetHeight


    Image {
        anchors.centerIn: parent
        width: LazerTheme.barGlyphSize
        height: LazerTheme.barGlyphSize
        source: "../../lazerbar/icons/settings.svg"
        opacity: root.hovered ? 1 : 0.85

        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
    }
}
