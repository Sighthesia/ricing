import QtQuick

// Own the settings dropdown menu surface: a scrollable osu-style item list
// with selected/preselected/hover feedback and full keyboard navigation.
// Lives inside the content overlay layer so it is never clipped by the page
// Flickable viewport.
Item {
    id: root

    property var model: []
    property string currentValue: ""
    property int preselectIndex: -1
    property Item choiceItem: null
    readonly property int itemCount: model ? model.length : 0
    readonly property bool menuVisible: visible
    readonly property string preselectLabel: preselectIndex >= 0 && preselectIndex < itemCount
                                             ? String(model[preselectIndex].label) : ""
    signal itemSelected(string value)
    signal closed()

    visible: false
    focus: false

    function indexOfValue(candidate) {
        for (var i = 0; i < root.model.length; i++)
            if (String(root.model[i].value) === String(candidate))
                return i
        return -1
    }

    function open() {
        visible = true
        focus = true
        root.preselectIndex = Math.max(0, indexOfValue(root.currentValue))
        listView.positionViewAtIndex(Math.max(0, root.preselectIndex), ListView.Center)
    }

    function close() {
        if (!visible)
            return
        visible = false
        focus = false
        root.preselectIndex = -1
        root.closed()
    }

    function selectPreselected() {
        if (root.preselectIndex >= 0 && root.preselectIndex < itemCount)
            root.itemSelected(String(root.model[root.preselectIndex].value))
    }

    function movePreselect(delta) {
        if (itemCount === 0)
            return
        var next = Math.max(0, Math.min(itemCount - 1, (root.preselectIndex < 0 ? 0 : root.preselectIndex) + delta))
        root.preselectIndex = next
        listView.positionViewAtIndex(next, ListView.Contain)
    }

    Keys.onPressed: event => {
        if (!root.visible)
            return
        if (event.key === Qt.Key_Up) {
            movePreselect(-1)
            event.accepted = true
        } else if (event.key === Qt.Key_Down) {
            movePreselect(1)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            selectPreselected()
            event.accepted = true
        } else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Tab) {
            root.close()
            event.accepted = true
        }
    }

    // Paint the rounded menu surface behind the item list.
    Rectangle {
        id: menuSurface
        anchors.fill: parent
        radius: LazerTheme.settingsControlRadius
        color: LazerTheme.settingsMenuBackground
        border.width: 1
        border.color: LazerTheme.settingsMenuBorder
        clip: true

        ListView {
            id: listView
            anchors.fill: parent
            anchors.margins: 4
            clip: true
            model: root.model
            interactive: root.model.length > 6
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                id: itemSurface
                width: listView.width
                height: 30
                radius: 4
                color: itemHover.hovered || index === root.preselected ? LazerTheme.settingsMenuHover : "transparent"
                Behavior on color { ColorAnimation { duration: MotionTokens.dropdownItem } }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: LazerTheme.settingsControlPadding
                    anchors.right: parent.right
                    anchors.rightMargin: LazerTheme.settingsControlPadding
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.label
                    color: String(modelData.value) === root.currentValue ? LazerTheme.osuPink : LazerTheme.textPrimary
                    font.pixelSize: 14
                    font.weight: String(modelData.value) === root.currentValue ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }

                HoverHandler {
                    id: itemHover
                    onHoveredChanged: {
                        if (itemHover.hovered)
                            root.preselectIndex = index
                    }
                }
                TapHandler {
                    onTapped: root.itemSelected(String(modelData.value))
                }
            }
        }
    }
}