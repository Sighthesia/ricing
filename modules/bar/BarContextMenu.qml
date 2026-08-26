import QtQuick
import "../lazerbar"
import "../../services" as Services

// Static shell menu rendered in the tray-menu language: sharp popup face,
// brightness-diff hover rows, and a check square as the mode indicator.
Rectangle {
    id: root

    signal openSettingsRequested()
    signal layoutModeToggled()

    readonly property bool layoutModeActive: Services.BarLayoutService.settingsMode
    readonly property int menuWidth: 236

    implicitWidth: menuWidth
    implicitHeight: menuColumn.implicitHeight
    radius: 10
    color: LazerTheme.popupBackground
    border.width: 1
    border.color: LazerTheme.popupBorder

    Column {
        id: menuColumn

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        topPadding: 8
        bottomPadding: 8
        spacing: 2

        MenuRow {
            label: "Open Settings"
            onActivated: root.openSettingsRequested()
        }

        // Separator hairline between actions and the mode toggle.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: LazerTheme.divider
        }

        MenuRow {
            label: root.layoutModeActive ? "Exit Layout Mode" : "Enter Layout Mode"
            checked: root.layoutModeActive
            onActivated: root.layoutModeToggled()
        }
    }

    // One actionable lazer row: hover fill swap, reserved check slot so all
    // labels share one left edge, and a click flash through TapHandler.
    component MenuRow: Item {
        id: entryRow

        required property string label
        property bool checked: false
        signal activated()

        width: parent ? parent.width : root.menuWidth
        implicitHeight: 32

        // Hover fill swap only; the sharp row shape never changes.
        Rectangle {
            anchors.fill: parent
            radius: 5
            color: entryHover.hovered ? LazerTheme.settingsMenuHover : "transparent"

            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        // Check slot stays reserved on every row so text shares one edge.
        Rectangle {
            id: checkIndicator

            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            radius: 3
            color: "transparent"
            border.color: entryRow.checked ? LazerTheme.osuGreen : LazerTheme.textMuted
            border.width: 1

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 6
                height: parent.height - 6
                radius: 2
                color: LazerTheme.osuGreen
                visible: entryRow.checked
            }
        }

        Text {
            anchors.left: checkIndicator.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: entryRow.label
            color: LazerTheme.textPrimary
            font.pixelSize: 13
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: entryRow.activated()
        }

        HoverHandler {
            id: entryHover
        }
    }
}
