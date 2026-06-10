pragma ComponentBehavior: Bound

import "../MenuVisuals.js" as MenuVisuals
import QtQuick
import QtQuick.Controls
import Quickshell
import "../../../services" as Services

// Multi-level DBus menu renderer for the system tray, ported from the reference
// shell's TrayMenu but restyled in afloat's glass language. The root owns two
// height domains: the menu's full natural content height and the currently
// visible viewport height while the dockzone is still expanding.
Item {
    id: root

    // Fixed menu width; rows elide their labels to fit.
    readonly property real menuWidth: MenuVisuals.trayMenuWidth
    // The top-level DBus menu handle (QsMenuHandle) for the hovered tray item.
    property var rootHandle: null
    // The currently visible height provided by the host while the dockzone
    // expands. Default to the full content height for measurement-only uses.
    property real viewportHeight: contentHeight
    // The currently visible width provided by the host while the dockzone
    // expands. The menu keeps its natural width for measurement and eliding,
    // but the rendered viewport is clipped to this live width.
    property real viewportWidth: menuWidth
    readonly property real contentHeight: menuStack.implicitHeight
    readonly property real widthProgress: menuWidth > 0 ? Math.max(0, Math.min(1, width / menuWidth)) : 1
    // Only reveal complete rows. Partial rows are where text/icons become
    // visible before the dockzone glass has expanded enough to contain them.
    readonly property real revealHeight: Math.max(0, height - 1)

    implicitWidth: menuWidth
    implicitHeight: contentHeight
    width: Math.min(viewportWidth, menuWidth)
    height: Math.min(viewportHeight, contentHeight)

    // Rebuild from scratch whenever the hovered item (its menu handle) changes.
    onRootHandleChanged: resetToRoot(true)

    // Collapse any open submenus back to the top level.
    function resetToRoot(rebuild) {
        while (menuStack.depth > 1)
            menuStack.pop(StackView.Immediate)
        if (rebuild && menuStack.currentItem)
            menuStack.currentItem.handle = root.rootHandle
    }

    // Clip the full-size menu content to the host-provided viewport so rows
    // never paint outside the still-expanding glass body.
    Item {
        id: viewport

        width: root.width
        height: root.height
        clip: true

        // Host the logical page stack at full natural height; only the viewport
        // above is height-clamped during the expand animation.
        StackView {
            id: menuStack

            width: root.menuWidth
            implicitHeight: currentItem ? currentItem.implicitHeight : 0
            x: 0
            anchors.top: parent.top
            clip: true
            opacity: Math.min(1, root.widthProgress * 1.25)

            initialItem: subMenuComp.createObject(null, { handle: root.rootHandle, isSubMenu: false })

            // Push/pop carry no StackView transition; each page animates its own fade.
            pushEnter: Transition { NumberAnimation { duration: 0 } }
            pushExit: Transition { NumberAnimation { duration: 0 } }
            popEnter: Transition { NumberAnimation { duration: 0 } }
            popExit: Transition { NumberAnimation { duration: 0 } }
        }
    }

    // One menu page: opens the handle, lists entries, optional Back header.
    Component {
        id: subMenuComp

        Column {
            id: page

            property var handle: null
            property bool isSubMenu: false
            property bool shown: false

            width: root.menuWidth
            leftPadding: MenuVisuals.rowRadius
            rightPadding: MenuVisuals.rowRadius
            topPadding: MenuVisuals.rowRadius
            bottomPadding: MenuVisuals.rowRadius
            spacing: MenuVisuals.compactSpacing

            // Animate page entry/exit with opacity only so foreground text/icons
            // never overshoot the host clip during the dockzone expand.
            opacity: shown ? 1 : 0

            Component.onCompleted: shown = true
            StackView.onActivating: shown = true
            StackView.onDeactivating: shown = false
            StackView.onRemoved: destroy()

            Behavior on opacity { NumberAnimation { duration: Services.Motion.popup.opacityDuration; easing.type: Services.Motion.popup.opacityEasing } }

            // Pull live children for this handle.
            QsMenuOpener {
                id: opener

                menu: page.handle
            }

            // Back header for nested pages; pops one level.
            Item {
                id: backHeader

                readonly property bool fullyRevealed: y + height <= root.revealHeight

                width: root.menuWidth - 12
                height: MenuVisuals.submenuHeaderHeight
                visible: page.isSubMenu
                opacity: fullyRevealed ? 1 : 0

                Rectangle {
                    anchors.fill: parent
                    radius: MenuVisuals.rowRadius
                    color: backArea.containsMouse ? Qt.alpha(Services.Color.mOnSurface, MenuVisuals.hoverOpacity) : "transparent"

                    Behavior on color { ColorAnimation { duration: Services.Motion.number.shortDuration; easing.type: Services.Motion.number.shortEasing } }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: MenuVisuals.contentInset
                    spacing: MenuVisuals.contentSpacing

                    Services.FluidText {
                        text: "\u2039"
                        color: Services.Color.mPrimary
                        basePixelSize: MenuVisuals.iconFontSize
                        anchors.verticalCenter: parent.verticalCenter
                        width: MenuVisuals.iconWidth
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Services.FluidText {
                        text: "Back"
                        color: Services.Color.mPrimary
                        basePixelSize: MenuVisuals.bodyFontSize
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: backArea

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: backHeader.fullyRevealed
                    cursorShape: Qt.PointingHandCursor
                    onClicked: menuStack.pop()
                }
            }

            // Thin divider under the Back header.
            Rectangle {
                readonly property bool fullyRevealed: y + height <= root.revealHeight

                width: root.menuWidth - MenuVisuals.separatorInset * 2
                anchors.horizontalCenter: parent.horizontalCenter
                height: 1
                color: Qt.alpha(Services.Color.mOutline, MenuVisuals.dividerOpacity)
                visible: page.isSubMenu
                opacity: fullyRevealed ? 1 : 0
            }

            // One row per DBus menu entry.
            Repeater {
                model: opener.children

                Item {
                    id: entry

                    required property var modelData
                    readonly property bool fullyRevealed: y + implicitHeight <= root.revealHeight

                    width: root.menuWidth - MenuVisuals.separatorInset
                    implicitHeight: modelData.isSeparator ? MenuVisuals.separatorRowHeight : MenuVisuals.rowHeight
                    opacity: fullyRevealed ? 1 : 0

                    // Separator: centered hairline, no interaction.
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - MenuVisuals.rowEdgeInset
                        height: 1
                        color: Qt.alpha(Services.Color.mOutline, MenuVisuals.dividerOpacity)
                        visible: entry.modelData.isSeparator
                    }

                    // Interactive row content for normal entries.
                    Loader {
                        anchors.fill: parent
                        active: !entry.modelData.isSeparator

                        sourceComponent: Item {
                            // Hover highlight background.
                            Rectangle {
                                anchors.fill: parent
                                radius: MenuVisuals.rowRadius
                                color: rowArea.containsMouse && entry.modelData.enabled ? Qt.alpha(Services.Color.mOnSurface, MenuVisuals.hoverOpacity) : "transparent"

                                Behavior on color { ColorAnimation { duration: Services.Motion.number.shortDuration; easing.type: Services.Motion.number.shortEasing } }
                            }

                            // Leading check/radio marker when the entry is toggled on.
                            Services.FluidText {
                                id: check

                                anchors.left: parent.left
                                anchors.leftMargin: MenuVisuals.contentInset
                                anchors.verticalCenter: parent.verticalCenter
                                width: MenuVisuals.checkIndicatorWidth
                                horizontalAlignment: Text.AlignHCenter
                                text: "\u2713"
                                color: Services.Color.mPrimary
                                basePixelSize: MenuVisuals.bodyFontSize
                                visible: entry.modelData.checkState === Qt.Checked
                            }

                            // Entry icon when provided by the application.
                            Image {
                                id: rowIcon

                                anchors.left: check.visible ? check.right : parent.left
                                anchors.leftMargin: check.visible ? MenuVisuals.rowEdgeInset : MenuVisuals.contentInset
                                anchors.verticalCenter: parent.verticalCenter
                                width: MenuVisuals.iconWidth
                                height: MenuVisuals.iconImageSize
                                visible: entry.modelData.icon !== ""
                                source: entry.modelData.icon
                                sourceSize: Qt.size(MenuVisuals.iconImageSize, MenuVisuals.iconImageSize)
                                smooth: true
                            }

                            // Entry label, elided to fit before the chevron.
                            Services.FluidText {
                                id: rowLabel

                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: rowIcon.visible ? rowIcon.right
                                    : check.visible ? check.right : parent.left
                                anchors.leftMargin: (rowIcon.visible || check.visible) ? MenuVisuals.rowRadius : MenuVisuals.contentInset
                                anchors.right: chevron.visible ? chevron.left : parent.right
                                anchors.rightMargin: MenuVisuals.contentInset
                                text: entry.modelData.text
                                color: entry.modelData.enabled ? Services.Color.mOnSurface : Services.Color.mOutline
                                basePixelSize: MenuVisuals.bodyFontSize
                                elide: Text.ElideRight
                            }

                            // Submenu affordance.
                            Services.FluidText {
                                id: chevron

                                anchors.right: parent.right
                                anchors.rightMargin: MenuVisuals.contentInset
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\u203a"
                                color: entry.modelData.enabled ? Services.Color.mOnSurfaceVariant : Services.Color.mOutline
                                basePixelSize: MenuVisuals.chevronFontSize
                                visible: entry.modelData.hasChildren
                            }

                            MouseArea {
                                id: rowArea

                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: entry.modelData.enabled && entry.fullyRevealed
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var e = entry.modelData
                                    if (e.hasChildren) {
                                        menuStack.push(subMenuComp.createObject(null, {
                                            handle: e,
                                            isSubMenu: true
                                        }))
                                    } else {
                                        e.triggered()
                                        Services.TrayMenuService.close()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
