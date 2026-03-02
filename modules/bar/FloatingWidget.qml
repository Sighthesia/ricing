import QtQuick
import qs.config
import qs.services

Item {
    id: floatingWidget

    property string widgetId: ""
    property string widgetSection: ""
    property string widgetAlignment: ""
    property Item parentOverlay: null

    width: 80
    height: Theme.barHeight - 8

    // Initial position: center of the source section
    x: {
        let thirdWidth = parentOverlay ? parentOverlay.width / 3 : 100;
        if (widgetSection === "left") return thirdWidth * 0.5 - width / 2;
        if (widgetSection === "center") return thirdWidth * 1.5 - width / 2;
        return thirdWidth * 2.5 - width / 2;
    }
    y: parentOverlay ? (parentOverlay.height - height) / 2 : 0

    // Enter animation: elastic scale bounce
    scale: 0.8
    opacity: 0

    Component.onCompleted: {
        enterAnim.start();
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation {
            target: floatingWidget; property: "scale"
            from: 0.8; to: 1.0
            duration: Theme.anim.enterDuration
            easing.type: Theme.anim.enterType
            easing.amplitude: Theme.anim.enterAmplitude
            easing.period: Theme.anim.enterPeriod
        }
        NumberAnimation {
            target: floatingWidget; property: "opacity"
            from: 0; to: 1
            duration: Theme.anim.enterDuration
            easing.type: Theme.anim.enterType
            easing.amplitude: Theme.anim.enterAmplitude
            easing.period: Theme.anim.enterPeriod
        }
    }

    // Visual: label card
    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Colors.surface
        border.color: Colors.border
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: floatingWidget.widgetId
            font.family: Theme.fontFamily
            font.pixelSize: 11
            color: Colors.text
        }
    }

    // Drag handler
    DragHandler {
        id: dragHandler
        target: floatingWidget

        onActiveChanged: {
            if (active) {
                floatingWidget.scale = 1.05;
            } else {
                floatingWidget.scale = 1.0;
                // Hit-test on release
                if (parentOverlay) {
                    let targetSection = parentOverlay.hitTestZone(
                        floatingWidget.x + floatingWidget.width / 2
                    );
                    // Fly to new position
                    flyAnim.targetSection = targetSection;
                    let thirdWidth = parentOverlay.width / 3;
                    if (targetSection === "left")
                        flyAnim.targetX = thirdWidth * 0.5 - floatingWidget.width / 2;
                    else if (targetSection === "center")
                        flyAnim.targetX = thirdWidth * 1.5 - floatingWidget.width / 2;
                    else
                        flyAnim.targetX = thirdWidth * 2.5 - floatingWidget.width / 2;

                    flyAnim.start();
                    parentOverlay.clearHighlights();
                }
            }
        }

        onTranslationChanged: {
            if (active && parentOverlay) {
                let zone = parentOverlay.hitTestZone(
                    floatingWidget.x + floatingWidget.width / 2
                );
                parentOverlay.highlightZone(zone);
            }
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }
    }

    // Fly-to-target animation
    SequentialAnimation {
        id: flyAnim
        property string targetSection: ""
        property real targetX: 0

        NumberAnimation {
            target: floatingWidget; property: "x"
            to: flyAnim.targetX
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
        ScriptAction {
            script: {
                BarLayoutService.moveWidget(
                    floatingWidget.widgetId,
                    flyAnim.targetSection,
                    floatingWidget.widgetAlignment,
                    0
                );
            }
        }
    }
}
