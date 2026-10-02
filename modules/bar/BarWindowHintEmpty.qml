import QtQuick
import "../lazerbar"
import "./WindowHintMenuLogic.js" as HintLogic

// The placeholder a column shows when its workspace has no windows.
//
// A rectangle where a window row would be, not a line of text. The panel is a
// three-column frame, and a column with nothing in it used to be a hole in that
// frame - which reads as a layout fault rather than as the fact being reported.
// An outlined slot reads as what it is: a place a window could be, and there is
// none.
//
// Outlined rather than filled, deliberately. A filled card is what a real window
// row looks like, and a placeholder that imitates one would be a lie the user
// has to tap to discover. An outline cannot be mistaken for a control.
//
// The label names no workspace. A column carries no number, so its position in
// the panel is what says which workspace it belongs to.
Item {
    id: root

    // The same footprint as the row it stands in for, so the three columns stay
    // on one pitch whether or not any of them is empty.
    property real rowHeight: 28
    property real rowRadius: 6

    implicitWidth: 180
    implicitHeight: rowHeight
    width: implicitWidth
    height: rowHeight

    Rectangle {
        id: slot
        objectName: "windowHintEmptySlot"
        anchors.fill: parent
        radius: root.rowRadius
        color: "transparent"
        border.color: LazerTheme.divider
        // 1px on purpose: this is an outline marking an absence and the hairline
        // is the whole of it. A thicker or filled slot would read as a control.
        border.width: 1
        // Inert: an empty slot has nothing to focus, and it must never intercept
        // a tap meant for a row in another column.
        enabled: false
    }

    Text {
        objectName: "windowHintEmptySlotLabel"
        anchors.centerIn: parent
        width: parent.width - 16
        text: HintLogic.NEIGHBOUR_EMPTY_LABEL
        color: LazerTheme.textMuted
        font.pixelSize: 10
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        maximumLineCount: 1
    }
}