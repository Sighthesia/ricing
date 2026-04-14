import Quickshell
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import ".." as BarComponents
import "systemmonitor" as MonitorParts

// Expanding system monitor pill that surfaces pinned metrics and quick status controls.
Item {
    id: root

    property bool liveInstance: false

    readonly property var _settings: SettingsService.data ? SettingsService.data.systemMonitor : null
    readonly property bool _enabled: !!(_settings && _settings.enabled)
    readonly property bool _hoverReveal: !!(_settings && _settings.hoverReveal)
    readonly property bool _hoverRevealAllowed:
        root._hoverReveal && !(BarLayoutService.settingsMode && BarLayoutService.isDragging)
    readonly property bool _dragCollapseActive:
        BarLayoutService.settingsMode && BarLayoutService.isDragging
    readonly property bool _resolvedExpanded: root._enabled && root._hoverRevealAllowed && (root._hovered || _hoverExitHoldTimer.running)
    readonly property bool _transitionRunning: _transition.running
    readonly property bool _flashHeightAnimated: false
    readonly property int _pillHeight: Theme.barWidget.pillHeight
    readonly property int _flashGap: Theme.barWidget.stackGap
    readonly property int _flashRowHeight: Theme.barWidget.pillHeight
    readonly property int _baseHeight: root._pillHeight + Theme.iconPadding
    readonly property real _mainRowRequiredWidth: persistentRow.implicitWidth
        + (expandedRow.visible ? (Theme.barWidget.pillSpacing + expandedRow.implicitWidth) : 0)
    property bool _hovered: false
    property bool _expandedVisualActive: false
    property int _hoverExitHoldDuration: 1500
    property string _flashMetricKey: ""
    property var _flashDetail: null
    property bool _flashExpanded: false
    readonly property bool _flashVisualActive: root._flashExpanded || _flashCollapseTimer.running
    property bool _flashClosePending: false
    readonly property real _verticalRevealSurfaceHeight: _verticalReveal.surfaceHeight
    readonly property real _verticalRevealClipHeight: _verticalReveal.clipHeight

    readonly property var _persistentMetrics: SystemMonitorService.persistentMetrics
    readonly property var _expandedMetrics: root._visibleExpandedMetrics()

    implicitWidth: root._enabled ? _transition.animatedWidth : 0
    implicitHeight: root._enabled ? root._baseHeight : 0
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

    function _setFlashDetail(metricKey, visible, detail) {
        if (visible) {
            _flashCollapseTimer.stop()
            root._flashMetricKey = metricKey
            root._flashDetail = detail || null
            root._flashClosePending = false
            root._flashExpanded = !!(root._flashDetail && root._flashDetail.labelText)
            return
        }

        if (root._flashMetricKey !== metricKey)
            return

        root._flashClosePending = true

        if (!root._resolvedExpanded)
            root._beginFlashCollapse()
    }

    function _beginFlashCollapse() {
        if (!root._flashDetail || !root._flashDetail.labelText)
            return

        root._flashExpanded = false
        _flashCollapseTimer.restart()
    }

    function _forceImmediateCollapse() {
        root._hovered = false
        root._expandedVisualActive = false
        root._flashExpanded = false
        root._flashClosePending = false
        root._flashMetricKey = ""
        root._flashDetail = null
        _hoverExitHoldTimer.stop()
        _flashCollapseTimer.stop()
    }

    function _syncExpandedVisualState() {
        if (root._resolvedExpanded)
            root._expandedVisualActive = true
    }

    on_ResolvedExpandedChanged: root._syncExpandedVisualState()
    on_HoverRevealAllowedChanged: {
        if (root._hoverRevealAllowed)
            return

        root._forceImmediateCollapse()
    }

    on_DragCollapseActiveChanged: {
        if (root._dragCollapseActive)
            root._forceImmediateCollapse()
    }
    on_HoveredChanged: {
        if (root._hovered) {
            _hoverExitHoldTimer.stop()
            root._expandedVisualActive = root._resolvedExpanded
            return
        }

        if (root._enabled && root._hoverRevealAllowed && root._expandedMetrics.length > 0)
            _hoverExitHoldTimer.restart()

        if (!root._resolvedExpanded && root._flashClosePending)
            root._beginFlashCollapse()
    }

    Component.onCompleted: root._expandedVisualActive = root._resolvedExpanded

    BarComponents.BarTransientRevealHost {
        id: _verticalReveal

        collapsedHeight: root._pillHeight
        expandedHeight: root._pillHeight + root._flashGap + root._flashRowHeight
        expanded: root._flashVisualActive
        extensionOwnerKey: root.liveInstance ? "system-monitor" : ""
        animateSurface: false
    }

    BarComponents.BarExpandTransition {
        id: _transition

        collapsedWidth: persistentRow.implicitWidth + Theme.barWidget.contentPaddingH * 2
        expandedWidth: root._mainRowRequiredWidth + Theme.barWidget.contentPaddingH * 2
        collapsedHeight: root._pillHeight
        expandedHeight: root._pillHeight
        expanded: root._isExpanded()
        animateWidth: true
        animateHeight: false
    }

    Rectangle {
        id: widgetBackground

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: pill.top
        height: root._verticalRevealSurfaceHeight
        radius: Theme.cornerRadius
        color: Colors.background
    }

    Timer {
        id: _hoverExitHoldTimer

        interval: root._hoverExitHoldDuration
        repeat: false
        onTriggered: Qt.callLater(() => {
            if (!root._resolvedExpanded && !_transition.running)
                root._expandedVisualActive = false

            if (!root._resolvedExpanded && root._flashClosePending)
                root._beginFlashCollapse()
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

    Timer {
        id: _flashCollapseTimer

        interval: Theme.anim.moveDuration
        repeat: false
        onTriggered: {
            if (root._flashExpanded)
                return

            root._flashClosePending = false
            root._flashMetricKey = ""
            root._flashDetail = null
        }
    }

    Item {
        id: pill
        objectName: "systemMonitorPill"

        anchors.top: parent.top
        anchors.topMargin: Theme.iconPadding
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: root.implicitWidth
        implicitHeight: root._verticalRevealClipHeight
        width: implicitWidth
        height: implicitHeight
        clip: true

        HoverHandler {
            enabled: root._enabled && root._hoverRevealAllowed
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onHoveredChanged: root._hovered = hovered
        }

        Behavior on implicitHeight {
            NumberAnimation {
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        Item {
            id: content
            objectName: "systemMonitorContent"
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.leftMargin: Theme.barWidget.contentPaddingH
            anchors.right: parent.right
            anchors.rightMargin: Theme.barWidget.contentPaddingH
            height: parent.height
            clip: true

            Item {
                id: mainRow
                objectName: "systemMonitorMainRow"
                anchors.left: parent.left
                y: (root._pillHeight - persistentRow.implicitHeight) / 2
                implicitWidth: root._mainRowRequiredWidth
                implicitHeight: Math.max(persistentRow.implicitHeight, expandedRow.implicitHeight)
                width: parent.width
                height: implicitHeight
            }

            RowLayout {
                id: persistentRow
                objectName: "systemMonitorPersistentRow"
                parent: mainRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.barWidget.iconSpacing

                Repeater {
                    model: root._persistentMetrics

                    delegate: MonitorParts.SystemMonitorGauge {
                        required property var modelData
                        objectName: "systemMonitorGauge_" + modelData.key
                        metric: modelData
                        interactive: false
                        onDetailVisibilityChanged: (visible, detail) => {
                            root._setFlashDetail(modelData.key, visible, detail)
                        }
                    }
                }
            }

            RowLayout {
                id: expandedRow
                objectName: "systemMonitorExpandedRow"
                parent: mainRow
                y: (parent.height - implicitHeight) / 2
                x: Math.max(0, Math.min(
                    persistentRow.width + Theme.barWidget.pillSpacing,
                    parent.width - implicitWidth
                ))
                spacing: Theme.barWidget.iconSpacing
                visible: root._enabled && root._expandedVisualActive && root._expandedMetrics.length > 0

                Repeater {
                    model: root._enabled ? root._expandedMetrics : []

                    delegate: MonitorParts.SystemMonitorGauge {
                        required property var modelData
                        objectName: "systemMonitorGauge_" + modelData.key
                        metric: modelData
                        interactive: modelData.key === "volume" || modelData.key === "brightness"
                        onDetailVisibilityChanged: (visible, detail) => {
                            root._setFlashDetail(modelData.key, visible, detail)
                        }
                        onStepRequested: (direction) => {
                            if (modelData.key === "volume")
                                SystemMonitorService.adjustVolumeByStep(direction)
                            else if (modelData.key === "brightness")
                                SystemMonitorService.adjustBrightnessByStep(direction)
                        }
                    }
                }
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root._pillHeight + Math.max(0, (root._flashGap - height) / 2)
                width: Math.max(0, parent.width)
                height: 1
                radius: 1
                color: Colors.border
                opacity: root._flashVisualActive ? 0.35 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.anim.moveDuration
                        easing.type: Theme.anim.moveType
                    }
                }
            }

            Item {
                id: flashRow
                objectName: "systemMonitorFlashRow"
                anchors.left: parent.left
                anchors.right: parent.right
                y: root._pillHeight + root._flashGap
                height: root._flashRowHeight
                visible: root._flashVisualActive

                RowLayout {
                    anchors.centerIn: parent
                    spacing: Theme.barWidget.iconLabelSpacing

                    Text {
                        objectName: "systemMonitorFlashIcon"
                        visible: !!(root._flashDetail && root._flashDetail.glyph)
                        text: root._flashDetail && root._flashDetail.glyph ? root._flashDetail.glyph : ""
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeIcon
                        color: root._flashDetail && root._flashDetail.iconColor ? root._flashDetail.iconColor : Colors.text
                    }

                    Text {
                        objectName: "systemMonitorFlashLabel"
                        text: root._flashDetail && root._flashDetail.labelText ? root._flashDetail.labelText : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSizeSmall
                        color: root._flashDetail && root._flashDetail.available === false ? Colors.textMuted : Colors.text
                    }
                }
            }
        }
    }
}
