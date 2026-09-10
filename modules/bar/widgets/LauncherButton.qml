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

    // Scheme-aware search glyph (dark in light mode, white in dark mode);
    // resolved here because BarIcon resolves relative paths against its file.
    BarIcon {
        anchors.centerIn: parent
        width: 16
        height: 16
        source: Qt.resolvedUrl("../../lazerbar/icons/search.svg")
        opacity: root.hovered ? 1 : 0.85

        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
    }
}
