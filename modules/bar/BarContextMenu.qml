import Quickshell
import QtQuick
import qs.config
import qs.services

// Right-click context menu for the bar background.
// Anchor to the BarContent item; positions itself below the bar at click X.
PopupWindow {
    id: root

    // The BarContent Item — used to calculate the popup's on-screen position.
    required property Item anchorTarget

    visible: false
    color: "transparent"

    anchor.item: anchorTarget
    // Place anchor point at the bar's bottom edge, horizontally at click X.
    // The menu expands downward (Quickshell default gravity: Bottom|Right).
    anchor.rect.x: Math.max(0, Math.min(_clickX - implicitWidth / 2,
                                         anchorTarget.width - implicitWidth))
    anchor.rect.y: anchorTarget.height
    anchor.rect.width: 1
    anchor.rect.height: 1

    implicitWidth: 160
    implicitHeight: menuColumn.implicitHeight + 8

    property real _clickX: 0
    property bool _active: false

    // Sync visible state back to service when menu is closed programmatically.
    onVisibleChanged: if (!visible) BarLayoutService.contextMenuOpen = false

    on_ActiveChanged: {
        if (_active) {
            visible = true;
            enterAnim.restart();
            s_layoutItem.runEnter()
            s_settingsItem.runEnter()
        } else {
            s_layoutItem.runExit()
            s_settingsItem.runExit()
            exitAnim.restart();
        }
    }

    // Close the menu when backdrop or external code sets contextMenuOpen = false.
    Connections {
        target: BarLayoutService
        function onContextMenuOpenChanged() {
            if (!BarLayoutService.contextMenuOpen) root._active = false;
        }
    }

    // Open menu at BarContent-local x coordinate.
    // `_y` is accepted for API symmetry with MouseArea.onClicked but is ignored:
    // the menu always appears at the bar's bottom edge regardless of click y.
    function showAt(x, _y) {
        _clickX = x;
        anchor.updateAnchor();
        BarLayoutService.contextMenuOpen = true;
        _active = true;
    }

    Rectangle {
        id: menuContent
        anchors.fill: parent
        color: Colors.surface
        radius: Theme.cornerRadius
        border.color: Colors.border
        border.width: 1

        opacity: 0
        scale: 0.85
        transformOrigin: Item.Top

        Column {
            id: menuColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 4
            spacing: 2

            // --- Layout mode item ---
            StaggerItem {
                id: s_layoutItem
                delay: SettingsService.data.animation.staggerLevel1BaseDelay
                exitDelay: 0
                width: parent.width
                height: Theme.barHeight - Theme.barPadding

                // Hover highlight overlay
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: Theme.cornerRadius - 2
                    color: Colors.highlight
                    opacity: layoutArea.containsMouse ? 0.12 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.anim.highlightDuration }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.widgetPadding
                    spacing: 8

                    Text {
                        text: "\uf0c9"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeIcon
                        color: BarLayoutService.settingsMode ? Colors.highlight : Colors.text
                        opacity: BarLayoutService.settingsMode ? 1.0 : 0.7
                    }

                    Text {
                        text: BarLayoutService.settingsMode ? "退出布局模式" : "布局模式"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        color: Colors.text
                    }
                }

                MouseArea {
                    id: layoutArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        BarLayoutService.activePanel =
                            BarLayoutService.settingsMode ? "none" : "layout";
                        root._active = false;
                    }
                }
            }

            // --- Settings item ---
            StaggerItem {
                id: s_settingsItem
                delay: SettingsService.data.animation.staggerLevel1BaseDelay
                     + SettingsService.data.animation.staggerLevel1Step
                exitDelay: 0
                width: parent.width
                height: Theme.barHeight - Theme.barPadding

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: Theme.cornerRadius - 2
                    color: Colors.highlight
                    opacity: settingsArea.containsMouse ? 0.12 : 0
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.anim.highlightDuration }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.widgetPadding
                    spacing: 8

                    Text {
                        text: "\uf013"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeIcon
                        color: Colors.text
                        opacity: 0.7
                    }

                    Text {
                        text: "设置"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        color: Colors.text
                    }
                }

                MouseArea {
                    id: settingsArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        BarLayoutService.activePanel = "config";
                        root._active = false;
                    }
                }
            }
        }
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation {
            target: menuContent; property: "opacity"
            from: 0; to: 1
            duration: 100; easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: menuContent; property: "scale"
            from: 0.85; to: 1.0
            duration: 130; easing.type: Easing.OutBack; easing.overshoot: 0.4
        }
    }

    SequentialAnimation {
        id: exitAnim
        ParallelAnimation {
            NumberAnimation {
                target: menuContent; property: "opacity"
                from: 1; to: 0
                duration: 80; easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: menuContent; property: "scale"
                from: 1.0; to: 0.88
                duration: 80; easing.type: Easing.InQuad
            }
        }
        ScriptAction { script: root.visible = false; }
    }
}
