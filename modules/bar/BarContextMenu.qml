import Quickshell
import QtQuick
import qs.config
import qs.services

// Right-click context menu for the bar background.
// Anchor to the BarContent item; positions itself below the bar at click X.
ContextMenuPopup {
    id: root

    // The BarContent Item — used to calculate the popup's on-screen position.
    required property Item anchorTarget

    anchor.item: anchorTarget
    // Place anchor point at the bar's bottom edge, horizontally at click X.
    // The menu expands downward (Quickshell default gravity: Bottom|Right).
    anchor.rect.x: Math.max(0, Math.min(_clickX - implicitWidth / 2,
                                         anchorTarget.width - implicitWidth))
    anchor.rect.y: anchorTarget.height
    anchor.rect.width: 1
    anchor.rect.height: 1

    implicitWidth: 160
    implicitHeight: menuColumn.implicitHeight + contentMargin * 2

    property real _clickX: 0
    property bool _active: false

    // Set by BarWidgetWrapper right-click; "" means bar-background right-click.
    property string _targetWidgetKey: ""
    // Bar-coord X of the widget centre; forwarded to LayoutService on panel open.
    property real _targetWidgetCenterX: 0
    // Human-readable widget type label (currently unused in display, reserved for tooltip).
    property string _targetWidgetLabel: ""
    readonly property int _widgetActionCount: 1
    StaggerOrchestrator {
        id: _stagger
    }

    // Sync visible state back to service when menu is closed programmatically.
    onVisibleChanged: if (!visible) BarLayoutService.contextMenuOpen = false

    on_ActiveChanged: {
        _stagger.clear();
        _stagger.registerItem(s_layoutItem, 0, 1);
        _stagger.registerItem(s_settingsItem, 1, 1);
        if (_targetWidgetKey !== "") {
            _stagger.registerItem(s_widgetDivider, 2, 1);
            _stagger.registerItem(s_widgetSettings, 3, 1);
        }

        if (_active) {
            visible = true;
            playEnterAnimation();
            _stagger.runEnter();
        } else {
            _stagger.runExit();
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

    // Deferred dismiss — gives the click ripple time to bloom before the menu
    // fades away. Only used when the user explicitly clicks a menu item.
    Timer {
        id: _dismissTimer
        interval: 130
        repeat: false
        onTriggered: root._active = false
    }

    // Open menu at BarContent-local x coordinate.
    // instanceKey / widgetCenterX / widgetLabel are optional — supply for widget right-click.
    function showAt(x, _y, instanceKey, widgetCenterX, widgetLabel) {
        _clickX = x;
        _targetWidgetKey = instanceKey || "";
        _targetWidgetCenterX = widgetCenterX || 0;
        _targetWidgetLabel = widgetLabel || "";
        anchor.updateAnchor();
        BarLayoutService.trayMenuOpen = false;
        BarLayoutService.contextMenuOpen = true;
        _active = true;
    }

    surfaceTransformOrigin: Item.Top

    // Bar menu entries.
    Column {
        id: menuColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 2

        // --- Layout mode item ---
        StaggerItem {
            id: s_layoutItem
            delay: SettingsService.data.animation.staggerLevel1BaseDelay
            exitDelay: 0
            width: parent.width
            height: Theme.barHeight - Theme.barPadding

            // Layout action row.
            ContextMenuAction {
                anchors.fill: parent

                // Layout row content.
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Layout icon.
                    Text {
                        text: "\uf0c9"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeIcon
                        color: BarLayoutService.settingsMode ? Colors.highlight : Colors.text
                        opacity: BarLayoutService.settingsMode ? 1.0 : 0.7
                    }

                    // Layout label.
                    Text {
                        text: BarLayoutService.settingsMode ? "退出布局模式" : "布局模式"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        color: Colors.text
                    }
                }

                onClicked: function(_mouse) {
                    BarLayoutService.activePanel =
                        BarLayoutService.settingsMode ? "none" : "layout"
                    _dismissTimer.restart()
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

            // Settings action row.
            ContextMenuAction {
                anchors.fill: parent

                // Settings row content.
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Settings icon.
                    Text {
                        text: "\uf013"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeIcon
                        color: Colors.text
                        opacity: 0.7
                    }

                    // Settings label.
                    Text {
                        text: "设置"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        color: Colors.text
                    }
                }

                onClicked: function(_mouse) {
                    BarLayoutService.activePanel = "config"
                    _dismissTimer.restart()
                }
            }
        }

        // --- Widget section separator (visible only on widget right-click) ---
        StaggerItem {
            id: s_widgetDivider
            visible: root._targetWidgetKey !== ""
            width: parent.width - 8
            anchors.horizontalCenter: parent.horizontalCenter
            height: visible ? 1 : 0

            ContextMenuDivider {
                anchors.fill: parent
            }
        }

        // --- "组件设置" item ---
        StaggerItem {
            id: s_widgetSettings
            visible: root._targetWidgetKey !== ""
            delay: SettingsService.data.animation.staggerLevel1BaseDelay
                 + SettingsService.data.animation.staggerLevel1Step * 2
            exitDelay: 0
            width: parent.width
            height: visible ? Theme.barHeight - Theme.barPadding : 0

            // Widget settings action row.
            ContextMenuAction {
                anchors.fill: parent

                // Widget settings row content.
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    // Widget settings icon.
                    Text {
                        text: "\uf085"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeIcon
                        color: Colors.text
                        opacity: 0.7
                    }

                    // Widget settings label.
                    Text {
                        text: "组件设置"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeBody
                        color: Colors.text
                    }
                }

                onClicked: function(_mouse) {
                    BarLayoutService.openWidgetSettings(root._targetWidgetKey, root._targetWidgetCenterX)
                    _dismissTimer.restart()
                }
            }
        }
    }

    SequentialAnimation {
        id: exitAnim
        ParallelAnimation {
            NumberAnimation {
                target: root.surface; property: "opacity"
                from: 1; to: 0
                duration: root.exitDuration; easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: root.surface; property: "scale"
                from: 1.0; to: root.closedScale
                duration: root.exitDuration; easing.type: Easing.InQuad
            }
        }
        ScriptAction {
            script: {
                root.visible = false;
                root._targetWidgetKey = "";
                root._targetWidgetCenterX = 0;
                root._targetWidgetLabel = "";
            }
        }
    }
}
