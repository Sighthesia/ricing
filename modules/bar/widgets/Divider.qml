import QtQuick
import "../../lazerbar"

// Visual separator between bar groups, placeable like any other widget.
Item {
    id: root

    // Widget identity contract filled by the layout loader.
    property string widgetId: ""
    property string instanceKey: ""
    property string section: ""
    property string screenName: ""

    implicitWidth: divider.implicitWidth
    implicitHeight: LazerTheme.barWidgetHeight

    BarDivider {
        id: divider

        anchors.centerIn: parent
    }
}
