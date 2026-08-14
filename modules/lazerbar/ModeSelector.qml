import QtQuick

// Keep four game modes and one continuous active indicator together.
Item {
    id: root

    property string selectedMode: "osu"
    readonly property int selectedIndex: modeIds.indexOf(selectedMode)
    readonly property var modeIds: ["osu", "taiko", "catch", "mania"]
    property url osuSource
    property url taikoSource
    property url catchSource
    property url maniaSource
    property alias indicatorItem: indicator
    readonly property real indicatorTargetX: slotX(selectedIndex) + (LazerTheme.targetSize - indicator.width) / 2
    readonly property real indicatorX: indicator.x
    signal modeSelected(string mode)

    implicitWidth: row.implicitWidth
    implicitHeight: LazerTheme.targetSize + 4
    activeFocusOnTab: true

    function slotX(index) { return index * (LazerTheme.targetSize + LazerTheme.inlineGap) }
    function activateIndex(index) {
        var normalized = (index + modeIds.length) % modeIds.length
        selectedMode = modeIds[normalized]
        modeSelected(selectedMode)
    }
    function moveSelection(delta) { activateIndex(selectedIndex + delta) }

    Keys.onLeftPressed: event => { moveSelection(-1); event.accepted = true }
    Keys.onRightPressed: event => { moveSelection(1); event.accepted = true }

    Row {
        id: row
        spacing: LazerTheme.inlineGap

        Repeater {
            model: root.modeIds
            delegate: IconButton {
                required property int index
                required property string modelData
                source: [root.osuSource, root.taikoSource, root.catchSource, root.maniaSource][index]
                accessibleName: modelData
                active: root.selectedIndex === index
                onClicked: root.activateIndex(index)
                KeyNavigation.left: index > 0 ? row.children[index - 1] : null
                KeyNavigation.right: index < 3 ? row.children[index + 1] : null
            }
        }
    }

    // Slide one persistent mark beneath the selected mode.
    Rectangle {
        id: indicator
        y: LazerTheme.targetSize + 1
        x: root.indicatorTargetX
        width: 12
        height: 2
        radius: 1
        color: "white"

        Behavior on x {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.medium; easing.type: Easing.BezierSpline; easing.bezierCurve: MotionTokens.outStd }
        }
    }
}
