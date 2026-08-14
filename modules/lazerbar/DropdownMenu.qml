import QtQuick
import "LazerBarLogic.js" as Logic

// Animate one anchored, single-level menu through a guarded lifecycle.
Item {
    id: root
    property var model: []
    property string phase: "closed"
    property int currentIndex: 0
    property bool interactive: phase === "opening" || phase === "open"
    property string originName: "topLeft"
    property Item opener: null
    readonly property real openFromScale: MotionTokens.popupFromScale
    readonly property real openFromY: MotionTokens.popupFromY
    readonly property int openDuration: MotionTokens.medium
    readonly property int closeDuration: MotionTokens.fast
    property real progress: 0
    signal triggered(int index, var entry)
    signal closed

    implicitWidth: 236
    implicitHeight: menuColumn.implicitHeight + 16
    visible: phase !== "closed"
    opacity: progress
    enabled: interactive
    transformOrigin: originName === "topRight" ? Item.TopRight : Item.TopLeft
    scale: MotionTokens.reducedMotion ? 1 : openFromScale + (1 - openFromScale) * progress
    y: MotionTokens.reducedMotion ? 0 : openFromY * (1 - progress)

    function openAt(anchorItem, screenWidth) {
        opener = anchorItem
        originName = Logic.popupOrigin(anchorItem ? anchorItem.x + anchorItem.width / 2 : 0,
                                       implicitWidth, screenWidth || 1920)
        phase = "opening"
        progressAnimation.duration = openDuration
        progressAnimation.to = 1
        progressAnimation.restart()
        forceActiveFocus()
    }
    function closeAndRestoreFocus() {
        if (phase === "closed" || phase === "closing") return
        phase = "closing"
        progressAnimation.duration = closeDuration
        progressAnimation.to = 0
        progressAnimation.restart()
    }
    function moveCurrent(delta) {
        if (!model || model.length === 0) return
        currentIndex = (currentIndex + delta + model.length) % model.length
    }

    Keys.onUpPressed: event => { moveCurrent(-1); event.accepted = true }
    Keys.onDownPressed: event => { moveCurrent(1); event.accepted = true }
    Keys.onEscapePressed: event => { closeAndRestoreFocus(); event.accepted = true }
    Keys.onReturnPressed: event => { if (model.length) triggered(currentIndex, model[currentIndex]); event.accepted = true }
    Keys.onEnterPressed: event => { if (model.length) triggered(currentIndex, model[currentIndex]); event.accepted = true }

    NumberAnimation {
        id: progressAnimation
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

    // Paint and populate the floating menu surface.
    Rectangle {
        anchors.fill: parent
        radius: 10
        color: LazerTheme.popupBackground
        border.width: 1
        border.color: LazerTheme.popupBorder
        Column {
            id: menuColumn
            anchors.fill: parent
            anchors.margins: 8
            Repeater {
                model: root.model
                delegate: MenuItem {
                    required property int index
                    required property var modelData
                    width: menuColumn.width
                    label: modelData.label || ""
                    shortcut: modelData.shortcut || ""
                    current: root.currentIndex === index
                    onTriggered: root.triggered(index, modelData)
                }
            }
        }
    }
}
