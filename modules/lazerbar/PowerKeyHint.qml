import QtQuick

// One shortcut legend for a full-screen prompt: the key or keys drawn as keycaps,
// then the word for what they do.
//
// A keycap block is a component surface with detail-level rounding — a small
// control, not a panel — and it reads as a key because of its shape rather than
// because the sentence around it says "press". A prose line made the reader hunt
// for the key inside it.
Row {
    id: root

    // Keycap labels, in press order. Empty drops the block row entirely.
    property var keys: []
    // What the key does; read as a caption beside the blocks.
    property string caption: ""

    spacing: 6

    Row {
        spacing: 4

        Repeater {
            model: root.keys

            Rectangle {
                id: cap

                required property var modelData

                readonly property int labelHeight: 22

                height: labelHeight
                width: Math.max(26, labelText.implicitWidth + 14)
                radius: 4
                color: LazerTheme.settingsControlSurface
                border.width: 1
                border.color: LazerTheme.divider

                Text {
                    id: labelText
                    anchors.centerIn: parent
                    text: String(cap.modelData)
                    color: LazerTheme.textPrimary
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    Text {
        visible: root.caption.length > 0
        height: 22
        verticalAlignment: Text.AlignVCenter
        text: root.caption
        color: LazerTheme.textMuted
        font.pixelSize: 12
    }
}
