pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import "../../../services" as Services

// Multi-level DBus menu renderer for the system tray, ported from the reference
// shell's TrayMenu but restyled in afloat's glass language. A StackView pushes a
// fresh SubMenu page for every entry that has children and pops on Back.
StackView {
    id: root

    // Fixed menu width; rows elide their labels to fit.
    readonly property real menuWidth: 220
    // The top-level DBus menu handle (QsMenuHandle) for the hovered tray item.
    property var rootHandle: null

    implicitWidth: menuWidth
    implicitHeight: currentItem ? currentItem.implicitHeight : 0
    // Clip so that while the hosting dockzone is still expanding (the view is
    // taller than the visible body area), the lower rows are cut at the body
    // edge instead of spilling below the glass.
    clip: true

    initialItem: subMenuComp.createObject(null, { handle: root.rootHandle, isSubMenu: false })

    // Rebuild from scratch whenever the hovered item (its menu handle) changes.
    onRootHandleChanged: resetToRoot(true)

    // Collapse any open submenus back to the top level.
    function resetToRoot(rebuild) {
        while (depth > 1)
            pop(StackView.Immediate)
        if (rebuild && currentItem)
            currentItem.handle = root.rootHandle
    }

    // Push/pop carry no StackView transition; each page animates its own fade+scale.
    pushEnter: Transition { NumberAnimation { duration: 0 } }
    pushExit: Transition { NumberAnimation { duration: 0 } }
    popEnter: Transition { NumberAnimation { duration: 0 } }
    popExit: Transition { NumberAnimation { duration: 0 } }

    // One menu page: opens the handle, lists entries, optional Back header.
    Component {
        id: subMenuComp

        Column {
            id: page

            property var handle: null
            property bool isSubMenu: false
            property bool shown: false

            width: root.menuWidth
            leftPadding: 6
            rightPadding: 6
            topPadding: 6
            bottomPadding: 6
            spacing: 2

            // Animate page entry/exit so navigation feels like one moving surface.
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.92
            transformOrigin: Item.Top

            Component.onCompleted: shown = true
            StackView.onActivating: shown = true
            StackView.onDeactivating: shown = false
            StackView.onRemoved: destroy()

            Behavior on opacity { NumberAnimation { duration: Services.Motion.popup.opacityDuration; easing.type: Services.Motion.popup.opacityEasing } }
            Behavior on scale { NumberAnimation { duration: Services.Motion.popup.scaleDuration; easing.type: Services.Motion.popup.scaleEasing; easing.overshoot: Services.Motion.popup.scaleOvershoot } }

            // Pull live children for this handle.
            QsMenuOpener {
                id: opener

                menu: page.handle
            }

            // Back header for nested pages; pops one level.
            Item {
                width: root.menuWidth - 12
                height: 30
                visible: page.isSubMenu

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: backArea.containsMouse ? Qt.alpha(Services.Color.mOnSurface, 0.08) : "transparent"

                    Behavior on color { ColorAnimation { duration: Services.Motion.number.shortDuration; easing.type: Services.Motion.number.shortEasing } }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    spacing: 8

                    Text {
                        text: "\u2039"
                        color: Services.Color.mPrimary
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 16
                        horizontalAlignment: Text.AlignHCenter
                    }

                    Text {
                        text: "Back"
                        color: Services.Color.mPrimary
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: backArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pop()
                }
            }

            // Thin divider under the Back header.
            Rectangle {
                width: root.menuWidth - 16
                anchors.horizontalCenter: parent.horizontalCenter
                height: 1
                color: Qt.alpha(Services.Color.mOutline, 0.4)
                visible: page.isSubMenu
            }

            // One row per DBus menu entry.
            Repeater {
                model: opener.children

                Item {
                    id: entry

                    required property var modelData

                    width: root.menuWidth - 12
                    implicitHeight: modelData.isSeparator ? 7 : 32

                    // Separator: centered hairline, no interaction.
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 4
                        height: 1
                        color: Qt.alpha(Services.Color.mOutline, 0.4)
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
                                radius: 6
                                color: rowArea.containsMouse && entry.modelData.enabled ? Qt.alpha(Services.Color.mOnSurface, 0.08) : "transparent"

                                Behavior on color { ColorAnimation { duration: Services.Motion.number.shortDuration; easing.type: Services.Motion.number.shortEasing } }
                            }

                            // Leading check/radio marker when the entry is toggled on.
                            Text {
                                id: check

                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                horizontalAlignment: Text.AlignHCenter
                                text: "\u2713"
                                color: Services.Color.mPrimary
                                font.pixelSize: 12
                                visible: entry.modelData.checkState === Qt.Checked
                            }

                            // Entry icon when provided by the application.
                            Image {
                                id: rowIcon

                                anchors.left: check.visible ? check.right : parent.left
                                anchors.leftMargin: check.visible ? 4 : 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16
                                height: 16
                                visible: entry.modelData.icon !== ""
                                source: entry.modelData.icon
                                sourceSize: Qt.size(16, 16)
                                smooth: true
                            }

                            // Entry label, elided to fit before the chevron.
                            Text {
                                id: rowLabel

                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: rowIcon.visible ? rowIcon.right
                                    : check.visible ? check.right : parent.left
                                anchors.leftMargin: (rowIcon.visible || check.visible) ? 6 : 8
                                anchors.right: chevron.visible ? chevron.left : parent.right
                                anchors.rightMargin: 8
                                text: entry.modelData.text
                                color: entry.modelData.enabled ? Services.Color.mOnSurface : Services.Color.mOutline
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }

                            // Submenu affordance.
                            Text {
                                id: chevron

                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\u203a"
                                color: entry.modelData.enabled ? Services.Color.mOnSurfaceVariant : Services.Color.mOutline
                                font.pixelSize: 14
                                visible: entry.modelData.hasChildren
                            }

                            MouseArea {
                                id: rowArea

                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: entry.modelData.enabled
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var e = entry.modelData
                                    if (e.hasChildren) {
                                        root.push(subMenuComp.createObject(null, {
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
