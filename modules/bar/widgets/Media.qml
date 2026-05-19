import QtQuick
import "../../../services" as Services

// Render a compact now-playing pill for the bar.
Item {
    id: root

    property string currentText: root._displayText
    property string pendingText: root._displayText
    property string currentTextKey: root._displayTextKey
    property string pendingTextKey: root._displayTextKey
    property bool transitioning: false
    property string _stableArtUrl: ""
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
    readonly property string _displayText: Services.MediaControlService.showCompactLyric
        ? Services.MediaControlService.compactPrimaryLyric
        : root._fallbackDisplayText
    readonly property string _displayTextKey: Services.MediaControlService.showCompactLyric
        ? (Services.MediaControlService.compactPrimaryLyricKey !== ""
            ? Services.MediaControlService.compactPrimaryLyricKey
            : ("lyric:" + Services.MediaControlService.compactPrimaryLyric))
        : ("title:" + root._fallbackDisplayText)
    readonly property color _artFallbackColor: Qt.rgba(
        Services.Color.mSurfaceVariant.r,
        Services.Color.mSurfaceVariant.g,
        Services.Color.mSurfaceVariant.b,
        0.9
    )
    readonly property string _displayArtUrl:
        root._stableArtUrl !== "" ? root._stableArtUrl : Services.MediaControlService.artUrl
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

    implicitWidth: Math.min(Math.max(currentLayer.implicitWidth, nextLayer.implicitWidth) + 12, 220)
    implicitHeight: 26

    Behavior on implicitWidth {
        NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
    }

    Behavior on _progressValue {
        NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
    }

    function syncDisplayText() {
        const nextText = root._displayText
        const nextKey = root._displayTextKey
        if (nextKey === root.currentTextKey && !root.transitioning)
            return

        root.pendingText = nextText
        root.pendingTextKey = nextKey

        if (root.transitioning)
            return

        root.transitioning = true
        fadeTransition.restart()
    }

    function syncArtwork() {
        if (Services.MediaControlService.artUrl !== "") {
            root._stableArtUrl = Services.MediaControlService.artUrl
            return
        }

        if (Services.MediaControlService.title === "" && Services.MediaControlService.artist === "")
            root._stableArtUrl = ""
    }

    Component.onCompleted: {
        syncDisplayText()
        syncArtwork()
        root._progressValue = Services.MediaControlService.progress
    }

    on_DisplayTextChanged: syncDisplayText()
    on_DisplayTextKeyChanged: syncDisplayText()

    Connections {
        target: Services.MediaControlService

        function onCompactPrimaryLyricChanged() {
            root.syncDisplayText()
        }

        function onCompactPrimaryLyricKeyChanged() {
            root.syncDisplayText()
        }

        function onTitleChanged() {
            root.syncDisplayText()
            root.syncArtwork()
        }

        function onArtistChanged() {
            root.syncArtwork()
        }

        function onArtUrlChanged() {
            root.syncArtwork()
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

        anchors.centerIn: parent
        opacity: 1
        visible: opacity > 0
        implicitWidth: currentContent.implicitWidth
        implicitHeight: currentContent.implicitHeight

        // Render the current compact media content.
        Row {
            id: currentContent

            anchors.centerIn: parent
            spacing: 6

            // Draw the current circular artwork with a progress ring.
            Item {
                id: currentArtworkSlot

                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20

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

                // Mask the artwork into a persistent circular badge.
                Rectangle {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    radius: width / 2
                    color: root._artFallbackColor
                    border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.45)
                    border.width: 1
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root._displayArtUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: source !== ""
                        asynchronous: true
                        cache: true
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "♪"
                        color: Services.Color.mOnSurfaceVariant
                        font.pixelSize: 10
                        visible: root._displayArtUrl === ""
                    }
                }
            }

            // Show the current lyric or title in a constrained slot.
            Item {
                id: currentTextSlot

                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(currentTextLabel.implicitWidth, 184)
                height: currentTextLabel.implicitHeight

                Behavior on width {
                    NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
                }

                Text {
                    id: currentTextLabel

                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    text: root.currentText
                    color: Services.MediaControlService.showCompactLyric
                        ? Services.Color.mPrimary
                        : Services.Color.mOnSurface
                    font.pixelSize: 12
                    font.bold: Services.MediaControlService.showCompactLyric
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }
    }

    // Fade the next lyric or title above the current layer.
    Item {
        id: nextLayer

        anchors.centerIn: parent
        opacity: 0
        visible: opacity > 0
        z: 1
        implicitWidth: nextContent.implicitWidth
        implicitHeight: nextContent.implicitHeight

        // Render the incoming compact media content.
        Row {
            id: nextContent

            anchors.centerIn: parent
            spacing: 6

            // Keep the circular artwork and progress ring stable across text transitions.
            Item {
                id: nextArtworkSlot

                anchors.verticalCenter: parent.verticalCenter
                width: 20
                height: 20

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

                // Reuse the same circular badge inside the progress ring.
                Rectangle {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    radius: width / 2
                    color: root._artFallbackColor
                    border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.45)
                    border.width: 1
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root._displayArtUrl
                        fillMode: Image.PreserveAspectCrop
                        visible: source !== ""
                        asynchronous: true
                        cache: true
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "♪"
                        color: Services.Color.mOnSurfaceVariant
                        font.pixelSize: 10
                        visible: root._displayArtUrl === ""
                    }
                }
            }

            // Show the next lyric or title in the same width contract.
            Item {
                id: nextTextSlot

                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(nextTextLabel.implicitWidth, 184)
                height: nextTextLabel.implicitHeight

                Behavior on width {
                    NumberAnimation { duration: Services.Motion.number.contentDuration; easing.type: Services.Motion.number.contentEasing }
                }

                Text {
                    id: nextTextLabel

                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    text: root.pendingText
                    color: Services.MediaControlService.showCompactLyric
                        ? Services.Color.mPrimary
                        : Services.Color.mOnSurface
                    font.pixelSize: 12
                    font.bold: Services.MediaControlService.showCompactLyric
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }
    }
}
