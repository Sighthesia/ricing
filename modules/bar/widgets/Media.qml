import QtQuick
import Qt5Compat.GraphicalEffects
import ".." as Bar
import "../../../services" as Services

// Render a compact now-playing pill for the bar. While a transient message is
// active the text collapses away so the widget simplifies to its artwork icon,
// yielding attention to the interrupting message.
Item {
    id: root

    property string widgetInstanceKey: ""
    property real availableWidth: -1

    // Simplify to icon-only using the shared transient reveal progress.
    readonly property real transientRevealProgress: Services.TransientMessageService.revealProgress
    readonly property bool simplified: transientRevealProgress >= 0.99
    readonly property var mediaSettings: Services.SettingsService.widgetSettingsObject(
        "media",
        root.widgetInstanceKey
    )
    readonly property string lyricsDisplayMode: root.normalizedLyricsDisplayMode(
        root.mediaSettings && root.mediaSettings.lyricsDisplayMode
            ? root.mediaSettings.lyricsDisplayMode
            : "Original"
    )
    readonly property bool compactLyricVisible: Services.MediaControlService.showCompactLyric
        && root._displayLyricPrimaryText !== ""
    readonly property bool showAudioSpectrum: root.mediaSettings
        ? root.mediaSettings.showAudioSpectrum
        : false
    readonly property bool needsAudioSpectrum: root.showAudioSpectrum && !root.simplified
    readonly property string spectrumComponentId: "media:" + root.widgetInstanceKey
    readonly property real compactTextWidth: {
        if (root.availableWidth <= 0)
            return 200

        var artWidth = 24
        var spacing = 6
        var chrome = 16
        return Math.max(48, Math.min(200, root.availableWidth - artWidth - spacing - chrome))
    }
    readonly property real transientTextRevealProgress: Math.max(0, Math.min(1, 1 - root.transientRevealProgress))
    readonly property real currentTextTargetWidth: Math.min(Math.max(currentTextLabel.implicitWidth, currentSecondaryTextLabel.implicitWidth), root.compactTextWidth) * root.transientTextRevealProgress
    readonly property real nextTextTargetWidth: Math.min(Math.max(nextTextLabel.implicitWidth, nextSecondaryTextLabel.implicitWidth), root.compactTextWidth) * root.transientTextRevealProgress
    readonly property real compactBaseHeight: 30
    readonly property real lyricExtraHeight: Math.max(
        currentSecondaryText !== "" ? Math.max(0, currentTextColumn.implicitHeight - currentTextLabel.implicitHeight) : 0,
        pendingSecondaryText !== "" ? Math.max(0, nextTextColumn.implicitHeight - nextTextLabel.implicitHeight) : 0
    )
    readonly property real lyricBottomPadding: 8
    readonly property bool lyricHeightExpanded: root.compactLyricVisible && root.transientTextRevealProgress > 0.01
    readonly property real dockzoneExpandHeight: root.lyricHeightExpanded
        ? (root.lyricExtraHeight > 0 ? root.lyricExtraHeight + root.lyricBottomPadding : 0)
        : 0
    readonly property real compactCenterY: root.compactBaseHeight / 2

    property string currentText: root._displayText
    property string currentSecondaryText: root._displaySecondaryText
    property string pendingText: root._displayText
    property string pendingSecondaryText: root._displaySecondaryText
    property string currentTextKey: root._displayTextKey
    property string pendingTextKey: root._displayTextKey
    property bool transitioning: false
    property real _progressValue: Services.MediaControlService.progress

    readonly property string _fallbackTitle: Services.MediaControlService.title !== ""
        ? Services.MediaControlService.title
        : (Services.MediaService.title !== "" ? Services.MediaService.title : "No media")
    readonly property string _fallbackArtist: Services.MediaControlService.artist !== ""
        ? Services.MediaControlService.artist
        : Services.MediaService.artist
    readonly property string _fallbackDisplayText: root._fallbackArtist !== ""
        ? root._fallbackTitle + " · " + root._fallbackArtist
        : root._fallbackTitle
    readonly property string _displayLyricPrimaryText: {
        var original = Services.MediaControlService.compactOriginalLyric
        var translated = Services.MediaControlService.compactTranslatedLyric
        if (root.lyricsDisplayMode === "translated")
            return translated !== "" ? translated : original

        return original !== "" ? original : translated
    }
    readonly property string _displayLyricSecondaryText: root.lyricsDisplayMode === "both"
        && Services.MediaControlService.compactOriginalLyric !== ""
        && Services.MediaControlService.compactTranslatedLyric !== ""
            ? Services.MediaControlService.compactTranslatedLyric
            : ""
    readonly property string _displayText: root.compactLyricVisible
        ? root._displayLyricPrimaryText
        : root._fallbackDisplayText
    readonly property string _displaySecondaryText: root.compactLyricVisible ? root._displayLyricSecondaryText : ""
    readonly property string _displayTextKey: root.compactLyricVisible
        ? ("lyric:" + root.lyricsDisplayMode + ":"
            + (root.lyricsDisplayMode === "translated" && Services.MediaControlService.compactTranslatedLyric !== ""
                ? Services.MediaControlService.compactTranslatedLyricKey
                : Services.MediaControlService.compactOriginalLyricKey)
            + ":" + Services.MediaControlService.compactTranslatedLyricKey)
        : ("title:" + root._fallbackDisplayText)
    readonly property color _artFallbackColor: Qt.rgba(
        Services.Color.mSurfaceVariant.r,
        Services.Color.mSurfaceVariant.g,
        Services.Color.mSurfaceVariant.b,
        0.9
    )
    readonly property string _displayArtUrl: Services.MediaControlService.artUrl
    readonly property bool _currentArtworkReady: currentArtworkSource.status === Image.Ready
    readonly property bool _nextArtworkReady: nextArtworkSource.status === Image.Ready
    readonly property color _ringTrackColor: Qt.rgba(
        Services.Color.mOutline.r,
        Services.Color.mOutline.g,
        Services.Color.mOutline.b,
        0.3
    )
    readonly property color _ringProgressColor: Qt.rgba(
        Services.Color.mPrimary.r,
        Services.Color.mPrimary.g,
        Services.Color.mPrimary.b,
        0.95
    )

    implicitWidth: Math.min(Math.max(currentLayer.implicitWidth, nextLayer.implicitWidth) + 16, 240)
    implicitHeight: root.compactBaseHeight

    Behavior on _progressValue {
        NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
    }

    function isLyricTextKey(textKey) {
        return textKey.indexOf("original:") === 0
            || textKey.indexOf("translated:") === 0
            || textKey.indexOf("lyric:") === 0
    }

    function normalizedLyricsDisplayMode(value) {
        if (value === "Translated" || value === "translated")
            return "translated"
        if (value === "Original + Translation" || value === "both")
            return "both"
        return "original"
    }

    function syncDisplayText() {
        const nextText = root._displayText
        const nextSecondaryText = root._displaySecondaryText
        const nextKey = root._displayTextKey
        if (nextKey === root.currentTextKey && !root.transitioning)
            return

        if (root.isLyricTextKey(root.currentTextKey) && root.isLyricTextKey(nextKey)) {
            fadeTransition.stop()
            currentLayer.opacity = 1
            nextLayer.opacity = 0
            root.currentText = nextText
            root.currentSecondaryText = nextSecondaryText
            root.pendingText = nextText
            root.pendingSecondaryText = nextSecondaryText
            root.currentTextKey = nextKey
            root.pendingTextKey = nextKey
            root.transitioning = false
            return
        }

        root.pendingText = nextText
        root.pendingSecondaryText = nextSecondaryText
        root.pendingTextKey = nextKey

        if (root.transitioning)
            return

        root.transitioning = true
        fadeTransition.restart()
    }

    function syncSpectrumRegistration() {
        if (root.needsAudioSpectrum)
            Services.SpectrumService.registerComponent(root.spectrumComponentId)
        else
            Services.SpectrumService.unregisterComponent(root.spectrumComponentId)
    }

    Component.onCompleted: {
        Services.SettingsService.ensureWidgetSettings("media", root.widgetInstanceKey)
        syncDisplayText()
        root._progressValue = Services.MediaControlService.progress
        syncSpectrumRegistration()
    }

    Component.onDestruction: Services.SpectrumService.unregisterComponent(root.spectrumComponentId)

    on_DisplayTextChanged: syncDisplayText()
    on_DisplayTextKeyChanged: syncDisplayText()
    on_DisplaySecondaryTextChanged: syncDisplayText()
    onLyricsDisplayModeChanged: syncDisplayText()
    onNeedsAudioSpectrumChanged: syncSpectrumRegistration()

    Connections {
        target: Services.MediaControlService

        function onCompactPrimaryLyricChanged() {
            root.syncDisplayText()
        }

        function onCompactPrimaryLyricKeyChanged() {
            root.syncDisplayText()
        }

        function onCompactTranslatedLyricChanged() {
            root.syncDisplayText()
        }

        function onCompactTranslatedLyricKeyChanged() {
            root.syncDisplayText()
        }

        function onTitleChanged() {
            root.syncDisplayText()
        }

        function onProgressChanged() {
            root._progressValue = Services.MediaControlService.progress
        }
    }

    SequentialAnimation {
        id: fadeTransition

        ParallelAnimation {
            NumberAnimation {
                target: currentLayer
                property: "opacity"
                from: 1
                to: 0
                duration: Services.Motion.number.shortDuration
                easing.type: Services.Motion.number.shortEasing
            }

            NumberAnimation {
                target: nextLayer
                property: "opacity"
                from: 0
                to: 1
                duration: Services.Motion.number.enterDuration
                easing.type: Services.Motion.number.enterEasing
            }
        }

        ScriptAction {
            script: {
                root.currentText = root.pendingText
                root.currentSecondaryText = root.pendingSecondaryText
                root.currentTextKey = root.pendingTextKey
            }
        }

        ScriptAction {
            script: {
                currentLayer.opacity = 1
                nextLayer.opacity = 0
                root.transitioning = false
            }
        }
    }

    // Keep the current artwork and text visible while transitions run.
    Item {
        id: currentLayer

        x: Math.round((parent.width - width) / 2)
        y: Math.round(root.compactCenterY - height / 2)
        opacity: 1
        visible: opacity > 0
        implicitWidth: currentArtworkSlot.width + root.currentTextTargetWidth + (root.currentTextTargetWidth > 0 ? currentContent.spacing : 0)
        implicitHeight: currentContent.implicitHeight

        // Keep the spectrum tucked behind the compact media contents.
        Item {
            anchors.fill: currentContent
            visible: root.needsAudioSpectrum && width > 0 && height > 0 && (opacity > 0.01 || !Services.SpectrumService.isIdle)
            z: -1
            clip: true
            opacity: Services.SpectrumService.isIdle ? 0 : 1

            Behavior on opacity {
                NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
            }

            Bar.DockzoneSpectrum {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                anchors.topMargin: 3
                anchors.bottomMargin: 3
                values: Services.SpectrumService.values
            }
        }

        // Render the current compact media content.
        Row {
            id: currentContent

            anchors.centerIn: parent
            spacing: 6

            // Draw the current circular artwork with a progress ring.
            Item {
                id: currentArtworkSlot

                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24

                // Paint the circular progress track and active progress arc.
                Canvas {
                    id: currentProgressRing

                    anchors.fill: parent
                    antialiasing: true

                    onPaint: {
                        const ctx = getContext("2d")
                        const size = Math.min(width, height)
                        const center = size / 2
                        const radius = (size / 2) - 1.25
                        const startAngle = -Math.PI / 2
                        const sweep = Math.max(0, Math.min(1, root._progressValue)) * Math.PI * 2

                        ctx.reset()
                        ctx.clearRect(0, 0, width, height)
                        ctx.lineCap = "round"
                        ctx.lineWidth = 2

                        ctx.beginPath()
                        ctx.strokeStyle = root._ringTrackColor
                        ctx.arc(center, center, radius, 0, Math.PI * 2, false)
                        ctx.stroke()

                        if (sweep <= 0)
                            return

                        ctx.beginPath()
                        ctx.strokeStyle = root._ringProgressColor
                        ctx.arc(center, center, radius, startAngle, startAngle + sweep, false)
                        ctx.stroke()
                    }

                    Connections {
                        target: root
                        function on_ProgressValueChanged() { currentProgressRing.requestPaint() }
                    }

                    Connections {
                        target: Services.Color
                        function onMPrimaryChanged() { currentProgressRing.requestPaint() }
                        function onMOutlineChanged() { currentProgressRing.requestPaint() }
                    }
                }

                // Keep a reusable mask source for the circular artwork crop.
                Item {
                    id: currentArtworkMaskContainer

                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    layer.enabled: true
                    visible: false

                    // Define the circular crop shape.
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "white"
                    }
                }

                // Keep the raw artwork source separate from the masked output.
                Image {
                    id: currentArtworkSource

                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    visible: false
                    source: root._displayArtUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true

                    onStatusChanged: {
                        if (status === Image.Error && source !== "")
                            Services.MediaService.reportArtLoadFailure(source)
                    }
                }

                // Frame the circular artwork badge.
                Rectangle {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    radius: width / 2
                    color: root._artFallbackColor
                    border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.45)
                    border.width: 1

                    // Render the masked circular artwork.
                    OpacityMask {
                        anchors.fill: parent
                        visible: root._currentArtworkReady
                        source: currentArtworkSource
                        maskSource: currentArtworkMaskContainer
                    }

                    Services.FluidText {
                        anchors.centerIn: parent
                        text: "♪"
                        color: Services.Color.mOnSurfaceVariant
                        basePixelSize: 10
                        visible: !root._currentArtworkReady
                    }
                }
            }

            // Show the current lyric or title in a constrained slot.
            Item {
                id: currentTextSlot

                anchors.verticalCenter: parent.verticalCenter
                visible: root.transientTextRevealProgress > 0.01
                property real revealWidth: root.currentTextTargetWidth

                width: revealWidth
                height: currentTextLabel.implicitHeight

                Behavior on revealWidth {
                    NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
                }

                // Stack original and translated lyric lines when both are requested.
                Column {
                    id: currentTextColumn
                    width: parent.width
                    y: 0
                    opacity: root.transientTextRevealProgress
                    x: Math.round((1 - root.transientTextRevealProgress) * -6)
                    spacing: root.currentSecondaryText !== "" ? -1 : 0

                    Services.FluidText {
                        id: currentTextLabel

                        width: parent.width
                        text: root.currentText
                        color: root.compactLyricVisible
                            ? Services.Color.mPrimary
                            : Services.Color.mOnSurface
                        font.bold: root.compactLyricVisible
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Services.FluidText {
                        id: currentSecondaryTextLabel

                        visible: root.currentSecondaryText !== ""
                        width: parent.width
                        text: root.currentSecondaryText
                        color: Services.Color.mOnSurfaceVariant
                        basePixelSize: 10
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }
        }
    }

    // Fade the next lyric or title above the current layer.
    Item {
        id: nextLayer

        x: Math.round((parent.width - width) / 2)
        y: Math.round(root.compactCenterY - height / 2)
        opacity: 0
        visible: opacity > 0
        z: 1
        implicitWidth: nextArtworkSlot.width + root.nextTextTargetWidth + (root.nextTextTargetWidth > 0 ? nextContent.spacing : 0)
        implicitHeight: nextContent.implicitHeight

        // Mirror the spectrum during text transitions so the background stays continuous.
        Item {
            anchors.fill: nextContent
            visible: root.needsAudioSpectrum && width > 0 && height > 0 && (opacity > 0.01 || !Services.SpectrumService.isIdle)
            z: -1
            clip: true
            opacity: Services.SpectrumService.isIdle ? 0 : 1

            Behavior on opacity {
                NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
            }

            Bar.DockzoneSpectrum {
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                anchors.topMargin: 3
                anchors.bottomMargin: 3
                values: Services.SpectrumService.values
            }
        }

        // Render the incoming compact media content.
        Row {
            id: nextContent

            anchors.centerIn: parent
            spacing: 6

            // Keep the circular artwork and progress ring stable across text transitions.
            Item {
                id: nextArtworkSlot

                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24

                // Paint the same progress ring for the outgoing and incoming text layers.
                Canvas {
                    id: nextProgressRing

                    anchors.fill: parent
                    antialiasing: true

                    onPaint: {
                        const ctx = getContext("2d")
                        const size = Math.min(width, height)
                        const center = size / 2
                        const radius = (size / 2) - 1.25
                        const startAngle = -Math.PI / 2
                        const sweep = Math.max(0, Math.min(1, root._progressValue)) * Math.PI * 2

                        ctx.reset()
                        ctx.clearRect(0, 0, width, height)
                        ctx.lineCap = "round"
                        ctx.lineWidth = 2

                        ctx.beginPath()
                        ctx.strokeStyle = root._ringTrackColor
                        ctx.arc(center, center, radius, 0, Math.PI * 2, false)
                        ctx.stroke()

                        if (sweep <= 0)
                            return

                        ctx.beginPath()
                        ctx.strokeStyle = root._ringProgressColor
                        ctx.arc(center, center, radius, startAngle, startAngle + sweep, false)
                        ctx.stroke()
                    }

                    Connections {
                        target: root
                        function on_ProgressValueChanged() { nextProgressRing.requestPaint() }
                    }

                    Connections {
                        target: Services.Color
                        function onMPrimaryChanged() { nextProgressRing.requestPaint() }
                        function onMOutlineChanged() { nextProgressRing.requestPaint() }
                    }
                }

                // Keep a reusable mask source for the next-layer artwork crop.
                Item {
                    id: nextArtworkMaskContainer

                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    layer.enabled: true
                    visible: false

                    // Define the circular crop shape.
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "white"
                    }
                }

                // Keep the raw artwork source for the next layer separate.
                Image {
                    id: nextArtworkSource

                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    visible: false
                    source: root._displayArtUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true

                    onStatusChanged: {
                        if (status === Image.Error && source !== "")
                            Services.MediaService.reportArtLoadFailure(source)
                    }
                }

                // Reuse the same circular badge inside the progress ring.
                Rectangle {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    radius: width / 2
                    color: root._artFallbackColor
                    border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.45)
                    border.width: 1

                    // Render the masked circular artwork.
                    OpacityMask {
                        anchors.fill: parent
                        visible: root._nextArtworkReady
                        source: nextArtworkSource
                        maskSource: nextArtworkMaskContainer
                    }

                    Services.FluidText {
                        anchors.centerIn: parent
                        text: "♪"
                        color: Services.Color.mOnSurfaceVariant
                        basePixelSize: 10
                        visible: !root._nextArtworkReady
                    }
                }
            }

            // Show the next lyric or title in the same width contract.
            Item {
                id: nextTextSlot

                anchors.verticalCenter: parent.verticalCenter
                visible: root.transientTextRevealProgress > 0.01
                property real revealWidth: root.nextTextTargetWidth

                width: revealWidth
                height: nextTextLabel.implicitHeight

                Behavior on revealWidth {
                    NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
                }

                // Mirror the stacked lyric layout for incoming text transitions.
                Column {
                    id: nextTextColumn
                    width: parent.width
                    y: 0
                    opacity: root.transientTextRevealProgress
                    x: Math.round((1 - root.transientTextRevealProgress) * -6)
                    spacing: root.pendingSecondaryText !== "" ? -1 : 0

                    Services.FluidText {
                        id: nextTextLabel

                        width: parent.width
                        text: root.pendingText
                        color: root.compactLyricVisible
                            ? Services.Color.mPrimary
                            : Services.Color.mOnSurface
                        font.bold: root.compactLyricVisible
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Services.FluidText {
                        id: nextSecondaryTextLabel

                        visible: root.pendingSecondaryText !== ""
                        width: parent.width
                        text: root.pendingSecondaryText
                        color: Services.Color.mOnSurfaceVariant
                        basePixelSize: 10
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
            }
        }
    }
}
