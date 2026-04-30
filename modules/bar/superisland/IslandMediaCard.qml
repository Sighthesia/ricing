import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../media" as MediaParts

// Enhanced media card with artwork, progress bar, and transport controls for SuperIsland.
Item {
    id: root

    required property var event
    required property string iconSource
    property bool compact: false

    readonly property int _contentInsetV: Theme.barWidget.contentPaddingV
    readonly property int _artworkSize: root.compact
        ? Math.max(Theme.barWidget.primaryIconSize, Theme.barWidget.primaryIconSize + root._contentInsetV * 2)
        : Theme.barWidget.mediaPanelArtworkSize
    readonly property string _displayTitle: MediaControlService.title || root.event.title || "Media"
    readonly property string _displayArtist: MediaControlService.artist || root.event.subtitle || ""
    readonly property string _artUrl: MediaControlService.artUrl || root.iconSource || ""
    readonly property string _playbackState: MediaControlService.playbackState || "stopped"

    implicitWidth: root.compact ? _compactLayout.implicitWidth : _expandedLayout.implicitWidth
    implicitHeight: root.compact
        ? (Theme.fontSizeBody + root._contentInsetV * 2)
        : (_expandedLayout.implicitHeight + root._contentInsetV * 2)

    // Compact mode: artwork + title + state badge (bar pill).
    RowLayout {
        id: _compactLayout
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.compact
            ? Math.max(1, Math.round(Theme.barWidget.contentPaddingV / 2))
            : 0
        visible: root.compact
        spacing: Theme.barWidget.iconLabelSpacing

        // Album artwork thumbnail.
        MediaParts.MediaArtwork {
            source: root._artUrl
            size: Theme.barWidget.primaryIconSize + root._contentInsetV * 2
            Layout.alignment: Qt.AlignVCenter
        }

        // Track metadata.
        ColumnLayout {
            spacing: 0
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: root._displayTitle
                color: Colors.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
                elide: Text.ElideRight
                Layout.maximumWidth: Math.round(180 * Theme.uiScale)
            }

            Text {
                visible: root._displayArtist !== ""
                text: root._displayArtist
                color: Colors.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
                Layout.maximumWidth: Math.round(180 * Theme.uiScale)
            }
        }

        // Playback state badge.
        Rectangle {
            radius: Theme.cornerRadius
            color: Colors.highlight
            opacity: Colors.highlightAlpha + 0.1
            implicitHeight: _compactStateText.implicitHeight + Theme.barWidget.badgePaddingV * 2
            implicitWidth: _compactStateText.implicitWidth + Theme.barWidget.badgePaddingH * 2
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: _compactStateText
                anchors.centerIn: parent
                text: root._playbackState === "playing" ? "Playing"
                    : root._playbackState === "paused" ? "Pause"
                    : "Stopped"
                color: Colors.text
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
            }
        }
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
            spacing: Math.max(2, Theme.barWidget.contentPaddingV)

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
