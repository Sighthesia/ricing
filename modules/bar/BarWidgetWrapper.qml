import QtQuick
import qs.config
import qs.services

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

    // Staggered enter animation (initial state; overridden on completed)
    opacity: 0
    scale: 0.8

    // Settings mode dim: wrapper fades to 0.25 when active
    property real normalOpacity: 1.0
    property bool _enterDone: false

    Behavior on normalOpacity {
        NumberAnimation {
            duration: Theme.anim.exitDuration
            easing.type: Easing.InExpo
        }
    }

    // Bind to settingsMode after enter animation finishes
    Connections {
        target: BarLayoutService
        enabled: wrapper._enterDone
        function onSettingsModeChanged() {
            wrapper.normalOpacity = BarLayoutService.settingsMode ? 0.25 : 1.0;
            wrapper.opacity = wrapper.normalOpacity;
        }
    }

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
        ScriptAction {
            script: {
                wrapper._enterDone = true;
                wrapper.normalOpacity = BarLayoutService.settingsMode ? 0.25 : 1.0;
                wrapper.opacity = wrapper.normalOpacity;
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
