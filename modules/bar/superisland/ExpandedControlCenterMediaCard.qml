import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import ".." as BarComponents
import "../media" as MediaParts

// Media surface for the SuperIsland control center page.
BarComponents.FloatingShellSurface {
    id: root

    function pageActivated() {
        _mediaEnterDelay.restart()
    }

    function pageDeactivated() {
        _mediaEnterDelay.stop()
        if (_mediaPanel && _mediaPanel.runExitAnimation)
            _mediaPanel.runExitAnimation()
    }

    implicitWidth: ThemeCards.popupCardWidth
    implicitHeight: _contentColumn.implicitHeight + ThemeCards.panelPadding * 2
    contentMargin: ThemeCards.panelPadding

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
        anchors.margins: 0
        spacing: ThemeCards.compactGap

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
