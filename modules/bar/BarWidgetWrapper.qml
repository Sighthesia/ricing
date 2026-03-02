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

    // --- Settings mode drag (direct, no floating copies) ---
    DragHandler {
        id: dragHandler
        enabled: BarLayoutService.settingsMode && wrapper._enterDone
        target: wrapper
        xAxis.enabled: true
        yAxis.enabled: false

        onActiveChanged: {
            if (active) {
                wrapper.z = 100;
                wrapper.scale = 1.05;
            } else {
                wrapper.scale = 1.0;
                // Hit-test: map center to barContent coordinate space
                let barContent = wrapper.parent;
                while (barContent && !barContent.hitTestSection)
                    barContent = barContent.parent;

                if (barContent && barContent.hitTestSection) {
                    let globalPt = wrapper.mapToItem(barContent,
                        wrapper.width / 2, wrapper.height / 2);
                    let targetSection = barContent.hitTestSection(globalPt.x);
                    if (targetSection !== "") {
                        BarLayoutService.moveWidget(
                            wrapper.widgetId, targetSection, "left", 0);
                    }
                }

                // Snap back to layout position
                wrapper.x = 0;
                wrapper.z = 0;
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
