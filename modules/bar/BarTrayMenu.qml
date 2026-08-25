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
    // Exposed so the popup window's input mask can cover the floating
    // submenu; without it pointer events over the panel never arrive.
    readonly property alias submenuSurfaceItem: submenuSurface
    // Sweeping between tray items swaps the DBusMenu handle and the new
    // children arrive asynchronously; hold the last settled height so the
    // frame never collapses mid-swap.
    property int settledHeight: 0
    readonly property int naturalHeight: Math.min(maxHeight, contentFlickable.contentHeight)
    implicitHeight: entries.length > 0 || settledHeight === 0
                    ? naturalHeight : Math.max(settledHeight, naturalHeight)
    onEntriesChanged: {
        if (entries.length > 0)
            settledHeight = naturalHeight
        closeSubmenu()
    }
    onPayloadChanged: closeSubmenu()
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

    // Submenu entries resolve through their own opener: reading a handle's
    // `children` never triggers the lazy DBusMenu fetch in this build, so
    // the panel would stay empty forever without it.
    QsMenuOpener {
        id: submenuOpener

        menu: root.submenuEntry
    }

    QsMenuOpener {
        id: opener

        menu: root.menuHandle
    }

    // Submenu reveal mirrors DropdownMenu's guarded lifecycle: one progress
    // drives opacity/scale/slide, retargets between submenus never replay,
    // and reduced motion snaps straight to the settled frame.
    property string submenuPhase: "closed"
    property real submenuProgress: 0

    onSubmenuEntryChanged: {
        if (root.submenuEntry !== null) {
            if (root.submenuPhase === "opening" || root.submenuPhase === "open")
                return
            root.submenuPhase = "opening"
            submenuAnimation.duration = MotionTokens.reducedMotion ? 0 : MotionTokens.medium
            submenuAnimation.to = 1
            submenuAnimation.restart()
        } else if (root.submenuPhase !== "closed") {
            root.submenuPhase = "closing"
            submenuAnimation.duration = MotionTokens.reducedMotion ? 0 : MotionTokens.fast
            submenuAnimation.to = 0
            submenuAnimation.restart()
        }
    }

    NumberAnimation {
        id: submenuAnimation

        target: root
        property: "submenuProgress"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: MotionTokens.outSoft
        onFinished: root.submenuPhase = root.submenuProgress === 1 ? "open" : "closed"
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

    // Second-level submenu surface sharing the same visual language. The
    // reveal replays DropdownMenu's fade + scale + drop-in; the layout
    // rectangle stays unanimated so only paint properties move per frame.
    Rectangle {
        id: submenuSurface

        visible: root.submenuProgress > 0
        enabled: root.submenuPhase === "opening" || root.submenuPhase === "open"
        opacity: root.submenuProgress
        transformOrigin: Item.TopLeft
        scale: MotionTokens.reducedMotion ? 1
               : MotionTokens.popupFromScale
                 + (1 - MotionTokens.popupFromScale) * root.submenuProgress
        radius: 10
        color: LazerTheme.popupBackground
        border.width: 1
        border.color: LazerTheme.popupBorder

        width: root.menuWidth
        // The column's own top/bottom padding already spaces the content;
        // adding more left a dead band at the bottom.
        height: submenuColumn.implicitHeight
        // Open toward the screen center; fall back to the left edge-side
        // when the right side would overflow the window.
        readonly property real dockedX: {
            if (root.submenuProgress <= 0)
                return 0
            var rootRightInWindow = root.mapToItem(null, root.x + root.width, 0).x
            return rootRightInWindow + width + 24 > root.Window.width
                   ? -width - 4 : root.width + 4
        }
        readonly property real dockedY: {
            if (!root.submenuAnchorRow)
                return 0
            // Map in root coordinates: mapping into the surface itself
            // would fold its own y into the result and oscillate.
            var rowY = root.submenuAnchorRow.mapToItem(root, 0, 0).y
            return Math.max(4, Math.min(rowY - 4, root.height - height - 8))
        }
        x: dockedX
        y: dockedY + (MotionTokens.reducedMotion ? 0
                       : MotionTokens.popupFromY * (1 - root.submenuProgress))

        Column {
            id: submenuColumn

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            topPadding: 8
            bottomPadding: 8
            spacing: 2

            Repeater {
                model: [...submenuOpener.children.values]

                delegate: MenuEntryRow {
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
    // Required modelData keeps the Repeater's strict delegate mode happy;
    // entry aliases it so rows read naturally.
    component MenuEntryRow: Item {
        id: entryRow

        required property var modelData
        readonly property var entry: modelData
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

        // Check indicator: square for checkbox, circle for radio. The slot
        // is reserved on every row (visible or not) so text shares one left
        // edge across checkable and plain items.
        Rectangle {
            id: checkIndicator

            anchors.left: parent.left
            anchors.leftMargin: entryRow.rowPadding
            anchors.verticalCenter: parent.verticalCenter
            width: 14
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

        // Icon slot: always reserved at full width so every row's text
        // starts on the same left edge, whether or not an icon is present.
        Image {
            id: entryIcon

            anchors.left: checkIndicator.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            source: entryRow.iconSource
            sourceSize: Qt.size(16, 16)
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            visible: entryRow.iconSource !== ""
            opacity: entryRow.entryEnabled ? 1 : MotionTokens.disabledOpacity
        }

        Text {
            anchors.left: entryIcon.right
            anchors.leftMargin: 10
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

        // Auto-expand on hover: hovering a child row opens its panel at
        // once; hovering any plain row folds the open one, matching native
        // menu traversal. No click required anywhere in the flow.
        HoverHandler {
            id: entryHover

            enabled: !entryRow.isSeparator
            onHoveredChanged: {
                if (!hovered || !entryRow.entryEnabled)
                    return
                if (entryRow.hasChildren) {
                    entryRow.openSubmenu(entryRow.entry, entryRow)
                    return
                }
                if (root.submenuAnchorRow)
                    root.closeSubmenu()
            }
        }
    }
}
