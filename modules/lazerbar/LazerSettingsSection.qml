import QtQuick
import "LazerSettingsLogic.js" as Logic

// Present one settings category as an osu-style section block: a titled
// background container whose rows stay fully visible while active and dim
// under a translucent overlay while another section is being browsed.
Item {
    id: root

    property string title: ""
    property string searchQuery: ""
    property bool sectionActive: true
    property bool interactive: true
    readonly property bool sectionHovered: dimArea.hovered === true
    readonly property int visibleResultCount: _countVisibleRows()
    readonly property bool hasVisibleContent: visibleResultCount > 0

    // Rows are injected as the section content and laid out in one column.
    default property alias content: contentColumn.data

    signal activated()

    implicitWidth: 400
    width: parent ? parent.width : implicitWidth
    readonly property real contentImplicitHeight: contentColumn.implicitHeight
    implicitHeight: header.height + contentImplicitHeight + 12
    height: hasVisibleContent ? implicitHeight : 0
    visible: hasVisibleContent
    clip: true
    opacity: root.interactive ? 1 : LazerTheme.settingsDisabledAlpha

    Behavior on height { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint } }

    function _countVisibleRows() {
        var count = 0
        var children = contentColumn.children
        for (var i = 0; i < children.length; i++) {
            if (children[i].searchVisible === true)
                count++
        }
        return count
    }

    // Paint the square section background behind the title and rows, slightly
    // lighter than the row cards so the category block reads as one surface.
    Rectangle {
        id: background
        anchors.fill: parent
        color: LazerTheme.settingsSection
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }

    // Present the category title as the section header with a bottom rule.
    Item {
        id: header
        x: 0
        y: 0
        width: root.width
        height: 48

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: LazerTheme.textPrimary
            font.pixelSize: 16
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: LazerTheme.divider
        }
    }

    // Lay out the injected rows below the header with one shared gap.
    Column {
        id: contentColumn
        x: 0
        y: header.height
        width: root.width
        spacing: 8
    }

    // Dim the whole block while it is not the browsed section.
    Rectangle {
        id: dim
        z: 4
        anchors.fill: parent
        color: "#000000"
        visible: root.sectionActive ? opacity > 0.01 : true
        opacity: root.sectionActive ? 0 : (root.sectionHovered ? 0.5 : 0.8)
        Behavior on opacity { enabled: !MotionTokens.reducedMotion; NumberAnimation { duration: 300; easing.type: Easing.OutQuint } }
    }

    // Let the first click on a dimmed block scroll it into view (osu behavior).
    MouseArea {
        id: dimArea
        z: 5
        anchors.fill: parent
        enabled: !root.sectionActive
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: root.activated()
    }
}