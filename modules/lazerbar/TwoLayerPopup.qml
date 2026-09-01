import QtQuick

// Fixed two-layer popup container with shared reveal and direction contracts.
// Keeps sidebar and content as sibling hosts driven by revealProgress.
Item {
    id: root
    // Horizontal settings layers travel outside the owner; callers with an
    // external reveal owner can opt out of the vertical self-clip.
    property bool clipVertical: true
    clip: root.clipVertical && root.orientation === root.vertical

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
    // Host sets this from its lifecycle so exit motion is not delayed twice.
    property bool opening: true
    property real horizontalSidebarX: 0
    property real horizontalContentX: 0
    // Settings owns horizontal layer opacity; vertical popups use the shared fade.
    property bool animateLayerOpacity: true

    // Stable stacking heights to avoid mid-reveal jumps when content switches.
    // Updated only when the popup is settled (near 0/1); during flight the
    // previous heights are held so the second layer does not teleport.
    property real stableSidebarHeight: 0
    property real stableContentHeight: 0

    function syncStableHeights() {
        if (root.revealProgress < 0.01 || root.revealProgress > 0.99) {
            if (sidebarSlot.height > 0)
                stableSidebarHeight = sidebarSlot.height
            if (contentSlot.height > 0)
                stableContentHeight = contentSlot.height
        }
    }

    onRevealProgressChanged: syncStableHeights()
    Component.onCompleted: syncStableHeights()

    readonly property int revealDuration: MotionTokens.settingsSidebarFade + MotionTokens.settingsContentDelay
    readonly property bool interactable: root.revealProgress > 0.99
    readonly property real sidebarRevealProgress: root.revealProgress
    readonly property real contentRevealProgress: MotionTokens.reducedMotion || !root.opening
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
        z: 1
        width: childrenRect.width
        height: childrenRect.height
        x: root.orientation === root.horizontal ? root.horizontalSidebarX : 0
        y: {
            if (root.orientation !== root.vertical)
                return 0
            if (root.direction === root.down)
                return 0
            var h = (root.revealProgress > 0.01 && root.revealProgress < 0.99 && root.stableContentHeight > 0)
                ? root.stableContentHeight : contentSlot.height
            return h + 1
        }
        onHeightChanged: root.syncStableHeights()
        opacity: root.animateLayerOpacity ? root.sidebarRevealProgress : 1
        clip: false
        transform: Translate {
            x: root.orientation === root.horizontal ? root.sidebarOffset * (1 - root.sidebarRevealProgress) : 0
            y: root.orientation === root.vertical ? root.sidebarOffset * (1 - root.sidebarRevealProgress) : 0
        }
        Behavior on opacity {
            enabled: root.animateLayerOpacity && !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.settingsSidebarFade; easing.type: Easing.OutQuint }
        }
    }

    // Content host follows with a delayed reveal and independent offset.
    Item {
        id: contentSlot
        z: 0
        width: childrenRect.width
        height: childrenRect.height
        x: root.orientation === root.horizontal ? root.horizontalContentX : 0
        y: {
            if (root.orientation !== root.vertical)
                return 0
            if (root.direction === root.down) {
                var sh = (root.revealProgress > 0.01 && root.revealProgress < 0.99 && root.stableSidebarHeight > 0)
                    ? root.stableSidebarHeight : sidebarSlot.height
                return sh + 1
            }
            return 0
        }
        onHeightChanged: root.syncStableHeights()
        opacity: root.animateLayerOpacity ? root.contentRevealProgress : 1
        clip: false
        transform: Translate {
            x: root.orientation === root.horizontal ? root.contentOffset * (1 - root.contentRevealProgress) : 0
            y: root.orientation === root.vertical ? root.contentOffset * (1 - root.contentRevealProgress) : 0
        }
        Behavior on opacity {
            enabled: root.animateLayerOpacity && !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.settingsSidebarFade; easing.type: Easing.OutQuint }
        }
    }
}
