import QtQuick
import "textdiff.js" as TextDiff

// osu!lazer password mask: one capsule per character instead of Qt's native
// bullets. New characters grow in, deleted ones fall away; selection,
// clipboard, IME and scrolling stay with TextInput.
// Reference: osu.Game/Graphics/UserInterface/OsuPasswordTextBox.cs
TextInput {
    id: root

    // Revert switch: false hides every custom layer and restores the native
    // bullets, the native caret and the shared text colour.
    property bool osuMotion: true

    // Neither Wi-Fi host sets a font, so the default font.pixelSize is -1
    // ("use the application font"), which would zero the capsule geometry.
    // Pin a size the component derives everything from; hosts may override.
    font.pixelSize: 14

    readonly property real maskPixelSize: Math.max(8, Math.min(48, font.pixelSize > 0 ? font.pixelSize : 14))

    // osu! PasswordMaskChar geometry: a cell is FontSize/2 wide and one
    // FontSize tall, and the capsule fills 40% x 80% of that cell.
    readonly property real maskCellWidth: maskPixelSize * 0.5
    readonly property real capsuleWidth: maskPixelSize * 0.4
    readonly property real capsuleHeight: maskPixelSize * 0.8
    // Entry is FadeIn/ResizeTo over 500ms OutQuint; a removal drops one cell
    // height over 200ms InQuad while fading out linearly.
    readonly property int maskGrowTime: 500
    readonly property int maskFallTime: 200
    readonly property real maskFallDistance: maskPixelSize

    // Previous string, so a text change can be narrowed down to the run that
    // was removed and to where it used to sit.
    property string trackedText: ""

    // Password semantics and every native editing behaviour stay with Qt; only
    // the glyphs (and the caret) are drawn here.
    echoMode: TextInput.Password

    // The mask layer is the only visible glyph source, so the native text is
    // hidden; the selection highlight stays and reads at half strength behind
    // the capsules.
    color: root.osuMotion ? "transparent" : LazerTheme.textPrimary
    // Selected bullets must stay invisible too, or the mask glyphs reappear
    // under the selection highlight.
    selectedTextColor: root.osuMotion ? "transparent" : LazerTheme.textPrimary
    selectionColor: root.osuMotion
        ? Qt.rgba(LazerTheme.settingsAccent.r, LazerTheme.settingsAccent.g,
                  LazerTheme.settingsAccent.b, 0.5)
        : LazerTheme.settingsAccent

    // Empty delegate swallows the native caret; OsuTextCaret draws the real
    // one, and null hands the native caret back on the revert path.
    cursorDelegate: root.osuMotion ? emptyCursor : null

    // The osu caret contract shares geometry with a TextInput, so it only
    // needs the target; it is unmounted with the custom mask layer.
    Loader {
        id: caretLoader
        active: root.osuMotion
        z: 4
        sourceComponent: OsuTextCaret { target: root }
    }

    // One capsule per character, positioned from the editor's own caret
    // geometry so scrolling and selection keep the masks over the real text.
    Repeater {
        model: root.osuMotion ? root.text.length : 0

        delegate: Rectangle {
            id: capsule

            // Grows on entry. It also makes the geometry binding re-run after
            // Qt has laid the new character out, so a fresh capsule never
            // paints at a stale x.
            property bool grown: false

            // Reading length, cursor, width and font registers the dependencies
            // Qt cannot infer from positionToRectangle alone.
            readonly property rect caretRect: {
                root.text.length
                root.cursorPosition
                root.width
                root.maskPixelSize
                capsule.grown
                return root.positionToRectangle(index)
            }

            // Qt reports a 1px caret line unless overwrite mode supplies a real
            // advance, so the osu cell width is what centres the capsule.
            readonly property real cellAdvance: caretRect.width > 1
                ? caretRect.width : root.maskCellWidth

            width: root.capsuleWidth
            height: capsule.grown ? root.capsuleHeight : 0
            radius: width / 2
            color: LazerTheme.textPrimary
            opacity: capsule.grown ? 1 : 0

            x: caretRect.x + cellAdvance / 2 - width / 2
            y: caretRect.y
               + (caretRect.height > 0 ? caretRect.height : root.height) / 2
               - height / 2

            Behavior on height {
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: root.maskGrowTime; easing.type: Easing.OutQuint }
            }

            Behavior on opacity {
                enabled: !MotionTokens.reducedMotion
                NumberAnimation { duration: root.maskGrowTime; easing.type: Easing.OutQuint }
            }

            Component.onCompleted: {
                if (MotionTokens.reducedMotion)
                    capsule.grown = true
                else
                    Qt.callLater(function() { capsule.grown = true })
            }
        }
    }

    // Falling deletions live inside the field so its clip cuts them the way
    // osu's TextBox mask does. They are siblings of the capsule repeater, never
    // its children, so a delegate can be destroyed while its ghost still falls.
    Item {
        id: ghostLayer
        anchors.fill: parent
        enabled: false
        z: 3
    }

    // One removed capsule: drops a full cell height while dissolving away.
    Component {
        id: fallGhost

        Rectangle {
            id: ghost

            property real fallDistance: 0

            radius: width / 2
            color: LazerTheme.textPrimary
            opacity: 1

            Behavior on y {
                NumberAnimation { duration: root.maskFallTime; easing.type: Easing.InQuad }
            }

            Behavior on opacity {
                NumberAnimation { duration: root.maskFallTime }
            }

            Component.onCompleted: Qt.callLater(function() {
                ghost.y += ghost.fallDistance
                ghost.opacity = 0
            })

            Timer {
                interval: root.maskFallTime + 8
                running: true
                onTriggered: ghost.destroy()
            }
        }
    }

    // Empty delegate the native caret is swapped for while the osu caret runs.
    Component {
        id: emptyCursor

        Item { }
    }

    Component.onCompleted: root.trackedText = root.text

    onTextChanged: {
        if (root.osuMotion)
            spawnFallMasks(root.trackedText, root.text)
        root.trackedText = root.text
    }

    // Replays every removed character as its own falling capsule. Qt does not
    // expose the per-character advance of masked text, so the osu cell width
    // stands in for it.
    function spawnFallMasks(oldText, newText) {
        if (MotionTokens.reducedMotion)
            return

        var range = TextDiff.removeRange(oldText, newText)
        if (!range)
            return

        var start = Math.min(range.start, root.text.length)
        var anchor = root.positionToRectangle(start)
        var cellWidth = anchor.width > 1 ? anchor.width : root.maskCellWidth
        var cellHeight = anchor.height > 0 ? anchor.height : root.height
        var baseX = anchor.x + cellWidth / 2 - root.capsuleWidth / 2
        var baseY = anchor.y + cellHeight / 2 - root.capsuleHeight / 2

        for (var i = 0; i < range.removed.length; i++) {
            fallGhost.createObject(ghostLayer, {
                width: root.capsuleWidth,
                height: root.capsuleHeight,
                x: baseX + i * cellWidth,
                y: baseY,
                fallDistance: root.maskFallDistance
            })
        }
    }
}
