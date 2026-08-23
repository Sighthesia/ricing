import QtQuick
import "../../lazerbar"
import "../../../services" as Services

// Focused window title read straight from the compositor state.
Item {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    readonly property string displayTitle:
        Services.NiriService.activeTitle.length > 0 ? Services.NiriService.activeTitle : "桌面"

    implicitWidth: Math.min(titleText.implicitWidth + 8, 240)
    implicitHeight: LazerTheme.barWidgetHeight

    Text {
        id: titleText

        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, parent.width)
        text: root.displayTitle
        color: LazerTheme.textPrimary
        elide: Text.ElideRight
        font.pixelSize: 13
    }
}
