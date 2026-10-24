import QtQuick
import "../../services" as Services

// Tail of the launcher list: the region that has not arrived yet. Shown only
// while a refresh is still streaming batches, sitting where the next row
// will land so the list reads as "growing downward" instead of "finished
// and empty".
//
// Carries the shared osu loading ring rather than a spinner of its own: the
// same ring the launcher shows for its full loading state, at a calmer size
// for what is a background tail rather than a blocked surface.
Item {
    id: root

    // Stream state comes from the session: false leaves the row collapsed so
    // it costs no space in the finished list.
    property bool loadingMore: false

    readonly property int rowHeight: 56
    width: parent ? parent.width : 0
    height: visible ? rowHeight : 0
    // Stay rendered until the fade has landed, so the ring does not vanish
    // mid-decay when the last batch arrives.
    visible: root.loadingMore || opacity > 0.01
    opacity: root.loadingMore ? 1 : 0

    Behavior on opacity {
        enabled: !MotionTokens.reducedMotion
        NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
    }

    LazerLoadingRing {
        id: ring
        objectName: "launcherLoadingMoreRing"
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        // The footer owns the fade, so the ring only follows the spin: two
        // opacity ramps on top of each other would read as a stutter.
        active: true
        running: root.loadingMore
    }

    Text {
        anchors.left: ring.right
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: Services.Tr.q("launcher.loadingMore")
        color: LazerTheme.textMuted
        font.pixelSize: 11
    }
}