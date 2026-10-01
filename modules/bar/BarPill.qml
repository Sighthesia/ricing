import QtQuick
import "../lazerbar"

// Hover-reactive sharp pill surface shared by every bar widget.
Item {
    id: root

    property bool hoverable: true
    property color hoverColor: LazerTheme.hoverFill
    readonly property bool hovered: visible && enabled && hoverable && hoverHandler.hovered
    signal clicked
    signal rightClicked
    signal middleClicked

    // Opt-in hover intent publication for two-layer popup.
    property bool hoverIntentEnabled: false
    signal popupRequested(var intent)
    signal popupCloseRequested()
    signal popupAnchorUpdate(var intent)

    // Where the bar window sits on its output. The layout injects it because
    // `mapToGlobal` is per-window: a bar on a second monitor, or a floating bar
    // inset by its margin, would otherwise publish window-local coordinates as
    // if they were screen ones, and the shared ring would start in the wrong
    // place on every other surface.
    property real glowScreenX: 0
    property real glowScreenY: 0

    // This widget's centre in screen coordinates, which is where the shell's
    // glow ring starts.
    //
    // A function, not a binding: `mapToGlobal` is a call, so a binding over it
    // would not depend on this item's *position* at all and would keep the
    // value it happened to compute on the first evaluation — usually before
    // the layout settled, i.e. the middle of the bar, forever. Reading it at
    // trigger time is the only way to be sure.
    function barGlowOrigin() {
        try {
            var point = root.mapToGlobal(root.width / 2, root.height / 2)
            if (isFinite(point.x) && isFinite(point.y))
                return { x: root.glowScreenX + Number(point.x),
                         y: root.glowScreenY + Number(point.y) }
        } catch (e) {}
        return null
    }

    implicitHeight: LazerTheme.barWidgetHeight

    // Paint the sharp interactive surface without rounding the pill body.
    Rectangle {
        anchors.fill: parent
        radius: 0
        color: root.hovered ? root.hoverColor : "transparent"

        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }

    HoverHandler {
        id: hoverHandler
        objectName: "pillHoverHandler"
        enabled: root.hoverable
    }

    // Left click is the primary activation path for every pill.
    TapHandler {
        objectName: "pillPrimaryTapHandler"
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.clicked()
    }

    // Side buttons stay opt-in: pills without listeners simply ignore them.
    TapHandler {
        acceptedButtons: Qt.RightButton | Qt.MiddleButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: (eventPoint, button) => {
            if (button === Qt.RightButton) root.rightClicked()
            else root.middleClicked()
        }
    }
}
