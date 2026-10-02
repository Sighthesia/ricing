import QtQuick
import "../lazerbar"

// One window label in a NEIGHBOUR column - the workspace either side of the
// active one.
//
// Deliberately plainer than the active column's row: no card fill, no focus
// highlight, no indicator, a muted title. The active column is the only one that
// carries state, so the other two read as context for it rather than as three
// equal lists. Tapping a label still focuses that window, which is what makes
// the neighbours worth showing at all - niri moves the view to its workspace.
Item {
    id: root

    required property var modelData
    required property int index

    // Geometry comes from the owner so the two copies of a strip mid-slide are
    // laid out identically and cannot drift apart by a pixel.
    property real rowHeight: 28
    property real glyphInset: 8
    property real glyphWidth: 16

    signal activated(string windowId)

    implicitWidth: 180
    implicitHeight: rowHeight
    width: implicitWidth
    height: rowHeight

    // App icon, the same size and inset as the active column's.
    Image {
        id: rowIcon
        x: root.glyphInset
        anchors.verticalCenter: parent.verticalCenter
        width: root.glyphWidth
        height: root.glyphWidth
        source: root.modelData ? root.modelData.icon : ""
        visible: source !== ""
        asynchronous: false
        fillMode: Image.PreserveAspectFit
        smooth: true
        // A neighbour is not the current window, so its icon sits back a step -
        // and lifts to full on hover, the only feedback this label has.
        opacity: rowHover.hovered ? 1 : 0.55
        Behavior on opacity {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
        }
    }

    // A generous hit area: a neighbour label has no card behind it, so the
    // pointer needs the whole row rather than the text's own extent.
    Text {
        id: rowTitle
        anchors.left: rowIcon.visible ? rowIcon.right : parent.left
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: root.modelData ? root.modelData.title : ""
        color: rowHover.hovered ? LazerTheme.textPrimary : LazerTheme.textMuted
        font.pixelSize: 11
        elide: Text.ElideRight
        maximumLineCount: 1

        Behavior on color {
            enabled: !MotionTokens.reducedMotion
            ColorAnimation { duration: MotionTokens.fast }
        }
    }

    // Hover response: the row has no surface, so the feedback is the title and
    // the icon lifting to the active column's treatment. `Behavior` rather than
    // a `State` + `Transition` pair - the shared recipe on the active row is a
    // Behaviour per property, and this row answers the same hover the same way.
    HoverHandler { id: rowHover; blocking: false }
    TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: root.activated(root.modelData ? root.modelData.windowId : "")
    }
}
