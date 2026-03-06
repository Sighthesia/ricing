import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "widget-settings"
import "settings"

// Floating bubble panel anchored below the bar, horizontally centred on the
// active widget. Shown when BarLayoutService.widgetSettingsPanelOpen = true
// AND BarLayoutService.activeWidgetInstanceKey is non-empty.
//
// Must be placed inside BarContent with anchorTarget = the BarContent Item.
PopupWindow {
    id: root

    StaggerOrchestrator {
        id: _stagger
    }

    required property Item anchorTarget

    color: "transparent"

    anchor.item: anchorTarget
    anchor.rect.y: anchorTarget.height
    anchor.rect.width: 1
    anchor.rect.height: 1
    anchor.rect.x: Math.max(0, Math.min(
        BarLayoutService.widgetSettingsX - implicitWidth / 2,
        anchorTarget.width > 0 ? anchorTarget.width - implicitWidth : 0))

    implicitWidth: 300
    // Fixed height to avoid Wayland surface resize on ExpandableGroup expand/collapse.
    // Content scrolls internally via Flickable.
    implicitHeight: 380

    // State machine: "closed" | "opening" | "open" | "closing"
    // Keeps Wayland surface alive during close animation.
    property string _state: "closed"
    visible: _state !== "closed"

    readonly property string _widgetId: {
        let key = BarLayoutService.activeWidgetInstanceKey;
        if (!key) return "";
        return key.split("_").slice(0, -1).join("_");
    }

    readonly property bool _shouldBeOpen:
        BarLayoutService.widgetSettingsPanelOpen
        && BarLayoutService.activeWidgetInstanceKey !== ""

    on_ShouldBeOpenChanged: {
        if (_shouldBeOpen) {
            if (_state === "closed" || _state === "closing") {
                _scaleCloseAnim.stop();
                _opacityCloseAnim.stop();
                _opacityDelayTimer.stop();
                _state = "opening";
                panelCard._scaleY = 0.0;
                panelCard.opacity = 0.0;
                _scaleOpenAnim.restart();
                _opacityDelayTimer.restart();
                // Stagger groups in after panel scale animation completes
                _staggerEnterTimer.restart();
            }
        } else {
            if (_state === "open" || _state === "opening") {
                _scaleOpenAnim.stop();
                _opacityOpenAnim.stop();
                _opacityDelayTimer.stop();
                _staggerEnterTimer.stop();
                _state = "closing";
                _stagger.clear();
                _stagger.registerItem(_siHeader, 0, 1);
                _stagger.registerItem(_siAppearance, 1, 1);
                _stagger.registerItem(_siFunctional, 2, 1);
                _stagger.registerItem(_siDelete, 3, 1);
                _stagger.runExit();
                // Defensive fallback: ensure panel sections always leave visible state
                // even if orchestration timing is interrupted mid-transition.
                _siHeader.runExit();
                _siAppearance.runExit();
                _siFunctional.runExit();
                _siDelete.runExit();
                _opacityCloseAnim.restart();
                _scaleCloseAnim.restart();
            }
        }
    }

    // Delay group stagger start until panel scale animation is partially complete.
    Timer {
        id: _staggerEnterTimer
        interval: 120; repeat: false
        onTriggered: {
            _stagger.clear()
            _stagger.registerItem(_siHeader, 0, 1)
            _stagger.registerItem(_siAppearance, 1, 1)
            _stagger.registerItem(_siFunctional, 2, 1)
            _stagger.registerItem(_siDelete, 3, 1)
            _stagger.runEnter()
            // Defensive fallback: some compositor/lifecycle races can skip the
            // orchestrated callback on first open; explicitly trigger all groups.
            _siHeader.runEnter()
            _siAppearance.runEnter()
            _siFunctional.runEnter()
            _siDelete.runEnter()
        }
    }

    // Enter animation — mirrors AnimatedPanelBase:
    // scaleY 0→1 (OutBack 280ms) + opacity 0→1 (OutQuad 180ms, delayed 60ms)
    PropertyAnimation {
        id: _scaleOpenAnim
        target: panelCard; property: "_scaleY"; to: 1.0
        duration: 280; easing.type: Easing.OutBack; easing.overshoot: 0.7
        onFinished: if (root._state === "opening") root._state = "open"
    }
    PropertyAnimation {
        id: _opacityOpenAnim
        target: panelCard; property: "opacity"; to: 1.0
        duration: 180; easing.type: Easing.OutQuad
    }
    Timer {
        id: _opacityDelayTimer
        interval: 60; repeat: false
        onTriggered: _opacityOpenAnim.restart()
    }

    // Exit animation — mirrors AnimatedPanelBase:
    // opacity 1→0 (InQuad 120ms) || scaleY 1→0 (InBack 200ms)
    PropertyAnimation {
        id: _scaleCloseAnim
        target: panelCard; property: "_scaleY"; to: 0.0
        duration: 200; easing.type: Easing.InBack; easing.overshoot: 0.7
        onFinished: if (root._state === "closing") root._state = "closed"
    }
    PropertyAnimation {
        id: _opacityCloseAnim
        target: panelCard; property: "opacity"; to: 0.0
        duration: 120; easing.type: Easing.InQuad
    }

    // Panel card
    Rectangle {
        id: panelCard
        anchors.fill: parent
        anchors.topMargin: 4
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        anchors.bottomMargin: 4
        radius: Theme.cornerRadius
        color: Colors.background
        border.color: Colors.border
        border.width: 1

        // ScaleY transform from the top edge (panel expands downward)
        property real _scaleY: 0.0
        transform: Scale { origin.x: 0; origin.y: 0; xScale: 1.0; yScale: panelCard._scaleY }

        // Inner highlight border
        Rectangle {
            anchors.fill: parent; anchors.margins: 1
            radius: Theme.cornerRadius - 1
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.04); border.width: 1
        }

        // Scrollable content area — Flickable height excludes the fixed delete button below
        Flickable {
            id: contentFlickable
            anchors {
                top: parent.top; left: parent.left; right: parent.right
                bottom: _siDelete.top
                margins: 12; bottomMargin: 0
            }
            contentHeight: panelLayout.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: panelLayout
            width: contentFlickable.width
            spacing: 0

            // Header row
            StaggerItem {
                id: _siHeader
                Layout.fillWidth: true
                height: _headerRow.implicitHeight + 8  // matches Layout.bottomMargin
                delay:        160
                enterOffsetY: 20
                exitOffsetY:  10
                exitDelay: 0

            Row {
                id: _headerRow
                width: parent.width
                anchors.top: parent.top
                spacing: 8

                // Back button
                Rectangle {
                    width: 28; height: 28; radius: Theme.cornerRadius - 2
                    color: "transparent"
                    border.color: backBtnArea.containsMouse ? Colors.highlight : "transparent"
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: Theme.anim.highlightDuration } }
                    Text {
                        anchors.centerIn: parent
                        text: "\uf053"
                        font.family: Theme.fontMono; font.pixelSize: Theme.fontSizeIcon
                        color: Colors.text
                    }
                    MouseArea {
                        id: backBtnArea; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            BarLayoutService.widgetSettingsPanelOpen = false;
                            BarLayoutService.activeWidgetInstanceKey = "";
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        let widgetId = root._widgetId;
                        if (!widgetId) return "组件设置";
                        let names = { clock: "时钟", workspaceWidget: "工作区" };
                        return (names[widgetId] || widgetId) + " — 设置";
                    }
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                    color: Colors.text; font.weight: Font.Medium
                }
            }
            } // StaggerItem _siHeader

            // Divider between header and groups
            Rectangle { Layout.fillWidth: true; height: 1; color: Colors.border; opacity: 0.4; Layout.bottomMargin: 4 }

            // Appearance group
            StaggerItem {
                id: _siAppearance
                Layout.fillWidth: true
                height: _groupAppearance.implicitHeight
                delay:        240
                enterOffsetY: 20
                exitOffsetY:  10
                exitDelay: 0

            ExpandableGroup {
                id: _groupAppearance
                width: parent.width
                title: "外观"

                AppearanceSection {
                    width: parent.width
                    instanceKey: BarLayoutService.activeWidgetInstanceKey
                }
            }
            } // StaggerItem _siAppearance

            // Functional config group
            StaggerItem {
                id: _siFunctional
                Layout.fillWidth: true
                height: _groupFunctional.implicitHeight
                delay:        320
                enterOffsetY: 20
                exitOffsetY:  10
                exitDelay: 0

            ExpandableGroup {
                id: _groupFunctional
                width: parent.width
                title: "功能"
                expanded: false

                Loader {
                    width: parent.width
                    active: root._widgetId === "workspaceWidget"
                    sourceComponent: WorkspaceWidgetSection { width: parent.width }
                }

                Text {
                    width: parent.width
                    visible: root._widgetId !== "workspaceWidget"
                    height: visible ? Theme.settingsRowHeight : 0
                    text: "暂无可用设置"
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                    color: Colors.textMuted; opacity: 0.5
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            } // StaggerItem _siFunctional
        }
        } // Flickable

        // Delete widget — fixed at the bottom of the panel card, always visible
        StaggerItem {
            id: _siDelete
            anchors {
                left: parent.left; right: parent.right; bottom: parent.bottom
                margins: 12; bottomMargin: 10
            }
            height: 28
            delay: 360
            exitDelay: 0

            Rectangle {
                id: deleteBtn
                anchors.fill: parent
                radius: Theme.cornerRadius - 2
                color: _deleteArea.containsMouse ? Qt.rgba(247, 118, 142, 0.15) : Colors.surface
                border.color: _deleteArea.containsMouse ? "#f7768e" : Colors.border
                border.width: 1
                Behavior on color        { ColorAnimation { duration: Theme.anim.highlightDuration } }
                Behavior on border.color { ColorAnimation { duration: Theme.anim.highlightDuration } }

                Text {
                    anchors.centerIn: parent
                    text: "删除组件"
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSizeBody
                    color: "#f7768e"
                }
                MouseArea {
                    id: _deleteArea; anchors.fill: parent
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let key = BarLayoutService.activeWidgetInstanceKey;
                        WidgetConfigService.removeConfig(key);
                        BarLayoutService.removeWidget(key);
                        // Panel closes automatically via removeWidget → settingsMode guard
                    }
                }
            }
        }
    }

    // Close when context menu opens (focus shift)
    Connections {
        target: BarLayoutService
        function onContextMenuOpenChanged() {
            if (BarLayoutService.contextMenuOpen) {
                BarLayoutService.widgetSettingsPanelOpen = false;
                BarLayoutService.activeWidgetInstanceKey = "";
            }
        }
    }
}
