import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "." as IslandCards
import "../media" as MediaParts

// Enhanced media card with artwork, progress bar, and transport controls for SuperIsland.
Item {
    id: root

    required property var event
    required property string iconSource
    property bool compact: false
    property date currentTime: new Date()
    property bool hasPendingEvents: false

    readonly property int _contentInsetV: Theme.barWidget.contentPaddingV
    readonly property string _displayTitle: MediaControlService.title || root.event.title || "Media"
    readonly property string _displayArtist: MediaControlService.artist || root.event.subtitle || ""
    readonly property string _artUrl: MediaControlService.artUrl || root.iconSource || ""
    readonly property string _playbackState: MediaControlService.playbackState || "stopped"
    readonly property string superIslandCardKind: "media"
    readonly property int _artworkSize: root.compact
        ? Theme.barWidget.pillHeight - root._contentInsetV * 2
        : Theme.barWidget.mediaPanelArtworkSize

    implicitWidth: root.compact ? _compactLayout.implicitWidth : _expandedLayout.implicitWidth
    implicitHeight: root.compact
        ? _compactLayout.implicitHeight
        : (_expandedLayout.implicitHeight + root._contentInsetV * 2)

    // Compact mode: shared clock and persistent media row.
    IslandCards.IslandClockMediaRow {
        id: _compactLayout
        anchors.verticalCenter: parent.verticalCenter
        visible: root.compact
        currentTime: root.currentTime
        hasPendingEvents: root.hasPendingEvents
    }

    // Expanded mode: full media controls (flash/strip track).
    RowLayout {
        id: _expandedLayout
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.compact
        spacing: Theme.barWidget.iconLabelSpacing

        // Album artwork.
        MediaParts.MediaArtwork {
            source: root._artUrl
            size: root._artworkSize
            roundedRect: true
            Layout.alignment: Qt.AlignVCenter
        }

        // Metadata + progress + controls column.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: ThemeSuperIsland.mediaExpandedMetadataSpacing

            // Track title.
            Text {
                Layout.fillWidth: true
                text: root._displayTitle
                color: Colors.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
            }

            // Artist label.
            Text {
                visible: root._displayArtist !== ""
                Layout.fillWidth: true
                text: root._displayArtist
                color: Colors.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
            }

            // Progress row with seek.
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: MediaControlService.positionLabel
                    color: Colors.textMuted
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    Layout.alignment: Qt.AlignVCenter
                    Layout.minimumWidth: implicitWidth
                }

                MediaParts.MediaProgressStrip {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.barWidget.iconLabelSpacing
                    Layout.rightMargin: Theme.barWidget.iconLabelSpacing
                    progress: MediaControlService.progress
                    expanded: true
                    interactive: MediaControlService.canSeek
                    onProgressCommitted: progressValue => MediaControlService.seekToProgress(progressValue)
                }

                Text {
                    text: MediaControlService.durationLabel
                    color: Colors.textMuted
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                    horizontalAlignment: Text.AlignRight
                    Layout.alignment: Qt.AlignVCenter
                    Layout.minimumWidth: implicitWidth
                }
            }

            // Transport controls.
            MediaParts.MediaFlashControls {
                Layout.fillWidth: true
                progress: MediaControlService.progress
                leadingLabel: ""
                durationLabel: ""
                playbackState: MediaControlService.playbackState
                canGoPrevious: MediaControlService.canGoPrevious
                canTogglePlayback: MediaControlService.canTogglePlayback
                canGoNext: MediaControlService.canGoNext
                showProgress: false
                topPadding: 0
                bottomPadding: 0
                onPreviousRequested: MediaControlService.previous()
                onPlayPauseRequested: MediaControlService.playPause()
                onNextRequested: MediaControlService.next()
            }
        }
    }
}
