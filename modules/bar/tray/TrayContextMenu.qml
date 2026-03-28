import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

// Local QML-rendered tray menu that skips the DBusMenu root wrapper.
PopupWindow {
    id: root

    required property Item anchorTarget

    property var trayItem: null
    property var menu: null
    property var rootMenu: null
    property bool isSubmenu: false
    property Item submenuAnchor: anchorTarget
    property real clickX: 0
    property bool openLeft: false

    readonly property var _entries: opener.children ? [...opener.children.values] : []
    readonly property real _screenWidth: Screen.width || 0
    readonly property real _maxHeight: _screenWidth > 0 ? Math.max(180, Screen.height * 0.7) : 420

    property var _submenuMenu: null

    visible: false
    color: "transparent"

    Component.onCompleted: {
        if (!root.rootMenu)
            root.rootMenu = root
    }

    anchor.item: root.isSubmenu ? root.submenuAnchor : root.anchorTarget
    anchor.rect.x: {
        if (root.isSubmenu) {
            return root.openLeft ? -implicitWidth - 6 : ((root.submenuAnchor ? root.submenuAnchor.width : 0) + 6)
        }

        return Math.max(0, Math.min(root.clickX - implicitWidth / 2, root.anchorTarget.width - implicitWidth))
    }
    anchor.rect.y: root.isSubmenu ? 0 : root.anchorTarget.height
    anchor.rect.width: 1
    anchor.rect.height: 1

    implicitWidth: 220
    implicitHeight: Math.min(root._maxHeight, contentColumn.implicitHeight + Theme.widgetPadding * 2)

    onVisibleChanged: {
        if (!visible)
            root._closeSubmenu()

        if (!visible && !root.isSubmenu)
            BarLayoutService.trayMenuOpen = false
    }

    function showForItem(item, x, _y) {
        if (!item || !item.hasMenu || !item.menu)
            return

        root._closeSubmenu()
        root.trayItem = item
        root.menu = item.menu
        root.clickX = Number(x) || 0

        BarLayoutService.contextMenuOpen = false
        BarLayoutService.trayMenuOpen = true

        root.visible = true
        root.anchor.updateAnchor()
        Qt.callLater(function() {
            if (root.visible)
                root.anchor.updateAnchor()
        })
    }

    function closeRootMenu() {
        if (root.isSubmenu) {
            root.visible = false
            root.destroy()
            return
        }

        root.visible = false
    }

    function closeEntireTree() {
        if (root.rootMenu && root.rootMenu !== root) {
            root.rootMenu.closeMenuTree()
            return
        }

        root.closeMenuTree()
    }

    function closeMenuTree() {
        root._closeSubmenu()
        root.visible = false
    }

    function toggleSubmenu(menuEntry, itemDelegate) {
        if (!menuEntry || !menuEntry.hasChildren || !itemDelegate)
            return

        if (root._submenuMenu && root._submenuMenu.menu === menuEntry) {
            root._closeSubmenu()
            return
        }

        root._closeSubmenu()

        let component = Qt.createComponent(Qt.resolvedUrl("TrayContextMenu.qml"))
        if (component.status !== Component.Ready)
            return

        root._submenuMenu = component.createObject(root, {
            "anchorTarget": root.anchorTarget,
            "menu": menuEntry,
            "rootMenu": root.rootMenu ? root.rootMenu : root,
            "isSubmenu": true,
            "submenuAnchor": itemDelegate,
            "openLeft": root._shouldOpenLeft()
        })

        if (!root._submenuMenu)
            return

        root._submenuMenu.visible = true
        root._submenuMenu.anchor.updateAnchor()
    }

    function _closeSubmenu() {
        if (!root._submenuMenu)
            return

        root._submenuMenu.closeMenuTree()
        root._submenuMenu.destroy()
        root._submenuMenu = null
    }

    function _shouldOpenLeft() {
        if (root._screenWidth <= 0)
            return false

        return root.x + root.implicitWidth * 2 + 24 > root._screenWidth
    }

    QsMenuOpener {
        id: opener

        menu: root.menu
    }

    Connections {
        target: opener

        function onChildrenChanged() {
            if (!root.visible)
                return

            Qt.callLater(function() {
                if (root.visible)
                    root.anchor.updateAnchor()
            })
        }
    }

    Connections {
        target: BarLayoutService

        function onTrayMenuOpenChanged() {
            if (!BarLayoutService.trayMenuOpen && root.visible)
                root.closeMenuTree()
        }

        function onContextMenuOpenChanged() {
            if (BarLayoutService.contextMenuOpen && root.visible)
                root.closeMenuTree()
        }
    }

    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: {
            BarLayoutService.trayMenuOpen = false
            event.accepted = true
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Colors.surface
        border.color: Colors.border
        border.width: 1
    }

    Component {
        id: menuEntryDelegate

        Item {
            id: menuEntryRoot

            required property var modelData

            readonly property var entry: modelData
            readonly property bool isSeparator: entry?.isSeparator ?? false
            readonly property bool enabledEntry: entry?.enabled ?? true
            readonly property bool hasChildrenEntry: entry?.hasChildren ?? false
            readonly property int buttonTypeEntry: entry?.buttonType ?? QsMenuButtonType.None
            readonly property bool checkedEntry: entry?.checkState === Qt.Checked

            width: parent ? parent.width : 220
            implicitHeight: isSeparator
                ? 9
                : Math.max(Theme.barHeight - Theme.barPadding, label.implicitHeight + Theme.widgetPadding * 2)

            Rectangle {
                anchors.centerIn: parent
                width: parent.width - Theme.widgetPadding
                height: 1
                radius: 1
                color: Colors.border
                opacity: menuEntryRoot.isSeparator ? 0.65 : 0
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.cornerRadius - 2
                color: hoverArea.containsMouse && !menuEntryRoot.isSeparator ? Colors.highlight : "transparent"
                opacity: hoverArea.containsMouse && !menuEntryRoot.isSeparator ? 0.12 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.anim.highlightDuration
                        easing.type: Theme.anim.highlightType
                    }
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.widgetPadding
                anchors.rightMargin: Theme.widgetPadding
                spacing: Theme.barWidget.iconSpacing
                visible: !menuEntryRoot.isSeparator

                Item {
                    Layout.preferredWidth: Theme.fontSizeBody
                    Layout.preferredHeight: Theme.fontSizeBody
                    Layout.alignment: Qt.AlignVCenter
                    visible: menuEntryRoot.buttonTypeEntry !== QsMenuButtonType.None

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        radius: menuEntryRoot.buttonTypeEntry === QsMenuButtonType.RadioButton ? width / 2 : 3
                        color: "transparent"
                        border.color: menuEntryRoot.checkedEntry ? Colors.highlight : Colors.textMuted
                        border.width: 1

                        Rectangle {
                            anchors.centerIn: parent
                            width: menuEntryRoot.buttonTypeEntry === QsMenuButtonType.RadioButton ? parent.width / 2 : parent.width - 4
                            height: menuEntryRoot.buttonTypeEntry === QsMenuButtonType.RadioButton ? parent.height / 2 : parent.height - 4
                            radius: menuEntryRoot.buttonTypeEntry === QsMenuButtonType.RadioButton ? width / 2 : 2
                            color: Colors.highlight
                            visible: menuEntryRoot.checkedEntry
                        }
                    }
                }

                Image {
                    Layout.preferredWidth: Theme.barWidget.primaryIconSize
                    Layout.preferredHeight: Theme.barWidget.primaryIconSize
                    Layout.alignment: Qt.AlignVCenter
                    source: menuEntryRoot.entry?.icon ?? ""
                    sourceSize.width: width
                    sourceSize.height: height
                    smooth: true
                    fillMode: Image.PreserveAspectFit
                    visible: source !== ""
                    opacity: menuEntryRoot.enabledEntry ? 1 : 0.45
                }

                Text {
                    id: label

                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: (menuEntryRoot.entry?.text ?? "").replace(/[\n\r]+/g, " ")
                    color: menuEntryRoot.enabledEntry ? Colors.text : Colors.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    elide: Text.ElideRight
                    wrapMode: Text.NoWrap
                    maximumLineCount: 1
                    opacity: menuEntryRoot.enabledEntry ? 1 : 0.7
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: ">"
                    color: Colors.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    visible: menuEntryRoot.hasChildrenEntry
                }
            }

            MouseArea {
                id: hoverArea

                anchors.fill: parent
                enabled: !menuEntryRoot.isSeparator && menuEntryRoot.enabledEntry
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: function(_mouse) {
                    if (menuEntryRoot.hasChildrenEntry) {
                        root.toggleSubmenu(menuEntryRoot.entry, menuEntryRoot)
                        return
                    }

                    if (menuEntryRoot.entry && typeof menuEntryRoot.entry.triggered === "function")
                        menuEntryRoot.entry.triggered()

                    root.closeEntireTree()
                }
            }
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: Theme.widgetPadding / 2
        contentHeight: contentColumn.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentColumn

            width: parent.width
            spacing: 2

            Repeater {
                model: root._entries
                delegate: menuEntryDelegate
            }
        }
    }
}
