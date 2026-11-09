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

    // The frame's slice of THIS label, computed by the strip - which is where both
    // halves of the intersection live, so that a neighbour card and an active card
    // are lit by the same arithmetic and cannot drift apart.
    //
    // A neighbour needed this for as long as the active column has. The frame spends
    // the first half of every journey on the card being LEFT, which lives in a
    // departing column, and a label with no mask left that whole half dark: the
    // highlight appeared to jump straight across to the column being moved to while
    // the frame was still visibly sliding off the old card. Measured across a 2-to-3
    // switch, the frame's x ran 205 -> 131 over the departure leg - exactly the label's
    // own x - and nothing there lit at any point in those 170ms.
    property real focusMaskTop: 0
    property real focusMaskHeight: 0
    property bool focusMaskVisible: false

    implicitWidth: 180
    implicitHeight: rowHeight
    width: implicitWidth
    height: rowHeight

    // The row's own surface, in the same place in the paint order as the active
    // card's. A neighbour column has to read as the same LIST as the active one -
    // same 28px rows on the same 34px pitch - and a row with no surface read as a
    // thinner, denser line than the card beside it. It is the active card's tone at
    // reduced presence rather than a different surface: a neighbour is context for
    // the workspace you are on, which is what keeps it muted.
    Rectangle {
        anchors.fill: parent
        radius: 6
        color: LazerTheme.settingsCard
        opacity: rowHover.hovered ? 0.72 : 0.4
        Behavior on opacity {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
        }
    }

    // The focus tint, in the same place in the paint order as the active row's: above
    // this row's own surface and below the glyph and title that follow, so the text
    // is never veiled. Same colour and radius, because it is the same mark: the focus
    // frame's own rectangle, clipped to this card, and identical in shape to the
    // frame's border it sits inside.
    Rectangle {
        objectName: "windowHintLabelFocusMask"
        x: 0
        width: parent.width
        y: root.focusMaskTop
        height: root.focusMaskHeight
        visible: height > 0 && root.focusMaskVisible
        color: LazerTheme.settingsSelected
        radius: 6
    }

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

    // A generous hit area: the surface is a wash rather than a control, so the
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
        font.pixelSize: 12
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
