import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import qs.config
import qs.services
import "../media" as MediaParts

// Compact synced lyrics strip with spectrum visualizer for SuperIsland.
Item {
    id: root

    required property var event
    required property string iconSource

    readonly property string _artUrl: MediaControlService.artUrl || root.iconSource || ""
    readonly property bool _preferTranslated: MediaControlService.preferTranslatedLyrics
    readonly property var _lyricLines: _preferTranslated
        ? NeteaseWebLyricsService._translatedLyricLines
        : NeteaseWebLyricsService._lyricLines
    readonly property int _currentLineIndex: _preferTranslated
        ? NeteaseWebLyricsService.currentTranslatedLyricIndex
        : NeteaseWebLyricsService.currentLyricIndex

    // Dynamic width: base + longest visible lyric line.
    property int _defaultTextWidth: Math.round(350 * Theme.uiScale)
    property int _currentTextWidth: root._defaultTextWidth

    // Layout: leftMargin(12) + cover(26) + gap(12) + text(dynamic) + gap(12) + spectrum(22) + rightMargin(12)
    implicitWidth: 96 + root._currentTextWidth
    implicitHeight: Theme.barWidget.pillHeight

    // Manage CavaService refcount for spectrum lifecycle.
    Component.onCompleted: CavaService.refCount++
    Component.onDestruction: CavaService.refCount = Math.max(0, CavaService.refCount - 1)

    Item {
        anchors.fill: parent
        clip: true

        // Album cover thumbnail.
        Item {
            id: _coverContainer
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 26
            height: 26

            MediaParts.MediaArtwork {
                anchors.fill: parent
                source: root._artUrl
                size: 26
            }
        }

        // Synced lyrics ListView.
        ListView {
            id: _lyricsView
            anchors.left: _coverContainer.right
            anchors.leftMargin: 12
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: root._currentTextWidth

            interactive: false
            model: root._lyricLines
            currentIndex: Math.max(0, root._currentLineIndex)

            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: 0
            preferredHighlightEnd: 0
            highlightMoveDuration: 400

            delegate: Item {
                width: ListView.view.width
                height: 42
                property bool _isCurrent: ListView.isCurrentItem

                on_IsCurrentChanged: {
                    if (_isCurrent) {
                        root._currentTextWidth = Math.max(
                            root._defaultTextWidth,
                            Math.min(Math.round(_lyricText.implicitWidth), Math.round(800 * Theme.uiScale))
                        )
                    }
                }

                Text {
                    id: _lyricText
                    anchors.centerIn: parent
                    text: modelData.text || ""
                    color: parent._isCurrent ? Colors.text : Colors.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeBody
                    font.weight: parent._isCurrent ? Font.Bold : Font.Normal
                    opacity: parent._isCurrent ? 1.0 : 0.5
                    scale: parent._isCurrent ? 1.25 : 1.0
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.anim.highlightDuration
                            easing.type: Theme.anim.highlightType
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.anim.highlightDuration
                            easing.type: Theme.anim.highlightType
                        }
                    }
                }
            }
        }

        // Symmetric 6-bar spectrum visualizer from CavaService.
        Item {
            id: _spectrumContainer
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 16

            property var smoothValues: [0, 0, 0, 0, 0, 0]

            Timer {
                interval: 16
                running: CavaService.healthy
                repeat: true
                onTriggered: {
                    var s = _spectrumContainer.smoothValues
                    var r = CavaService.bars
                    if (!r || r.length < 6)
                        return

                    var barCount = r.length

                    // Aggregate cava bars into 6 symmetric frequency regions.
                    var getRegionMax = function(start, end) {
                        var maxV = 0
                        var clampEnd = Math.min(end, barCount - 1)
                        for (var i = start; i <= clampEnd; i++) {
                            if (r[i] > maxV)
                                maxV = r[i]
                        }
                        return maxV
                    }

                    var targets = [0, 0, 0, 0, 0, 0]
                    var hfComp = 1.5
                    var mfComp = 1.2

                    // Outer bars: high frequency.
                    targets[0] = getRegionMax(Math.round(barCount * 0.55), Math.round(barCount * 0.75)) * hfComp
                    targets[5] = getRegionMax(Math.round(barCount * 0.75), barCount - 1) * hfComp

                    // Middle bars: mid frequency.
                    targets[1] = getRegionMax(Math.round(barCount * 0.2), Math.round(barCount * 0.35)) * mfComp
                    targets[4] = getRegionMax(Math.round(barCount * 0.35), Math.round(barCount * 0.55)) * mfComp

                    // Center bars: bass.
                    targets[2] = getRegionMax(0, Math.round(barCount * 0.1))
                    targets[3] = getRegionMax(Math.round(barCount * 0.1), Math.round(barCount * 0.2))

                    var globalBeat = Math.max(targets[2], targets[3])

                    for (var i = 0; i < 6; i++) {
                        var finalTarget = Math.min(1, targets[i] * 0.8 + globalBeat * 0.2)
                        var diff = finalTarget - s[i]

                        // Fast attack, slow release for smooth feel.
                        if (diff > 0)
                            s[i] += 0.85 * diff
                        else
                            s[i] += 0.08 * diff
                    }

                    _spectrumContainer.smoothValues = s
                    _spectrumCanvas.requestPaint()
                }
            }

            Canvas {
                id: _spectrumCanvas
                anchors.fill: parent
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var s = parent.smoothValues

                    ctx.beginPath()
                    ctx.lineCap = "round"
                    ctx.lineWidth = 2.5
                    ctx.strokeStyle = String(Colors.highlight)

                    for (var i = 0; i < 6; i++) {
                        var val = Math.min(1.0, s[i])
                        var h = Math.max(3, val * height)

                        var x = 1.25 + i * 3.7

                        ctx.moveTo(x, height / 2 - h / 2)
                        ctx.lineTo(x, height / 2 + h / 2)
                    }
                    ctx.stroke()
                }
            }
        }
    }
}
