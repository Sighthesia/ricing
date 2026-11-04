import QtQuick
import QtQuick.Effects
import "../lazerbar"

// Straight header identity layer with settings rail, optional icon, title and summary.
Rectangle {
    id: root

    property string title
    property string iconSource
    // Monochrome module glyphs opt in to the scheme-aware barIcon tint;
    // colored intents (tray icons) leave this off.
    property bool tintIcon: false
    // Second line under the title. Contract: it carries what the panel BODY does
    // not already show. A widget whose content is the value itself (a slider
    // reading 80%, a card printing 80%) leaves this empty, otherwise the same
    // number appears twice within one small panel - the header says "Brightness
    // 80%" and the slider underneath says "Brightness 80%" again.
    property string summary
    property real hostWidth: 260
    property bool showClose: false
    // Foreground fade for replacement slides: icon, texts and close fade
    // while the rail background stays opaque.
    property real foregroundOpacity: 1
    // Announce an IN-PLACE change of the two lines. Off by default, because most
    // rails are set once per open and a flash on every repositioned summary would
    // be noise; the mod-key window hint turns both on, because its lines change
    // while the panel sits still - a held modifier plus a tapped key rewrites the
    // title under the user's eyes, and a cut there reads as a glitch.
    //
    // `animatedText` runs the shell's own text transition (`MarqueeLabel`'s scan:
    // the outgoing line falls character by character, the incoming one is revealed
    // left to right) rather than a second transition invented here.
    property bool animatedText: false
    // `changeFlash` washes the rail with the shared click-flash recipe so the
    // change is noticed from the corner of an eye that is not reading the text.
    property bool changeFlash: false
    signal closeRequested()

    implicitWidth: hostWidth
    implicitHeight: 48
    width: hostWidth
    height: 48
    color: LazerTheme.settingsRail
    clip: true
    radius: 0

    // The change wash. Declared before the row so it tints the rail UNDER the
    // icon and the two lines: the flash says "something changed here", and a
    // wash over the glyphs would instead read as the text itself flickering.
    //
    // Same recipe as every click flash in the shell - `textPrimary` at
    // `clickFlashOpacity`, falling to zero on `clickFlashDuration` with
    // `clickFlashEasing` - so the rail flashing when a shortcut changes and a
    // settings row flashing when it is clicked are visibly the same event.
    Rectangle {
        id: changeFlashSurface
        objectName: "identityChangeFlash"
        anchors.fill: parent
        color: LazerTheme.textPrimary
        opacity: 0
        enabled: false
        visible: opacity > 0.001
    }

    NumberAnimation {
        id: changeFlashRun
        target: changeFlashSurface
        property: "opacity"
        from: MotionTokens.clickFlashOpacity
        to: 0
        duration: MotionTokens.clickFlashDuration
        easing.type: MotionTokens.clickFlashEasing
    }

    // Left-aligned row: optional 16px icon plus title/summary column.
    Row {
        id: layoutRow
        opacity: root.foregroundOpacity
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 12
        anchors.rightMargin: root.showClose ? 52 : 12
        spacing: 8

        // Icon slot: 16px glyph plus its optional scheme-aware tint. The
        // wrapper keeps anchored effect children out of the Row — one
        // anchored child makes the whole positioner refuse to lay out,
        // which piled the texts on top of the icon.
        Item {
            id: iconSlot

            width: 16
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            visible: root.iconSource !== ""

            Image {
                id: iconImage
                objectName: "identityIcon"
                anchors.fill: parent
                source: root.iconSource
                asynchronous: true
                fillMode: Image.PreserveAspectFit
            }

            MultiEffect {
                anchors.fill: parent
                source: iconImage
                visible: iconSlot.visible && root.tintIcon
                colorization: 1
                colorizationColor: LazerTheme.barIcon

                Behavior on colorizationColor { ColorAnimation { duration: MotionTokens.fast } }
            }
        }

        Column {
            id: textColumn
            width: parent.width - (iconSlot.visible ? iconSlot.width + layoutRow.spacing : 0)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            // `MarqueeLabel` rather than `Text` because it is the shell's single
            // line-of-text contract: it grows with its content up to the cap,
            // scrolls past it instead of eliding, and - the reason it is here -
            // carries `transitionFrom`, the one text transition the shell has.
            // Under reduced motion it degrades to a statically elided line, which
            // is what a `Text` gave before.
            MarqueeLabel {
                id: titleText
                objectName: "identityTitle"
                maxWidth: Math.max(0, Math.round(parent.width))
                text: root.title
                textColor: LazerTheme.textPrimary
                pixelSize: 13
                bold: true
            }

            MarqueeLabel {
                id: summaryText
                objectName: "identitySummary"
                maxWidth: Math.max(0, Math.round(parent.width))
                text: root.summary
                textColor: LazerTheme.textMuted
                pixelSize: 10
                visible: root.summary !== ""
                opacity: visible ? 0.92 : 0
            }
        }
    }

    // The two lines as they were LAST SHOWN, so a change can be told from an
    // empty edge. `""` on either side is never announced: see `_announce`.
    property string _shownTitle: ""
    property string _shownSummary: ""

    function _flash() {
        if (!root.changeFlash || MotionTokens.reducedMotion)
            return
        changeFlashRun.stop()
        changeFlashSurface.opacity = MotionTokens.clickFlashOpacity
        changeFlashRun.restart()
    }

    // A change is announced only between two REAL answers. An empty side is the
    // rail being filled (the panel is opening) or emptied (the panel is closing),
    // and in both cases the panel's own reveal is already saying so: running the
    // text transition there made "Overview" fall away as you released mod, and
    // again on the way back in - the panel appeared to say the same word twice.
    function _announce(kind, previous, next, label) {
        if (previous === "" || next === "")
            return
        if (root.animatedText)
            label.transitionFrom(previous, next)
        root._flash()
    }

    onTitleChanged: {
        if (root._shownTitle === root.title)
            return
        const previous = root._shownTitle
        root._shownTitle = root.title
        root._announce("title", previous, root.title, titleText)
    }

    onSummaryChanged: {
        if (root._shownSummary === root.summary)
            return
        const previous = root._shownSummary
        root._shownSummary = root.summary
        root._announce("summary", previous, root.summary, summaryText)
    }

    // Persistent-menu close affordance pinned to the header's right edge.
    Rectangle {
        id: closeButton
        objectName: "identityCloseButton"
        width: 32
        height: 32
        opacity: root.foregroundOpacity
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        radius: 0
        visible: root.showClose
        enabled: root.showClose
        color: closeHover.hovered ? LazerTheme.hoverFill : "transparent"
        scale: closePress.pressed ? MotionTokens.pressScale : 1
        Behavior on scale {
            enabled: !MotionTokens.reducedMotion
            NumberAnimation { duration: MotionTokens.fast; easing.type: Easing.OutQuint }
        }
        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

        Text {
            anchors.centerIn: parent
            text: "✕"
            color: closeHover.hovered ? LazerTheme.textPrimary : LazerTheme.textMuted
            font.pixelSize: 14
            Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
        }

        HoverHandler { id: closeHover; blocking: false }
        TapHandler { id: closePress; gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: root.closeRequested() }
    }
}
