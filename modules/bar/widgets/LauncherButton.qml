import QtQuick
import ".."
import "../../lazerbar"
import "../../../services" as Services

// Search pill routed to the standalone launcher session; toggling keeps the
// bar entry consistent with the keyboard IPC path (same single instance).
BarPill {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    onClicked: Services.LauncherService.toggle()

    implicitWidth: 32

    Image {
        anchors.centerIn: parent
        width: 16
        height: 16
        source: "../../lazerbar/icons/search.svg"
        opacity: root.hovered ? 1 : 0.85

        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
    }
}
