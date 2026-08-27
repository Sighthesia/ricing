import QtQuick

// Fixed two-layer popup container with shared reveal and direction contracts.
// Keeps sidebar and content as sibling hosts driven by revealProgress.
Item {
    id: root
    clip: true

    enum Orientation { Horizontal, Vertical }
    enum Direction { Up, Down }
    readonly property int horizontal: 0
    readonly property int vertical: 1
    readonly property int up: 0
    readonly property int down: 1

    property int orientation: TwoLayerPopup.Orientation.Horizontal
    property int direction: TwoLayerPopup.Direction.Down
    property real revealProgress: 1
    property real sidebarOffset: 0
    property real contentOffset: 0
    property int contentDelay: MotionTokens.settingsContentDelay
    property real horizontalSidebarX: 0
    property real horizontalContentX: 0

    readonly property int revealDuration: MotionTokens.settingsSidebarFade + MotionTokens.settingsContentDelay
    readonly property real sidebarRevealProgress: MotionTokens.reducedMotion ? root.revealProgress : root.revealProgress
    readonly property real contentRevealProgress: MotionTokens.reducedMotion
        ? root.revealProgress
        : root.contentDelay <= 0
            ? root.revealProgress
            : Math.max(0, Math.min(1, (root.revealProgress - root.contentDelay / root.revealDuration)
                / (1 - root.contentDelay / root.revealDuration)))

    readonly property alias sidebarLayer: sidebarSlot
    readonly property alias contentLayer: contentSlot
    property alias sidebarData: sidebarSlot.data
    property alias contentData: contentSlot.data

    function beginReveal() {
        root.revealProgress = 1
    }

    function endReveal() {
        root.revealProgress = 0
    }

    // Sidebar host stays fixed while its offset and opacity follow reveal.
    Item {
        id: sidebarSlot
        width: childrenRect.width
        height: childrenRect.height
        x: root.orientation === root.horizontal ? root.horizontalSidebarX : 0
        y: {
            if (root.orientation !== root.vertical)
                return 0
            if (root.direction === root.down)
                return 0
            return contentSlot.height + 1
        }
        opacity: root.sidebarRevealProgress
        clip: false
        transform: Translate {
            x: root.orientation === root.horizontal ? root.sidebarOffset * (1 - root.sidebarRevealProgress) : 0
            y: root.orientation === root.vertical ? root.sidebarOffset * (1 - root.sidebarRevealProgress) : 0
        }
        Behavior on opacity {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.settingsSidebarFade; easing.type: Easing.OutQuint }
        }
    }

    // Content host follows with a delayed reveal and independent offset.
    Item {
        id: contentSlot
        width: childrenRect.width
        height: childrenRect.height
        x: root.orientation === root.horizontal ? root.horizontalContentX : 0
        y: {
            if (root.orientation !== root.vertical)
                return 0
            if (root.direction === root.down)
                return sidebarSlot.height + 1
            return 0
        }
        opacity: root.contentRevealProgress
        clip: false
        transform: Translate {
            x: root.orientation === root.horizontal ? root.contentOffset * (1 - root.contentRevealProgress) : 0
            y: root.orientation === root.vertical ? root.contentOffset * (1 - root.contentRevealProgress) : 0
        }
        Behavior on opacity {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.settingsSidebarFade; easing.type: Easing.OutQuint }
        }
    }
}
