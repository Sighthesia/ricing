import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import ".." as BarComponents

// Expanded media panel body with larger artwork and denser control layout.
Item {
    id: root

    implicitWidth: Theme.barWidget.mediaPanelWidth
    implicitHeight: _layout.implicitHeight + Theme.settingsPanelPadding + Theme.barWidget.contentPaddingV

    readonly property string _displayTitle:
        MediaControlService.title !== "" ? MediaControlService.title : "No Media"
    readonly property string _displayArtist:
        MediaControlService.artist !== "" ? MediaControlService.artist : MediaControlService.playerName
    readonly property string _metaLine:
        MediaControlService.playerName !== ""
            ? MediaControlService.playerName
            : MediaControlService.playbackState

    function runEnterAnimation() {
        _heroBlock.runEnter()
        _progressBlock.runEnter()
        _controlsBlock.runEnter()
    }

    function runExitAnimation() {
        _heroBlock.runExit()
        _progressBlock.runExit()
        _controlsBlock.runExit()
    }

    ColumnLayout {
        id: _layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: Theme.settingsPanelPadding
        anchors.rightMargin: Theme.settingsPanelPadding
        anchors.topMargin: Theme.settingsPanelPadding
        spacing: Theme.barWidget.contentPaddingV

        // Hero surface.
        BarComponents.StaggerItem {
            id: _heroBlock
            Layout.fillWidth: true
            implicitHeight: _heroSurface.implicitHeight
            delay: Theme.barWidget.mediaStaggerBaseDelay
            exitDelay: Theme.barWidget.mediaStaggerHeroExitDelay
            enterOffsetY: -Theme.barWidget.mediaStaggerHeroEnterOffset
            exitOffsetY: -Theme.barWidget.mediaStaggerHeroExitOffset

            // Hero surface body.
            Item {
                id: _heroSurface
                anchors.fill: parent
                implicitHeight: Theme.barWidget.mediaPanelArtworkSize
                    + Theme.barWidget.contentPaddingV * 2

                // Hero surface overlay.
                Rectangle {
                    anchors.fill: parent
                    color: Colors.background
                    opacity: Theme.barWidget.mediaSurfaceOverlayOpacity
                }

                // Panel visualizer strip.
                MediaVisualizerBackground {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.barWidget.contentPaddingH
                        + Theme.barWidget.mediaPanelArtworkSize
                        + Theme.barWidget.pillSpacing
                    anchors.rightMargin: Theme.barWidget.contentPaddingH
                    anchors.topMargin: Theme.barWidget.contentPaddingV * 2
                    anchors.bottomMargin: Theme.barWidget.contentPaddingV
                    bars: MediaControlService.visualizerHealthy ? MediaControlService.visualizerBars : []
                    barOpacity: Theme.barWidget.mediaVisualizerBarOpacity
                }

                // Hero content row.
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.barWidget.contentPaddingH
                    anchors.rightMargin: Theme.barWidget.contentPaddingH
                    anchors.topMargin: Theme.barWidget.contentPaddingV
                    anchors.bottomMargin: Theme.barWidget.contentPaddingV
                    spacing: Theme.barWidget.pillSpacing

                    // Panel artwork.
                    MediaArtwork {
                        source: MediaControlService.artUrl
                        size: Theme.barWidget.mediaPanelArtworkSize
                        roundedRect: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Hero text visualizer zone.
                    Item {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: _heroTextColumn.implicitHeight

                        // Hero text column.
                        ColumnLayout {
                            id: _heroTextColumn
                            anchors.fill: parent
                            spacing: Math.max(2, Theme.barWidget.contentPaddingV)

                            // Title row.
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.barWidget.iconSpacing

                                // Artist label.
                                Text {
                                    visible: root._displayArtist !== ""
                                    text: root._displayArtist
                                    color: Colors.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeBody
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    wrapMode: Text.NoWrap
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.maximumWidth: Math.round(
                                        Theme.barWidget.mediaPanelWidth
                                        * Theme.barWidget.mediaPanelArtistMaxWidthRatio)
                                }

                                // Artist-title separator.
                                Text {
                                    visible: root._displayArtist !== ""
                                    text: " - "
                                    color: Colors.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSizeBody
                                    opacity: Theme.barWidget.mediaFlashLabelOpacity
                                }

                                // Track title label.
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
                            }

                            // Meta label.
                            Text {
                                Layout.fillWidth: true
                                text: root._metaLine
                                color: Colors.textMuted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSizeSmall
                                visible: text !== ""
                                elide: Text.ElideRight
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }
        }

        // Progress and time group.
        BarComponents.StaggerItem {
            id: _progressBlock
            Layout.fillWidth: true
            implicitHeight: _progressRow.implicitHeight
            delay: Theme.barWidget.mediaStaggerBaseDelay + Theme.barWidget.mediaStaggerStep
            exitDelay: Theme.barWidget.mediaStaggerExitStep
            enterOffsetY: -Theme.barWidget.mediaStaggerProgressEnterOffset
            exitOffsetY: -Theme.barWidget.mediaStaggerProgressExitOffset

            // Progress and time row.
            Item {
                id: _progressRow
                anchors.fill: parent
                implicitHeight: _progressRowContent.implicitHeight + Theme.barWidget.contentPaddingV

                // Progress and time row content.
                RowLayout {
                    id: _progressRowContent
                    anchors.fill: parent
                    spacing: 0

                    // Elapsed time label.
                    Text {
                        text: MediaControlService.positionLabel
                        color: Colors.textMuted
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: Theme.barWidget.contentPaddingH
                        Layout.minimumWidth: implicitWidth
                    }

                    // Panel progress strip.
                    MediaProgressStrip {
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.barWidget.iconLabelSpacing
                        Layout.rightMargin: Theme.barWidget.iconLabelSpacing
                        progress: MediaControlService.progress
                        expanded: true
                        interactive: MediaControlService.canSeek
                        onProgressCommitted: progressValue => MediaControlService.seekToProgress(progressValue)
                    }

                    // Duration time label.
                    Text {
                        text: MediaControlService.durationLabel
                        color: Colors.textMuted
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignVCenter
                        Layout.rightMargin: Theme.barWidget.contentPaddingH
                        Layout.minimumWidth: implicitWidth
                    }
                }
            }
        }

        BarComponents.StaggerItem {
            id: _controlsBlock
            Layout.fillWidth: true
            Layout.topMargin: Theme.barWidget.mediaPanelControlsTopSpacing
            implicitHeight: _panelControls.implicitHeight
            delay: Theme.barWidget.mediaStaggerBaseDelay + Theme.barWidget.mediaStaggerStep * 2
            exitDelay: Theme.barWidget.mediaStaggerExitStep * 2
            enterOffsetY: -Theme.barWidget.mediaStaggerControlsEnterOffset
            exitOffsetY: -Theme.barWidget.mediaStaggerControlsExitOffset

            // Panel transport controls.
            MediaFlashControls {
                id: _panelControls
                anchors.fill: parent
                progress: MediaControlService.progress
                leadingLabel: ""
                durationLabel: ""
                playbackState: MediaControlService.playbackState
                canGoPrevious: MediaControlService.canGoPrevious
                canTogglePlayback: MediaControlService.canTogglePlayback
                canGoNext: MediaControlService.canGoNext
                showProgress: false
                topPadding: Theme.barWidget.contentPaddingV
                bottomPadding: Theme.barWidget.contentPaddingV * 2
                onPreviousRequested: MediaControlService.previous()
                onPlayPauseRequested: MediaControlService.playPause()
                onNextRequested: MediaControlService.next()
            }
        }

    }
}