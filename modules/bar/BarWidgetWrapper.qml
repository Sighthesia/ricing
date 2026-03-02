import QtQuick
import qs.config
import qs.services

Item {
    id: wrapper

    property int staggerIndex: 0
    property string widgetId: ""
    default property alias content: contentContainer.data

    implicitWidth: contentContainer.childrenRect.width
    implicitHeight: contentContainer.childrenRect.height

    // Background for highlight pulse + settings mode outline
    Rectangle {
        id: pulseBackground
        anchors.fill: parent
        anchors.margins: -2
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

    transform: Translate { x: wrapper.dragOffsetX }

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
                wrapper.z = 100;
                wrapper.scale = 1.05;
                BarLayoutService.isDragging = true;
            } else {
                wrapper.scale = 1.0;
                BarLayoutService.isDragging = false;
                BarLayoutService.dragHoverZone = "";

                // Hit-test via barContent
                let bc = wrapper.parent;
                while (bc && !bc.hitTestSection)
                    bc = bc.parent;

                if (bc && bc.hitTestSection) {
                    let globalPt = wrapper.mapToItem(bc,
                        wrapper.width / 2 + wrapper.dragOffsetX,
                        wrapper.height / 2);
                    let targetSection = bc.hitTestSection(globalPt.x);
                    if (targetSection !== "") {
                        BarLayoutService.moveWidget(
                            wrapper.widgetId, targetSection, "left", 0);
                    }
                }

                wrapper.dragOffsetX = 0;
                wrapper.z = 0;
            }
        }

        onCentroidChanged: {
            if (active) {
                wrapper.dragOffsetX = centroid.scenePosition.x - startSceneX;

                // Update hover zone for DropZone highlights
                let bc = wrapper.parent;
                while (bc && !bc.hitTestSection)
                    bc = bc.parent;
                if (bc && bc.hitTestSection) {
                    let globalPt = wrapper.mapToItem(bc,
                        wrapper.width / 2 + wrapper.dragOffsetX,
                        wrapper.height / 2);
                    BarLayoutService.dragHoverZone = bc.hitTestSection(globalPt.x);
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
