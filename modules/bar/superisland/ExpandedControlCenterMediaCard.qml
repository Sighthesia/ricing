import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../media" as MediaParts

// Media control card for the SuperIsland control center page.
Rectangle {
    id: root

    function pageActivated() {
        _mediaEnterDelay.restart()
    }

    function pageDeactivated() {
        _mediaEnterDelay.stop()
        if (_mediaPanel && _mediaPanel.runExitAnimation)
            _mediaPanel.runExitAnimation()
    }

    radius: Theme.cornerRadius
    color: Qt.rgba(Colors.surface.r, Colors.surface.g, Colors.surface.b, 0.68)
    border.color: Qt.rgba(Colors.border.r, Colors.border.g, Colors.border.b, 0.72)
    border.width: 1
    implicitHeight: _contentColumn.implicitHeight + Theme.settingsPanelPadding * 2

    Timer {
        id: _mediaEnterDelay
        interval: Theme.anim.highlightDuration
        repeat: false
        onTriggered: {
            if (_mediaPanel && _mediaPanel.runEnterAnimation)
                _mediaPanel.runEnterAnimation()
        }
    }

    ColumnLayout {
        id: _contentColumn
        anchors.fill: parent
        anchors.margins: Theme.settingsPanelPadding
        spacing: 10

        ColumnLayout {
            spacing: 2

            Text {
                text: "媒体控制"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeBody
                font.weight: Font.Medium
                color: Colors.text
            }

            Text {
                text: MediaControlService.hasMedia
                    ? (MediaControlService.playerName || "媒体会话")
                    : "等待播放器接入"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                color: Colors.textMuted
                elide: Text.ElideRight
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: _mediaPanel.implicitHeight

            MediaParts.MediaPanelContent {
                id: _mediaPanel
                anchors.fill: parent
            }
        }
    }
}
