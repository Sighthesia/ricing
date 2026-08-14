import QtQuick

// Contain focus and stage a modal panel above a dimmed backdrop.
Item {
    id: root
    default property alias content: body.data
    property string phase: "closed"
    property bool interactive: phase === "opening" || phase === "open"
    property Item opener: null
    property real progress: 0
    property real backdropProgress: 0
    readonly property real backdropTargetOpacity: MotionTokens.backdropOpacity
    readonly property int backdropEnterDuration: MotionTokens.backdropEnter
    readonly property int panelEnterDuration: MotionTokens.slow
    readonly property int panelExitDuration: MotionTokens.medium
    readonly property int backdropExitDuration: MotionTokens.fast
    readonly property real backdropOpacity: backdropProgress * backdropTargetOpacity
    readonly property real panelProgress: progress
    signal closed

    visible: phase !== "closed"
    enabled: interactive

    function openFrom(source) {
        opener = source
        phase = "opening"
        motion.duration = panelEnterDuration
        motion.to = 1
        motion.restart()
        backdropMotion.duration = backdropEnterDuration
        backdropMotion.to = 1
        backdropMotion.restart()
        body.forceActiveFocus()
    }
    function closeAndRestoreFocus() {
        if (phase === "closed" || phase === "closing") return
        phase = "closing"
        motion.duration = panelExitDuration
        motion.to = 0
        motion.restart()
        backdropMotion.duration = backdropExitDuration
        backdropMotion.to = 0
        backdropMotion.restart()
    }

    Keys.onEscapePressed: event => { closeAndRestoreFocus(); event.accepted = true }

    Rectangle { anchors.fill: parent; color: "black"; opacity: root.backdropOpacity }
    Rectangle {
        id: body
        anchors.centerIn: parent
        width: 420
        height: 280
        radius: 14
        color: LazerTheme.popupBackground
        opacity: root.progress
        scale: MotionTokens.reducedMotion ? 1 : 0.985 + 0.015 * root.progress
        transform: Translate { y: MotionTokens.reducedMotion ? 0 : MotionTokens.overlayFromY * (1 - root.progress) }
        activeFocusOnTab: true
    }
    NumberAnimation {
        id: motion
        target: root
        property: "progress"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: MotionTokens.outSoft
        onFinished: {
            if (root.progress === 1) root.phase = "open"
            else {
                root.phase = "closed"
                if (root.opener) root.opener.forceActiveFocus()
                root.closed()
            }
        }
    }
    NumberAnimation {
        id: backdropMotion
        target: root
        property: "backdropProgress"
        easing.type: Easing.BezierSpline
        easing.bezierCurve: MotionTokens.outSoft
    }
}
