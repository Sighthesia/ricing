import QtQuick
import "../lazerbar"

// The panel's master level row: one 38px card carrying the glyph, the label, the
// level slider, the percentage and the mute toggle.
//
// It replaces the settings-panel volume card this panel used to open with. That
// card was two stacked settings rows - 112px of panel for a single value -
// sitting directly above 34px device rows, so the top of the panel read at a
// different scale from everything under it. One row system for the whole panel
// is what makes it legible; the slider is still the shared settings slider, only
// the frame around it changed.
//
// Geometry is fixed from both ends rather than measured: the label gets a
// reserved column, the value and mute are pinned to the right edge, and the
// slider fills whatever is left. Deriving the slider's left edge from the
// label's measured width instead made the two depend on each other.
Item {
    id: root

    property string label: ""
    property string glyph: ""
    property real value: 0.5
    property bool muted: false
    property bool showMute: true

    signal valueCommitted(real value)
    signal toggleRequested()

    readonly property real clampedValue: Math.max(0, Math.min(1, Number(root.value) || 0))
    readonly property real cardPadding: 8
    readonly property real glyphSize: 14
    // Text column, shared with the device and mixer rows so every label in the
    // panel starts on the same vertical line.
    readonly property real textLeft: cardPadding + glyphSize + 4
    // Reserved label column. Long labels elide rather than push the slider, so
    // the level control never moves because a device is named at length.
    readonly property real labelColumn: 66
    readonly property real muteSize: 20
    readonly property real valueWidth: 30

    implicitWidth: 320
    implicitHeight: 38
    height: implicitHeight

    // Shared card surface with the device and mixer rows, so the panel reads as
    // one row system rather than a settings panel with some list rows under it.
    Rectangle {
        id: card
        objectName: "levelRowCard"
        anchors.fill: parent
        radius: 6
        color: cardHover.hovered ? LazerTheme.settingsCardHover : LazerTheme.settingsCard

        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }

    HoverHandler { id: cardHover }

    // Level glyph. Scheme-aware through BarIcon's ColorOverlay, like every other
    // glyph in the shell.
    BarIcon {
        id: levelGlyph
        objectName: "levelRowGlyph"
        x: root.cardPadding
        anchors.verticalCenter: parent.verticalCenter
        width: root.glyphSize
        height: root.glyphSize
        visible: root.glyph !== ""
        source: root.glyph
        tint: root.muted ? LazerTheme.textMuted : LazerTheme.textPrimary
        opacity: root.muted ? 0.55 : 0.9

        Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
    }

    Text {
        objectName: "levelRowLabel"
        x: root.textLeft
        anchors.verticalCenter: parent.verticalCenter
        width: root.labelColumn
        text: root.label
        color: LazerTheme.textPrimary
        font.pixelSize: 11
        font.bold: true
        elide: Text.ElideRight
    }

    // Percentage, pinned to the right of the control cluster; the slider fills
    // between the label column and it.
    Text {
        id: levelValue
        objectName: "levelRowValue"
        anchors.right: muteButton.left
        anchors.rightMargin: root.showMute ? 8 : root.cardPadding
        anchors.verticalCenter: parent.verticalCenter
        width: root.valueWidth
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.clampedValue * 100) + "%"
        color: root.muted ? LazerTheme.textMuted : LazerTheme.textPrimary
        font.pixelSize: 11

        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
    }

    LazerSettingsSlider {
        id: levelSlider
        objectName: "levelRowSlider"
        x: root.textLeft + root.labelColumn + 10
        anchors.verticalCenter: parent.verticalCenter
        // The settings slider's own width binding falls back to its 220px
        // implicit width, so an explicit width here is what actually sizes it.
        width: Math.max(60, levelValue.x - levelSlider.x - 8)
        height: 22
        from: 0
        to: 100
        stepSize: 1
        suffix: "%"
        accessibleName: root.label
        value: Math.round(root.clampedValue * 100)
        onValueModified: function (next) {
            root.valueCommitted(Math.max(0, Math.min(1, Number(next) / 100)))
        }
    }

    // Mute as a glyph button rather than a row of its own. A full-width card
    // whose only content was a toggle on the far right spent a quarter of the
    // panel on nothing and gave the panel a second control shape competing with
    // the slider beside it.
    Rectangle {
        id: muteButton
        objectName: "levelRowMute"
        anchors.right: parent.right
        anchors.rightMargin: root.cardPadding
        anchors.verticalCenter: parent.verticalCenter
        width: root.muteSize
        height: root.muteSize
        radius: 4
        visible: root.showMute
        color: muteHover.hovered ? LazerTheme.settingsMenuHover : "transparent"

        Behavior on color { ColorAnimation { duration: MotionTokens.fast } }

        BarIcon {
            anchors.centerIn: parent
            width: root.glyphSize
            height: root.glyphSize
            source: Qt.resolvedUrl("icons/" + (root.muted ? "volume-muted.svg" : "volume.svg"))
            tint: root.muted ? LazerTheme.settingsAccent : LazerTheme.textMuted
        }

        function toggle() { root.toggleRequested() }

        HoverHandler { id: muteHover }
        TapHandler { objectName: "levelRowMuteTap"; onTapped: muteButton.toggle() }
    }
}