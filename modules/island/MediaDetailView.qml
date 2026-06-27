import QtQuick
import "../../services" as Services

// Media detail page for the shared island surface.
// Lists every live MPRIS player as a MediaPlayerCard; selecting a card
// locks it as the active media source for the bar and compact rendering.
// When no players are active, shows a placeholder prompt.
Item {
    id: root

    readonly property var players: Services.MediaService.playerList
    readonly property int playerCount: Services.MediaService.playerCount
    readonly property string activePlayerKey: Services.MediaService.hasPlayer
        ? (Services.MediaService.activePlayer.identity || Services.MediaService.activePlayer.desktopEntry || "")
        : ""

    // Empty-state placeholder when no player is connected.
    Column {
        id: emptyState

        anchors.centerIn: parent
        visible: root.playerCount === 0
        spacing: 8

        Services.FluidText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "\u266A"
            color: Services.Color.mPrimary
            basePixelSize: 32
            opacity: 0.6
        }

        Services.FluidText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "\u6682\u65E0\u5A92\u4F53"
            color: Services.Color.mOnSurface
            basePixelSize: 16
            font.bold: true
        }

        Services.FluidText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "\u7B49\u5F85\u64AD\u653E\u5668\u8FDE\u63A5"
            color: Services.Color.mOnSurfaceVariant
            basePixelSize: 12
        }
    }

    // Scrollable list of all live media players.
    Flickable {
        id: playerList

        anchors.fill: parent
        visible: root.playerCount > 0
        contentWidth: width
        contentHeight: playerColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: playerColumn

            width: parent.width
            spacing: 10

            Repeater {
                model: root.players

                // Single media player card with cover, metadata, and controls.
                MediaPlayerCard {
                    required property var modelData

                    width: parent.width
                    player: modelData
                    isActive: (modelData.identity || modelData.desktopEntry || "") === root.activePlayerKey
                }
            }
        }
    }
}
