import QtQuick
import "../lazerbar"

// Single-line label that grows with its natural width up to a cap, then
// marquee-scrolls instead of eliding. Natural width comes from TextMetrics,
// never from the label's own implicitWidth, so a clipping/elide state can
// never feed back into the measurement (the cause of collapsed-width bugs).
// Under reduced motion it degrades to a statically elided line.
Item {
    id: root

    property string text: ""
    // Width cap where growth stops and marquee scrolling takes over.
    property int maxWidth: 300
    property color textColor
    property int pixelSize: 12
    property bool bold: false
    readonly property bool overflowing: metrics.advanceWidth > root.maxWidth
    // Exposed for entrance/ghost choreography that needs the raw label or
    // the clipping slot (e.g. per-character fade-ins sharing this origin).
    property alias label: label
    property alias slot: clipSlot
    // Unclipped overlay above the label, for effects that must escape the
    // clip window (e.g. exit ghosts falling past the surface).
    property alias overlay: overlayLayer

    implicitWidth: Math.min(metrics.advanceWidth, root.maxWidth)
    implicitHeight: metrics.height

    // Clipping window; the full-width label slides inside it while scrolling.
    Item {
        id: clipSlot

        anchors.fill: parent
        clip: true

        Text {
            id: label

            text: root.text
            color: root.textColor
            font.pixelSize: root.pixelSize
            font.bold: root.bold
            // Reduced motion keeps a static ellipsis; otherwise the label
            // always renders at full natural width and scrolls instead.
            width: MotionTokens.reducedMotion ? Math.min(metrics.advanceWidth, root.maxWidth) : metrics.advanceWidth
            elide: MotionTokens.reducedMotion ? Text.ElideRight : Text.ElideNone
        }
    }

    Item {
        id: overlayLayer

        anchors.fill: parent
        clip: false
    }

    // Independent measuring context — unaffected by the label's live layout.
    TextMetrics {
        id: metrics

        font: label.font
        text: root.text
    }

    // Marquee is sync-driven: every input change (text, reveal opacity, slot
    // width) resets x to 0 and restarts against current geometry, so a shorter
    // title can never leave the label parked outside the clip window and a
    // mid-morph slot width can never leave stale from/to offsets.
    function syncScroll() {
        var shouldRun = root.overflowing && !MotionTokens.reducedMotion
            && label.opacity >= 0.99 && clipSlot.width > 0
        scroll.stop()
        label.x = 0
        if (shouldRun)
            scroll.restart()
    }

    Component.onCompleted: syncScroll()
    onTextChanged: syncScroll()

    Connections {
        target: label
        function onOpacityChanged() { root.syncScroll() }
    }

    // Slot width changes per frame during the host pill's width morph; only
    // resync once it settles so the scroll is not perpetually restarted.
    Timer {
        id: slotWidthSettle

        interval: 240
        onTriggered: root.syncScroll()
    }

    Connections {
        target: clipSlot
        function onWidthChanged() {
            if (root.overflowing && !MotionTokens.reducedMotion)
                slotWidthSettle.restart()
        }
    }

    SequentialAnimation {
        id: scroll

        loops: Animation.Infinite

        PauseAnimation { duration: 1400 }
        NumberAnimation {
            target: label
            property: "x"
            from: 0
            to: -(metrics.advanceWidth - clipSlot.width)
            duration: Math.max(2000, (metrics.advanceWidth - clipSlot.width) * 18)
            easing.type: Easing.Linear
        }
        PauseAnimation { duration: 1400 }
        NumberAnimation {
            target: label
            property: "x"
            from: -(metrics.advanceWidth - clipSlot.width)
            to: 0
            duration: Math.max(2000, (metrics.advanceWidth - clipSlot.width) * 18)
            easing.type: Easing.Linear
        }
    }
}
