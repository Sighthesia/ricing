import Quickshell
import QtQuick
import qs.config
import qs.services
import ".." as BarComponents
import "." as TrayComponents

// Local QML-rendered tray menu that skips the DBusMenu root wrapper.
BarComponents.ContextMenuPopup {
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
    readonly property real _screenHeight: Screen.height || 0
    readonly property real _maxHeight:
        _screenHeight > 0 ? Math.max(180, root._screenHeight * 0.7) : 420
    readonly property int _menuWidth: ThemeCards.menuWidth
    property var _submenuMenu: null

    BarComponents.StaggerOrchestrator {
        id: _stagger
    }

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

    implicitWidth: root._menuWidth
    implicitHeight: Math.min(root._maxHeight, contentFlickable.contentHeight + contentMargin * 2)

    onVisibleChanged: {
        if (!visible) {
            root._closeSubmenu()
        } else {
            root.playEnterAnimation()
            Qt.callLater(function() {
                if (!root.visible)
                    return

                root._syncStaggerItems()
                _stagger.runEnter()
            })
        }

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
            root._setClosedState()
            root.destroy()
            return
        }

        root._setClosedState()
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
        root._setClosedState()
    }

    function _setClosedState() {
        root.setClosedState()
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

    function _syncStaggerItems() {
        _stagger.clear()

        for (let index = 0; index < entryRepeater.count; index++) {
            let item = entryRepeater.itemAt(index)
            if (!item)
                continue

            _stagger.registerItem(item, index, 1)
        }
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
                if (root.visible) {
                    root._syncStaggerItems()
                    _stagger.runEnter()
                    root.anchor.updateAnchor()
                }
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

    // Keyboard focus catcher.
    Item {
        anchors.fill: parent
        focus: root.visible
        Keys.onEscapePressed: {
            BarLayoutService.trayMenuOpen = false
            event.accepted = true
        }
    }

    surfaceTransformOrigin: root.isSubmenu ? Item.TopLeft : Item.Top

    // Scrollable tray menu entries.
    Flickable {
        id: contentFlickable

        anchors.fill: parent
        contentHeight: contentColumn.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        // Tray entry column.
        Column {
            id: contentColumn

            width: parent.width
                spacing: ThemeCards.panelGap / 4

            Repeater {
                id: entryRepeater
                model: root._entries
                delegate: BarComponents.StaggerItem {
                    required property var modelData

                    width: contentColumn.width
                    height: itemDelegate.implicitHeight

                    TrayComponents.TrayContextMenuItem {
                        id: itemDelegate

                        anchors.fill: parent
                        entry: modelData
                        menuRoot: root
                    }
                }
            }
        }
    }
}
