import QtQuick
import qs.config

Item {
    id: wrapper

    property int staggerIndex: 0
    default property alias content: contentContainer.data

    implicitWidth: contentContainer.implicitWidth
    implicitHeight: contentContainer.implicitHeight

    // Background for highlight pulse
    Rectangle {
        id: pulseBackground
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: Palette.highlight
        opacity: 0
    }

    Item {
        id: contentContainer
        anchors.fill: parent
    }

    // Staggered enter animation
    opacity: 0
    scale: 0.8
    Component.onCompleted: {
        enterAnimation.start();
    }

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
    }

    // Highlight pulse API
    function pulse(count) {
        pulseAnimation.loops = count;
        pulseAnimation.start();
    }

    SequentialAnimation {
        id: pulseAnimation
        property int loops: 1
        loops: pulseAnimation.loops
        NumberAnimation {
            target: pulseBackground; property: "opacity"
            from: 0; to: Palette.highlightAlpha
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }
        NumberAnimation {
            target: pulseBackground; property: "opacity"
            from: Palette.highlightAlpha; to: 0
            duration: Theme.anim.highlightDuration
            easing.type: Theme.anim.highlightType
        }
    }
}
