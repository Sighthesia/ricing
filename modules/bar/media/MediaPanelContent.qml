import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "." as MediaParts
import ".." as BarComponents

// Expanded media panel body with shared SuperIsland shell treatment.
BarComponents.FloatingShellSurface {
    id: root

    property bool embedded: false

    implicitWidth: Theme.barWidget.mediaPanelWidth
    implicitHeight: _contentColumn.implicitHeight + root.contentMargin * 2
    shellRadius: ThemeCards.shellRadius
    contentMargin: root.embedded ? 0 : ThemeCards.panelPadding
    fillColor: root.embedded
        ? "transparent"
        : Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, ThemeCards.shellSurfaceAlpha)
    borderColor: root.embedded
        ? "transparent"
        : Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, ThemeCards.shellBorderAlpha)
    innerBorderColor: root.embedded
        ? "transparent"
        : Qt.rgba(Colors.text.r, Colors.text.g, Colors.text.b, ThemeCards.shellInnerBorderAlpha)
    innerBorderWidth: root.embedded ? 0 : 1

    readonly property bool _showLyrics: SettingsService.data.mediaControl.showLyrics
    readonly property bool _preferLyrics: SettingsService.data.mediaControl.preferLyrics
    readonly property string _currentLyric: MediaControlService.currentLyric || ""
    readonly property string _nextLyric: MediaControlService.nextLyric || ""
    readonly property string _currentTranslatedLyric: MediaControlService.currentTranslatedLyric || ""
    readonly property string _nextTranslatedLyric: MediaControlService.nextTranslatedLyric || ""
    readonly property string _primaryLyric:
        root._currentLyric !== "" ? root._currentLyric : root._nextLyric
    readonly property string _primaryTranslatedLyric:
        root._currentTranslatedLyric !== "" ? root._currentTranslatedLyric : root._nextTranslatedLyric
    readonly property string _displayTitle:
        MediaControlService.title !== "" ? MediaControlService.title : "No Media"
    readonly property string _displayArtist:
        MediaControlService.artist !== "" ? MediaControlService.artist : MediaControlService.playerName
    readonly property color _panelFillColor: Qt.rgba(
        Colors.background.r,
        Colors.background.g,
        Colors.background.b,
        ThemeCards.shellSurfaceAlpha
    )
    readonly property color _panelBorderColor: Qt.rgba(
        Colors.border.r,
        Colors.border.g,
        Colors.border.b,
        ThemeCards.shellBorderAlpha
    )
    readonly property color _panelInnerBorderColor: Qt.rgba(
        Colors.text.r,
        Colors.text.g,
        Colors.text.b,
        ThemeCards.shellInnerBorderAlpha
    )
    property real _contentOpacity: 0

    function runEnterAnimation() {
        _contentExitAnim.stop()
        _contentEnterAnim.restart()
    }

    function runExitAnimation() {
        _contentEnterAnim.stop()
        _contentExitAnim.restart()
    }

    // Media panel stack.
    ColumnLayout {
        id: _contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        opacity: root._contentOpacity
        spacing: ThemeCards.panelGap

        // Hero shell.
        BarComponents.FloatingShellSurface {
            id: _heroShell
            Layout.fillWidth: true
            shellRadius: ThemeCards.compactRadius
            contentMargin: ThemeCards.compactInset
            implicitHeight: _heroContent.implicitHeight + contentMargin * 2
            fillColor: root._panelFillColor
            borderColor: root._panelBorderColor
            innerBorderColor: root._panelInnerBorderColor
            innerBorderWidth: 1

            // Hero content shell.
            ColumnLayout {
                id: _heroContent
                anchors.fill: parent
                spacing: ThemeCards.compactGap

                // Title row.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: ThemeCards.compactGap

                    // Album artwork.
                    MediaParts.MediaArtwork {
                        source: MediaControlService.artUrl
                        size: Theme.barWidget.mediaPanelArtworkSize
                        roundedRect: true
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // Metadata column.
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

                        // Primary lyric line.
                        Text {
                            visible: root._showLyrics && root._preferLyrics && root._primaryLyric !== ""
                            Layout.fillWidth: true
                            text: root._primaryLyric
                            color: Colors.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            wrapMode: Text.NoWrap
                        }

                        // Primary translated lyric line.
                        Text {
                            visible: root._showLyrics && root._preferLyrics && root._primaryTranslatedLyric !== ""
                            Layout.fillWidth: true
                            text: root._primaryTranslatedLyric
                            color: Colors.text
                            opacity: 0.85
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSizeSmall
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            wrapMode: Text.NoWrap
                        }
                    }
                }

                // Background visualizer layer.
                MediaParts.MediaVisualizerBackground {
                    Layout.fillWidth: true
                    implicitHeight: Math.max(Theme.barWidget.mediaPanelArtworkSize, Theme.barWidget.pillHeight)
                    bars: MediaControlService.visualizerHealthy ? MediaControlService.visualizerBars : []
                    barOpacity: Theme.barWidget.mediaVisualizerBarOpacity
                }
            }
        }

        // Transport shell.
        BarComponents.FloatingShellSurface {
            id: _bodyShell
            Layout.fillWidth: true
            shellRadius: ThemeCards.compactRadius
            contentMargin: ThemeCards.compactInset
            implicitHeight: _bodyContent.implicitHeight + contentMargin * 2
            fillColor: root._panelFillColor
            borderColor: root._panelBorderColor
            innerBorderColor: root._panelInnerBorderColor
            innerBorderWidth: 1

            // Body content.
            ColumnLayout {
                id: _bodyContent
                anchors.fill: parent
                spacing: ThemeCards.compactGap

                // Progress row.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    // Elapsed label.
                    Text {
                        text: MediaControlService.positionLabel
                        color: Colors.textMuted
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        Layout.alignment: Qt.AlignVCenter
                        Layout.minimumWidth: implicitWidth
                    }

                    // Seek strip.
                    MediaParts.MediaProgressStrip {
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.barWidget.iconLabelSpacing
                        Layout.rightMargin: Theme.barWidget.iconLabelSpacing
                        progress: MediaControlService.progress
                        expanded: true
                        interactive: MediaControlService.canSeek
                        onProgressCommitted: progressValue => MediaControlService.seekToProgress(progressValue)
                    }

                    // Duration label.
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
                    id: _panelControls
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

    // Content enter animation.
    NumberAnimation {
        id: _contentEnterAnim
        target: root
        property: "_contentOpacity"
        to: 1
        duration: Theme.anim.highlightDuration
        easing.type: Theme.anim.highlightType
    }

    // Content exit animation.
    NumberAnimation {
        id: _contentExitAnim
        target: root
        property: "_contentOpacity"
        to: 0
        duration: Theme.anim.moveDuration
        easing.type: Theme.anim.moveType
    }
}
