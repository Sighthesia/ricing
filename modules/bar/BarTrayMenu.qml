import QtQuick
import Quickshell
import "../lazerbar"
import "../../services" as Services

// Render one tray item's DBusMenu with the lazer popup language: sharp
// surface, brightness-diff hover, and geometric state indicators.
Rectangle {
    id: root

    // The SystemTray item whose menu should be rendered.
    property var payload: null

    readonly property var menuHandle: payload && payload.hasMenu ? payload.menu : null
    readonly property var entries: opener.children ? [...opener.children.values] : []
    readonly property int menuWidth: 236
    readonly property real maxHeight: Screen.desktopAvailableHeight > 0
            ? Math.max(180, Screen.desktopAvailableHeight * 0.7) : 420

    implicitWidth: menuWidth
    implicitHeight: Math.min(maxHeight, contentFlickable.contentHeight)
    // Explicit dims keep the hosting Loader from stretching the surface.
    width: implicitWidth
    height: implicitHeight
    radius: 10
    color: LazerTheme.popupBackground
    border.width: 1
    border.color: LazerTheme.popupBorder

    // One open submenu level at a time, anchored beside its parent row.
    property var submenuEntry: null
    property Item submenuAnchorRow: null

    function closeSubmenu() {
        submenuEntry = null
        submenuAnchorRow = null
    }

    QsMenuOpener {
        id: opener

        menu: root.menuHandle
    }

    // Scrollable entry column; menus stay short so stop-at-bounds scrolling
    // is enough here.
    Flickable {
        id: contentFlickable

        anchors.fill: parent
        contentHeight: contentColumn.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            topPadding: 8
            bottomPadding: 8
            spacing: 2

            Repeater {
                model: root.entries

                delegate: MenuEntryRow {
                    entry: modelData
                    onOpenSubmenu: (entry, row) => {
                        root.submenuEntry = entry
                        root.submenuAnchorRow = row
                    }
                    onCloseSubmenu: root.closeSubmenu()
                    onTriggered: {
                        root.closeSubmenu()
                        Services.BarPopupService.close()
                    }
                }
            }
        }
    }

    // Second-level submenu surface sharing the same visual language.
    Rectangle {
        id: submenuSurface

        visible: root.submenuEntry !== null
        radius: 10
        color: LazerTheme.popupBackground
        border.width: 1
        border.color: LazerTheme.popupBorder

        width: root.menuWidth
        height: submenuColumn.implicitHeight + 16
        // Open toward the screen center; fall back to the left edge-side
        // when the right side would overflow the window.
        x: {
            if (!visible)
                return 0
            var rootRightInWindow = root.mapToItem(null, root.x + root.width, 0).x
            return rootRightInWindow + width + 24 > root.Window.width
                   ? -width - 4 : root.width + 4
        }
        y: {
            if (!root.submenuAnchorRow)
                return 0
            var rowY = root.submenuAnchorRow.mapToItem(submenuSurface, 0, 0).y
            return Math.max(4, Math.min(rowY - 4, root.height - height - 8))
        }

        Column {
            id: submenuColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            topPadding: 8
            bottomPadding: 8
            spacing: 2

            Repeater {
                model: root.submenuEntry && root.submenuEntry.children
                       ? [...root.submenuEntry.children.values] : []

                delegate: MenuEntryRow {
                    entry: modelData
                    onTriggered: {
                        root.closeSubmenu()
                        Services.BarPopupService.close()
                    }
                }
            }
        }

        // Leaving the submenu surface folds it back into the root menu.
        HoverHandler {
            onHoveredChanged: if (!hovered) root.closeSubmenu()
        }
    }

    // One DBus menu entry: separator hairline or an actionable lazer row.
    component MenuEntryRow: Item {
        id: entryRow

        required property var entry
        signal openSubmenu(var entry, Item row)
        signal closeSubmenu()
        signal triggered()

        readonly property bool isSeparator: entry ? (entry.isSeparator ?? false) : false
        readonly property bool entryEnabled: entry ? (entry.enabled ?? true) : false
        readonly property bool hasChildren: entry ? (entry.hasChildren ?? false) : false
        readonly property int buttonType: entry ? (entry.buttonType ?? QsMenuButtonType.None) : QsMenuButtonType.None
        readonly property bool checked: entry ? entry.checkState === Qt.Checked : false
        readonly property bool showsIndicator: buttonType !== QsMenuButtonType.None
        readonly property string iconSource: entry ? String(entry.icon ?? "") : ""
        readonly property real rowPadding: 12

        width: parent ? parent.width : menuWidth
        implicitHeight: isSeparator ? 9 : 32

        // Hover fill swap only; the sharp row shape never changes. The open
        // submenu's anchor row keeps its highlight as the selection marker.
        Rectangle {
            anchors.fill: parent
            radius: 5
            color: (entryHover.hovered || root.submenuAnchorRow === entryRow)
                           && !entryRow.isSeparator
                   ? LazerTheme.settingsMenuHover : "transparent"

            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        // Separator: single hairline across the row's vertical middle.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: LazerTheme.divider
            visible: entryRow.isSeparator
        }

        // Check indicator: square for checkbox, circle for radio.
        Rectangle {
            id: checkIndicator

            anchors.left: parent.left
            anchors.leftMargin: entryRow.rowPadding
            anchors.verticalCenter: parent.verticalCenter
            width: entryRow.showsIndicator ? 14 : 0
            height: 14
            visible: entryRow.showsIndicator
            radius: entryRow.buttonType === QsMenuButtonType.RadioButton ? width / 2 : 3
            color: "transparent"
            border.color: entryRow.checked ? LazerTheme.osuGreen : LazerTheme.textMuted
            border.width: 1

            Rectangle {
                anchors.centerIn: parent
                width: entryRow.buttonType === QsMenuButtonType.RadioButton
                       ? parent.width / 2 : parent.width - 6
                height: entryRow.buttonType === QsMenuButtonType.RadioButton
                        ? parent.height / 2 : parent.height - 6
                radius: entryRow.buttonType === QsMenuButtonType.RadioButton ? width / 2 : 2
                color: LazerTheme.osuGreen
                visible: entryRow.checked
            }
        }

        Image {
            id: entryIcon

            anchors.left: checkIndicator.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: entryRow.iconSource !== "" ? 16 : 0
            height: 16
            source: entryRow.iconSource
            sourceSize: Qt.size(16, 16)
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            opacity: entryRow.entryEnabled ? 1 : MotionTokens.disabledOpacity
        }

        Text {
            anchors.left: entryIcon.right
            anchors.leftMargin: entryIcon.width > 0 ? 10 : 0
            anchors.right: chevronText.visible ? chevronText.left : parent.right
            anchors.rightMargin: chevronText.visible ? 10 : entryRow.rowPadding
            anchors.verticalCenter: parent.verticalCenter
            text: entryRow.entry ? String(entryRow.entry.text || "").replace(/[\n\r]+/g, " ") : ""
            color: LazerTheme.textPrimary
            opacity: entryRow.entryEnabled ? 1 : MotionTokens.disabledOpacity
            font.pixelSize: 13
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        Text {
            id: chevronText

            anchors.right: parent.right
            anchors.rightMargin: entryRow.rowPadding
            anchors.verticalCenter: parent.verticalCenter
            text: "\u203A"
            color: LazerTheme.textMuted
            font.pixelSize: 13
            visible: entryRow.hasChildren
        }

        TapHandler {
            enabled: !entryRow.isSeparator
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: {
                if (!entryRow.entryEnabled)
                    return
                if (entryRow.hasChildren) {
                    entryRow.openSubmenu(entryRow.entry, entryRow)
                    return
                }
                if (typeof entryRow.entry.triggered === "function")
                    entryRow.entry.triggered()
                entryRow.triggered()
            }
        }

        HoverHandler {
            id: entryHover

            enabled: !entryRow.isSeparator
            onHoveredChanged: {
                if (!hovered || !root.submenuAnchorRow)
                    return
                // Moving between rows retargets or folds the open submenu.
                if (entryRow.hasChildren)
                    entryRow.openSubmenu(entryRow.entry, entryRow)
                else if (root.submenuAnchorRow === entryRow)
                    root.closeSubmenu()
            }
        }
    }
}
