import QtQuick
import "../../services" as Services

// Shared popup motion layer: fade + anchored scale-in for floating surfaces.
Item {
    id: root

    default property alias contentData: contentHost.data

    property bool shown: false
    property real hiddenScale: 0.96

    opacity: shown ? 1 : 0
    scale: shown ? 1 : hiddenScale

    Behavior on opacity {
        NumberAnimation {
            duration: Services.Motion.popup.opacityDuration
            easing.type: Services.Motion.popup.opacityEasing
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Services.Motion.popup.scaleDuration
            easing.type: Services.Motion.popup.scaleEasing
            easing.overshoot: Services.Motion.popup.scaleOvershoot
        }
    }

    // Host the floating surface content above the motion layer.
    Item {
        id: contentHost

        anchors.fill: parent
    }
}
