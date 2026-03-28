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

    // Set by BarWidgetWrapper right-click; "" means bar-background right-click.
    property string _targetWidgetKey: ""
    // Bar-coord X of the widget centre; forwarded to LayoutService on panel open.
    property real _targetWidgetCenterX: 0
    // Human-readable widget type label (currently unused in display, reserved for tooltip).
    property string _targetWidgetLabel: ""
    readonly property int _widgetActionCount: 1
    // FIXME: lift these shared ratios into Theme.anim.* if more panels reuse them.
    readonly property int _enterOpacityDuration:
        Math.max(1, Math.round(Theme.anim.highlightDuration * 0.56))
    readonly property int _enterScaleDuration:
        Math.max(1, Math.round(Theme.anim.springDuration * 0.36))
    readonly property int _exitDuration:
        Math.max(1, Math.round(Theme.anim.highlightDuration * 0.44))

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
            enterAnim.restart();
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
                HoverRevealHighlight {
                    id: layoutHighlight
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: Theme.cornerRadius - 2
                    hovered: layoutArea.containsMouse
                    highlightColor: Colors.highlight
                    highlightOpacity: 0.12
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

                // Ripple above content, below mouse capture.
                ClickRipple {
                    id: layoutRipple
                    anchors.fill: parent
                    anchors.margins: 1
                    rippleColor: Colors.highlight
                }

                MouseArea {
                    id: layoutArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        layoutRipple.triggerRipple(mouse.x, mouse.y)
                        BarLayoutService.activePanel =
                            BarLayoutService.settingsMode ? "none" : "layout";
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

                HoverRevealHighlight {
                    id: settingsHighlight
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: Theme.cornerRadius - 2
                    hovered: settingsArea.containsMouse
                    highlightColor: Colors.highlight
                    highlightOpacity: 0.12
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

                // Ripple above content, below mouse capture.
                ClickRipple {
                    id: settingsRipple
                    anchors.fill: parent
                    anchors.margins: 1
                    rippleColor: Colors.highlight
                }

                MouseArea {
                    id: settingsArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        settingsRipple.triggerRipple(mouse.x, mouse.y)
                        BarLayoutService.activePanel = "config";
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

                Rectangle {
                    anchors.fill: parent
                    color: Colors.border
                    opacity: 0.5
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

                HoverRevealHighlight {
                    anchors.fill: parent; anchors.margins: 1
                    radius: Theme.cornerRadius - 2
                    hovered: widgetSettingsArea.containsMouse
                    highlightColor: Colors.highlight; highlightOpacity: 0.12
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.leftMargin: Theme.widgetPadding
                    spacing: 8
                    Text {
                        text: "\uf085"
                        font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeIcon
                        color: Colors.text; opacity: 0.7
                    }
                    Text {
                        text: "组件设置"
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                        color: Colors.text
                    }
                }
                ClickRipple {
                    id: widgetSettingsRipple
                    anchors.fill: parent; anchors.margins: 1; rippleColor: Colors.highlight
                }
                MouseArea {
                    id: widgetSettingsArea; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        widgetSettingsRipple.triggerRipple(mouse.x, mouse.y)
                        BarLayoutService.openWidgetSettings(root._targetWidgetKey, root._targetWidgetCenterX)
                        _dismissTimer.restart()
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
            duration: root._enterOpacityDuration; easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: menuContent; property: "scale"
            from: 0.85; to: 1.0
            duration: root._enterScaleDuration; easing.type: Easing.OutBack; easing.overshoot: 0.4
        }
    }

    SequentialAnimation {
        id: exitAnim
        ParallelAnimation {
            NumberAnimation {
                target: menuContent; property: "opacity"
                from: 1; to: 0
                duration: root._exitDuration; easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: menuContent; property: "scale"
                from: 1.0; to: 0.88
                duration: root._exitDuration; easing.type: Easing.InQuad
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
