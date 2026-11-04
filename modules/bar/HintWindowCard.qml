import QtQuick
import "../lazerbar"

// One window row's card, in the active column: the plain surface, the focus tint as
// a child, the icon and the title, and the click flash.
//
// Extracted from `BarWindowHintStrip`'s delegate when the row grew a slot around it
// (`HintRow`), because the row and its animations are one component and the card
// inside it is the same card it always was. Nothing about how it looks or responds
// changed in the move.
Rectangle {
    id: root

    property var record: null
    property real glyphInset: 8
    property real glyphWidth: 16
    property bool interactive: true
    // Resolved by the owner against THIS item: the mask is a geometric function of
    // where the card is, and the frame's own rectangle lives up in the strip.
    property var maskFor: null
    property bool maskVisible: false

    signal activated(string windowId)

    readonly property alias rowFlashAnimation: rowFlash
    readonly property alias rowFlashOverlay: rowFlashOverlay

    radius: 6
    transformOrigin: Item.Center
    // The PLAIN surface. NO focus tint here, ever: the tint is the overlay below,
    // clipped to the frame, so a card the frame is only part way across is part way lit
    // rather than wholly lit - and a colour is a whole-surface property, so tinting this
    // rectangle cannot express that at all.
    color: rowHover.hovered
        ? LazerTheme.settingsCardHover : LazerTheme.settingsCard
    // A Rectangle borders itself by default; this row's own tint is its focus signal,
    // so that default is off - the outline that marks the focused row is the one shared
    // element, and it has its own border.
    border.width: 0
    scale: rowPress.pressed ? MotionTokens.pressScale : 1
    enabled: root.interactive

    // The focus tint: the part of this card the focus frame is over right now, and
    // nothing else.
    //
    // Declared FIRST so it paints above the card's own fill and below the icon and
    // title that follow it. That ordering is the entire reason it is an overlay rather
    // than a colour on the card - a colour on the card is the tint under the content,
    // which is right, but a colour is also a WHOLE-SURFACE property: the moment the
    // frame touched a card the entire card changed. That is a card switching state, not
    // a mark travelling across the list.
    Rectangle {
        id: focusMask
        objectName: "windowHintRowFocusMask"
        x: 0
        width: root.width
        y: root.maskFor ? root.maskFor(root).top : 0
        height: root.maskFor ? root.maskFor(root).height : 0
        color: LazerTheme.settingsSelected
        // The card's own radius, so at rest - the mask being the whole card - the two
        // are the same shape and the join is invisible.
        radius: 6
        // Zero height IS the answer for "the frame is not on this card", and saying it
        // with height rather than with `visible` keeps the geometry honest for anything
        // that measures it.
        visible: height > 0 && root.maskVisible
        // Inert to input. It is decoration lying over the card, and a surface that
        // swallowed taps meant for the window would be a fault the user only finds by
        // missing a click.
        enabled: false
    }

    Image {
        id: rowIcon
        objectName: "windowHintWindowIcon"
        x: root.glyphInset
        anchors.verticalCenter: parent.verticalCenter
        width: root.glyphWidth
        height: root.glyphWidth
        source: root.record ? root.record.icon : ""
        visible: source !== ""
        // Synchronous decode: the popup lives for the length of one key hold, so an
        // async icon would land too late to read.
        asynchronous: false
        fillMode: Image.PreserveAspectFit
        smooth: true
    }

    Text {
        objectName: "windowHintWindowTitle"
        anchors.left: rowIcon.visible ? rowIcon.right : parent.left
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.record ? root.record.title : ""
        color: root.record && root.record.isFocused
            ? LazerTheme.textPrimary : LazerTheme.barSubtitle
        font.pixelSize: 12
        font.bold: root.record && root.record.isFocused
        elide: Text.ElideRight
        maximumLineCount: 1

        Behavior on color {
            ColorAnimation { duration: MotionTokens.fast }
        }
    }

    // Click flash, inert to input so it cannot swallow the tap.
    Rectangle {
        id: rowFlashOverlay
        objectName: "windowHintRowFlash"
        anchors.fill: parent
        radius: 6
        color: LazerTheme.textPrimary
        opacity: 0
        enabled: false
    }

    NumberAnimation {
        id: rowFlash
        target: rowFlashOverlay
        property: "opacity"
        from: MotionTokens.clickFlashOpacity
        to: 0
        duration: MotionTokens.clickFlashDuration
        easing.type: MotionTokens.clickFlashEasing
    }

    HoverHandler { id: rowHover; blocking: false }
    TapHandler {
        id: rowPress
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: {
            if (MotionTokens.reducedMotion)
                rowFlashOverlay.opacity = 0
            else
                rowFlash.restart()
            root.activated(root.record ? root.record.windowId : "")
        }
    }

    // Behaviour on `color` is only ever about HOVER: the focus tint is the overlay
    // above, so no change to this item's colour can be caused by the frame.
    Behavior on color {
        ColorAnimation { duration: MotionTokens.fast }
    }
    Behavior on scale {
        enabled: !MotionTokens.reducedMotion
        NumberAnimation { duration: MotionTokens.fast
            easing.type: Easing.OutQuint }
    }
}
