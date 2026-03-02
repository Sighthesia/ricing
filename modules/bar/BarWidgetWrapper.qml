import QtQuick
import qs.config
import qs.services

Item {
    id: wrapper

    property int staggerIndex: 0
    property string widgetId: ""
    default property alias content: contentContainer.data

    // Collapse layout space during drag; content stays visible (clip: false)
    property bool _isDragging: false
    property real _naturalWidth: contentContainer.childrenRect.width
    property real _naturalHeight: contentContainer.childrenRect.height

    implicitWidth: _isDragging ? 0 : _naturalWidth
    implicitHeight: _isDragging ? 0 : _naturalHeight

    // Background for highlight pulse + settings mode outline
    Rectangle {
        id: pulseBackground
        width: wrapper._naturalWidth + 4
        height: wrapper._naturalHeight + 4
        x: -2
        y: -2
        radius: Theme.cornerRadius + 2
        color: "transparent"
        border.color: Colors.highlight
        border.width: BarLayoutService.settingsMode && wrapper._enterDone ? 1 : 0
        opacity: BarLayoutService.settingsMode ? 0.5 : 0

        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }
    }

    Item {
        id: contentContainer
        width: childrenRect.width
        height: childrenRect.height
    }

    // --- Enter animation ---
    opacity: 0
    scale: 0.8
    property bool _enterDone: false

    Component.onCompleted: enterAnimation.start()

    SequentialAnimation {
        id: enterAnimation
        PauseAnimation { duration: wrapper.staggerIndex * Theme.staggerDelay }
        ParallelAnimation {
            NumberAnimation {
                target: wrapper; property: "opacity"
                from: 0; to: 1
                duration: Theme.anim.enterDuration
                easing.type: Theme.anim.enterType
                easing.amplitude: Theme.anim.enterAmplitude
                easing.period: Theme.anim.enterPeriod
            }
            NumberAnimation {
                target: wrapper; property: "scale"
                from: 0.8; to: 1.0
                duration: Theme.anim.enterDuration
                easing.type: Theme.anim.enterType
                easing.amplitude: Theme.anim.enterAmplitude
                easing.period: Theme.anim.enterPeriod
            }
        }
        ScriptAction { script: wrapper._enterDone = true }
    }

    // --- Settings mode drag (visual offset via Translate) ---
    property real dragOffsetX: 0
    // Saved wrapper scene X at drag start (layout position, no Translate)
    property real _dragStartLayoutX: 0

    transform: Translate { x: wrapper.dragOffsetX }

    // Find ancestor with hitTestSection function (BarContent)
    function findBarContent() {
        let bc = wrapper.parent;
        while (bc && !bc.hitTestSection)
            bc = bc.parent;
        return bc;
    }

    // Find the BarSection child for a given section name
    function findSection(bc, sectionName) {
        for (let i = 0; i < bc.children.length; i++) {
            let child = bc.children[i];
            if (child.role === sectionName && child.insertIndexAt)
                return child;
        }
        // Check deeper (inside RowLayout)
        for (let i = 0; i < bc.children.length; i++) {
            let layout = bc.children[i];
            if (!layout.children) continue;
            for (let j = 0; j < layout.children.length; j++) {
                let child = layout.children[j];
                if (child.role === sectionName && child.insertIndexAt)
                    return child;
            }
        }
        return null;
    }

    DragHandler {
        id: dragHandler
        enabled: BarLayoutService.settingsMode && wrapper._enterDone
        target: null
        xAxis.enabled: true
        yAxis.enabled: false

        property real startSceneX: 0

        onActiveChanged: {
            if (active) {
                startSceneX = centroid.scenePosition.x;
                // Record layout scene position (parent.mapToItem excludes our Translate)
                let parentScene = wrapper.parent.mapToItem(null, 0, 0);
                wrapper._dragStartLayoutX = parentScene.x + wrapper.x;
                wrapper.z = 100;
                wrapper.scale = 1.05;
                wrapper._isDragging = true;
                BarLayoutService.isDragging = true;
                BarLayoutService.draggedWidgetId = wrapper.widgetId;
                BarLayoutService.ghostWidth = wrapper._naturalWidth;
            } else {
                wrapper.scale = 1.0;

                let targetSection = BarLayoutService.ghostSection;
                let targetIndex = BarLayoutService.ghostIndex;

                BarLayoutService.isDragging = false;
                BarLayoutService.dragHoverZone = "";
                BarLayoutService.draggedWidgetId = "";
                BarLayoutService.ghostSection = "";
                BarLayoutService.ghostIndex = -1;
                BarLayoutService.ghostWidth = 0;

                if (targetSection !== "") {
                    BarLayoutService.moveWidget(
                        wrapper.widgetId, targetSection, "left", targetIndex);
                }

                wrapper.dragOffsetX = 0;
                wrapper._isDragging = false;
                wrapper.z = 0;
            }
        }

        onCentroidChanged: {
            if (active) {
                // Mouse offset since drag start
                let mouseOffset = centroid.scenePosition.x - startSceneX;
                // Target visual scene X = original layout position + mouse offset
                let targetSceneX = wrapper._dragStartLayoutX + mouseOffset;
                // Current layout position (parent coords exclude our Translate)
                let parentScene = wrapper.parent.mapToItem(null, 0, 0);
                let layoutSceneX = parentScene.x + wrapper.x;
                // Translate = difference between target and current layout position
                wrapper.dragOffsetX = targetSceneX - layoutSceneX;

                let bc = wrapper.findBarContent();
                if (bc && bc.hitTestSection) {
                    // Use _naturalWidth for hit test since wrapper may be collapsed
                    let globalPt = wrapper.mapToItem(bc,
                        wrapper._naturalWidth / 2, wrapper._naturalHeight / 2);
                    let zoneName = bc.hitTestSection(globalPt.x);
                    BarLayoutService.dragHoverZone = zoneName;
                    BarLayoutService.ghostSection = zoneName;

                    // Find target section and calculate insert index
                    let sec = wrapper.findSection(bc, zoneName);
                    if (sec) {
                        let sectionPt = wrapper.mapToItem(sec,
                            wrapper._naturalWidth / 2, wrapper._naturalHeight / 2);
                        BarLayoutService.ghostIndex = sec.insertIndexAt(sectionPt.x);
                    }
                }
            }
        }
    }

    Behavior on scale {
        NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }

    // --- Highlight pulse API ---
    function pulse(count) {
        pulseAnimation.loops = count;
        pulseAnimation.start();
    }

    SequentialAnimation {
        id: pulseAnimation
        NumberAnimation {
            target: pulseBackground; property: "opacity"
            from: 0; to: Colors.highlightAlpha
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }
        NumberAnimation {
            target: pulseBackground; property: "opacity"
            from: Colors.highlightAlpha; to: 0
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }
    }
}
