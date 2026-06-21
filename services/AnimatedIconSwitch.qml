import QtQuick
import Quickshell.Widgets
import "./" as Services

// Switch one icon source with the same directional fade-and-drift treatment as text.
Item {
    id: root

    property string source: ""
    property int switchDuration: Services.Motion.number.surfaceDuration
    property real offsetX: 15
    property real offsetY: 15
    property real incomingFadeDelay: 0.04
    property real incomingFadeFloor: 0.03
    property real incomingOffsetScale: 1.45

    property string _displayedSource: ""
    property string _previousSource: ""
    property real _phase: 1
    property bool _transitioning: false

    implicitWidth: 18
    implicitHeight: 18

    function syncSource() {
        var nextSource = root.source || ""

        if (nextSource === root._displayedSource)
            return

        root._previousSource = root._displayedSource
        root._displayedSource = nextSource

        if (root._previousSource === "") {
            root._phase = 1
            root._transitioning = false
            return
        }

        root._transitioning = true
        root._phase = 0
        phaseAnimation.stop()
        phaseAnimation.restart()
    }

    function incomingOpacity(progress) {
        var delayed = Math.max(0, (progress - root.incomingFadeDelay) / Math.max(0.0001, 1 - root.incomingFadeDelay))
        return root.incomingFadeFloor + (1 - root.incomingFadeFloor) * Math.pow(delayed, 0.6)
    }

    onSourceChanged: syncSource()
    Component.onCompleted: syncSource()

    // Drift the previous icon down-right while fading it away.
    IconImage {
        width: parent.width
        height: parent.height
        x: root._transitioning ? root.offsetX * root._phase : 0
        y: root._transitioning ? root.offsetY * root._phase : 0
        source: root._previousSource
        opacity: root._transitioning ? (1 - root._phase) : 0
        visible: root._previousSource !== "" && opacity > 0.01
    }

    // Bring the new icon in from down-left toward its resting position.
    IconImage {
        readonly property real positionProgress: Math.min(1, Math.pow(root._phase, 0.78) * 1.18)

        width: parent.width
        height: parent.height
        x: root._transitioning ? -root.offsetX * root.incomingOffsetScale * (1 - positionProgress) : 0
        y: root._transitioning ? root.offsetY * root.incomingOffsetScale * (1 - positionProgress) : 0
        source: root._displayedSource
        opacity: root._transitioning ? root.incomingOpacity(root._phase) : 1
        visible: root._displayedSource !== ""
    }

    NumberAnimation {
        id: phaseAnimation

        target: root
        property: "_phase"
        from: 0
        to: 1
        duration: root.switchDuration
        easing.type: Services.Motion.number.surfaceEasing
        onFinished: {
            root._previousSource = ""
            root._transitioning = false
            root._phase = 1
        }
    }
}
