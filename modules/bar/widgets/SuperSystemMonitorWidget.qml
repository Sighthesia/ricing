import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import ".." as BarComponents
import "systemmonitor" as MonitorParts

Item {
    id: root

    readonly property var _settings: SettingsService.data ? SettingsService.data.systemMonitor : null
    readonly property bool _enabled: !!(_settings && _settings.enabled)
    readonly property bool _hoverReveal: !!(_settings && _settings.hoverReveal)
    readonly property bool _resolvedExpanded: root._enabled && root._hoverReveal && (root._hovered || _hoverExitHoldTimer.running)
    readonly property bool _transitionRunning: _transition.running
    property bool _hovered: false
    property bool _expandedVisualActive: false
    property int _hoverExitHoldDuration: 1500

    readonly property var _persistentMetrics: SystemMonitorService.persistentMetrics
    readonly property var _expandedMetrics: root._visibleExpandedMetrics()

    implicitWidth: root._enabled ? _transition.animatedWidth : 0
    implicitHeight: root._enabled ? _transition.animatedHeight : 0
    width: implicitWidth
    height: implicitHeight
    visible: root._enabled

    function _visibleExpandedMetrics() {
        const metrics = SystemMonitorService.expandedMetrics || []
        const visibleMetrics = []
        for (let index = 0; index < metrics.length; index++) {
            const metric = metrics[index]
            if (!metric)
                continue

            if (metric.key === "battery" && metric.available === false)
                continue

            visibleMetrics.push(metric)
        }
        return visibleMetrics
    }

    function _isExpanded() {
        return root._resolvedExpanded
    }

    function _syncExpandedVisualState() {
        if (root._resolvedExpanded)
            root._expandedVisualActive = true
    }

    on_ResolvedExpandedChanged: root._syncExpandedVisualState()
    on_HoveredChanged: {
        if (root._hovered) {
            _hoverExitHoldTimer.stop()
            root._expandedVisualActive = root._resolvedExpanded
            return
        }

        if (root._enabled && root._hoverReveal && root._expandedMetrics.length > 0)
            _hoverExitHoldTimer.restart()
    }

    Component.onCompleted: root._expandedVisualActive = root._resolvedExpanded

    BarComponents.BarExpandTransition {
        id: _transition

        collapsedWidth: persistentRow.implicitWidth + Theme.barWidget.contentPaddingH * 2
        expandedWidth: persistentRow.implicitWidth
            + (root._expandedMetrics.length > 0
                ? Theme.barWidget.pillSpacing
                  + root._expandedMetrics.length * Theme.barWidget.pillHeight
                  + (root._expandedMetrics.length - 1) * Theme.barWidget.iconSpacing
                : 0)
            + Theme.barWidget.contentPaddingH * 2
        collapsedHeight: Theme.barWidget.pillHeight
        expandedHeight: Theme.barWidget.pillHeight
        expanded: root._isExpanded()
        animateWidth: true
        animateHeight: false
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Colors.background
    }

    HoverHandler {
        enabled: root._enabled
        onHoveredChanged: root._hovered = hovered
    }

    Timer {
        id: _hoverExitHoldTimer

        interval: root._hoverExitHoldDuration
        repeat: false
        onTriggered: Qt.callLater(() => {
            if (!root._resolvedExpanded && !_transition.running)
                root._expandedVisualActive = false
        })
    }

    Connections {
        target: _transition

        function onRunningChanged() {
            if (_transition.running) {
                root._expandedVisualActive = true
                return
            }

            if (!root._resolvedExpanded)
                root._expandedVisualActive = false
        }
    }

    Item {
        id: content
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Theme.barWidget.contentPaddingH
        anchors.right: parent.right
        anchors.rightMargin: Theme.barWidget.contentPaddingH
        height: Theme.barWidget.pillHeight
        clip: true

        RowLayout {
            id: persistentRow
            objectName: "systemMonitorPersistentRow"
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.barWidget.iconSpacing

            Repeater {
                model: root._persistentMetrics

                delegate: MonitorParts.SystemMonitorGauge {
                    required property var modelData
                    objectName: "systemMonitorGauge_" + modelData.key
                    metric: modelData
                    interactive: false
                }
            }
        }

        RowLayout {
            id: expandedRow
            objectName: "systemMonitorExpandedRow"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: persistentRow.right
            anchors.leftMargin: Theme.barWidget.pillSpacing
            spacing: Theme.barWidget.iconSpacing
            visible: root._enabled && root._expandedVisualActive && root._expandedMetrics.length > 0

            Repeater {
                model: root._enabled ? root._expandedMetrics : []

                delegate: MonitorParts.SystemMonitorGauge {
                    required property var modelData
                    objectName: "systemMonitorGauge_" + modelData.key
                    metric: modelData
                    interactive: modelData.key === "volume" || modelData.key === "brightness"
                    onStepRequested: (direction) => {
                        if (modelData.key === "volume")
                            SystemMonitorService.adjustVolumeByStep(direction)
                        else if (modelData.key === "brightness")
                            SystemMonitorService.adjustBrightnessByStep(direction)
                    }
                }
            }
        }
    }
}
