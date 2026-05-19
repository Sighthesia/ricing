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

    implicitWidth: Math.min(Math.max(currentLayer.implicitWidth, nextLayer.implicitWidth) + 12, 220)
    implicitHeight: 26

    Behavior on implicitWidth {
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

    Component.onCompleted: syncDisplayText()

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

            // Draw the current album artwork slot.
            Rectangle {
                id: currentArtworkSlot

                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                radius: 9
                color: root._artFallbackColor
                border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.45)
                border.width: 1
                clip: true

                Image {
                    anchors.fill: parent
                    source: Services.MediaControlService.artUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: source !== ""
                    asynchronous: true
                    cache: false
                }

                Text {
                    anchors.centerIn: parent
                    text: "♪"
                    color: Services.Color.mOnSurfaceVariant
                    font.pixelSize: 10
                    visible: Services.MediaControlService.artUrl === ""
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

            // Keep the artwork stable across text transitions.
            Rectangle {
                id: nextArtworkSlot

                anchors.verticalCenter: parent.verticalCenter
                width: 18
                height: 18
                radius: 9
                color: root._artFallbackColor
                border.color: Qt.rgba(Services.Color.mOutline.r, Services.Color.mOutline.g, Services.Color.mOutline.b, 0.45)
                border.width: 1
                clip: true

                Image {
                    anchors.fill: parent
                    source: Services.MediaControlService.artUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: source !== ""
                    asynchronous: true
                    cache: false
                }

                Text {
                    anchors.centerIn: parent
                    text: "♪"
                    color: Services.Color.mOnSurfaceVariant
                    font.pixelSize: 10
                    visible: Services.MediaControlService.artUrl === ""
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
