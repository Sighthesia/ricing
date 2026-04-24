import QtQuick
import qs.config
import qs.services

// Renders one measured bar section and hosts its ordered widget delegates.
Item {
    id: section

    required property string role
    property var widgetRegistry: ({})
    implicitWidth: width > 0 ? width : widgetStage.implicitWidth
    implicitHeight: parent ? parent.height : 0

    readonly property var _frameGeometry: BarLayoutService.sectionGeometry(section.role)
    readonly property bool _centerAnchoredSection: (_frameGeometry.anchorMode || "") === "center"
    readonly property bool _pushDrivenByCenter: (_frameGeometry.pushSource || "").indexOf("center-overlap-") === 0
    readonly property real _layoutWidth: Number(_frameGeometry.layoutWidth) || 0
    readonly property real _visualLeft: Number(_frameGeometry.visualLeft) || 0
    property real _animatedVisualLeft: _visualLeft

    x: _centerAnchoredSection || _pushDrivenByCenter ? _visualLeft : _animatedVisualLeft

    // Keep the section reservation tied to the shared layout width.
    Behavior on implicitWidth {
        enabled: BarLayoutService.settingsMode
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    // Keep the whole section body structurally synced to collision ownership.
    Behavior on _animatedVisualLeft {
        enabled: false
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }

    // Collect enabled widgets for this section, sorted by order.
    property var widgets: []

    on_VisualLeftChanged: section._animatedVisualLeft = section._visualLeft
    on_CenterAnchoredSectionChanged: section._animatedVisualLeft = section._visualLeft

    function rebuildWidgets() {
        let result = [];
        for (let i = 0; i < BarLayoutService.layoutModel.count; i++) {
            let item = BarLayoutService.layoutModel.get(i);
            if (item.section === section.role && item.enabled)
                result.push({ widgetId: item.id, order: item.order, index: i });
        }
        // Use layoutModelIndex as stable key for Repeater
        result.sort((a, b) => a.order - b.order);
        widgets = result;
    }

    Component.onCompleted: rebuildWidgets()

    // Rebuild the section model when the shared layout updates.
    Connections {
        target: BarLayoutService
        function onLayoutChanged() { section.rebuildWidgets(); }
    }

    /// Determine insertion index for a drag at `localX` in section space.
    function insertIndexAt(localX) {
        return BarLayoutService.insertionIndexForSectionX(
            section.role,
            localX,
            BarLayoutService.draggedInstanceKey
        )
    }

    // Section-local slot stage.
    Item {
        id: widgetStage
        x: 0
        implicitWidth: Math.max(0, Number(section._layoutWidth) || 0)
        height: parent.height
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: section.widgets
            delegate: widgetDelegate
        }
    }

    // Section highlight overlay.
    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Colors.highlight
        opacity: BarLayoutService.widgetPickerOpen
                 && BarLayoutService.widgetPickerTargetSection === section.role ? 0.08 : 0
        Behavior on opacity {
            NumberAnimation { duration: Theme.anim.highlightDuration }
        }
    }

    // Section insertion marker.
    Rectangle {
        id: insertIndicator
        visible: BarLayoutService.isDragging
            && BarLayoutService.ghostSection === section.role
            && BarLayoutService.ghostIndex >= 0
        width: 2
        height: Theme.barHeight - Theme.widgetPadding
        anchors.verticalCenter: parent.verticalCenter
        color: Colors.highlight
        radius: 1
        opacity: 0.8

        Behavior on x {
            NumberAnimation {
                duration: Theme.anim.moveDuration
                easing.type: Theme.anim.moveType
            }
        }

        x: {
            if (!visible) return 0;
            let geometry = BarLayoutService.insertionIndicatorGeometry(
                section.role,
                BarLayoutService.ghostIndex,
                BarLayoutService.draggedInstanceKey
            )
            return geometry.sectionLocalX - width / 2
        }
    }

    // Widget delegate template.
    Component {
        id: widgetDelegate

        // Render each widget in the section-local slot geometry.
        BarWidgetWrapper {
            required property var modelData
            staggerIndex: modelData.index
            widgetId: modelData.widgetId
            instanceKey: BarLayoutService.instanceKeyAt(modelData.index)
            sectionRole: section.role
            readonly property var _widgetGeometry: BarLayoutService.widgetGeometry(instanceKey)
            readonly property real _baseLeft: Number(_widgetGeometry ? _widgetGeometry.baseLeft : 0) || 0
            readonly property real _localLeft: Number(_widgetGeometry ? _widgetGeometry.localLeft : 0) || 0
            readonly property string _alignmentMode: _widgetGeometry && _widgetGeometry.alignmentMode !== undefined
                ? _widgetGeometry.alignmentMode
                : "left"

            x: _localLeft
            readonly property real _localSlotX: _localLeft
            readonly property real _baseSlotX: _baseLeft
            anchors.verticalCenter: parent.verticalCenter

            // Load the widget content after the wrapper owns the slot geometry.
            Loader {
                source: section.widgetRegistry[modelData.widgetId] || ""
                active: source !== ""
                onLoaded: {
                    if (item && item.hasOwnProperty("liveInstance"))
                        item.liveInstance = true;
                    if (item && item.hasOwnProperty("debugInstanceLabel"))
                        item.debugInstanceLabel = "bar:" + BarLayoutService.instanceKeyAt(modelData.index);
                }
            }
        }
    }
}
