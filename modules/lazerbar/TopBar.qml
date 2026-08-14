import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services" as Services

// Create one background and three focused interaction zones per screen.
Variants {
    id: root
    property string username: "Sighthesia"
    property url avatarSource
    model: Quickshell.screens

    // Own the persistent surfaces for one compositor screen.
    Scope {
        id: screenScope
        required property var modelData
        readonly property int sidePadding: 12
        readonly property int safetyGap: 16
        readonly property int utilityBudget: Math.max(LazerTheme.targetSize,
            modelData.width - leftWindow.implicitWidth - statusWindow.implicitWidth
            - sidePadding * 2 - safetyGap * 2)
        property bool musicOverlayOpen: false
        property bool musicTooltipOpen: false
        property bool shuffleActive: false

        BarBackground { targetScreen: screenScope.modelData }

        // Host system and mode controls at the left edge.
        PanelWindow {
            id: leftWindow
            screen: screenScope.modelData
            color: "transparent"
            implicitWidth: leftContent.implicitWidth + screenScope.sidePadding * 2
            implicitHeight: LazerTheme.barHeight
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true }
            LeftZone { id: leftContent; anchors.centerIn: parent }
        }

        // Host utilities against the status zone without a full-width hit area.
        PanelWindow {
            id: utilityWindow
            screen: screenScope.modelData
            color: "transparent"
            implicitWidth: utilityContent.implicitWidth + screenScope.sidePadding * 2
            implicitHeight: LazerTheme.barHeight
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; right: true }
            margins { right: statusWindow.implicitWidth + screenScope.safetyGap }
            UtilityZone {
                id: utilityContent
                anchors.centerIn: parent
                availableWidth: screenScope.utilityBudget - screenScope.sidePadding * 2
                musicActive: screenScope.musicOverlayOpen
                onMusicOverlayRequested: open => {
                    screenScope.musicOverlayOpen = open
                    screenScope.musicTooltipOpen = false
                    if (open) musicOverlay.open()
                    else musicOverlay.close()
                }
                onMusicTooltipRequested: visible => screenScope.musicTooltipOpen = visible && !screenScope.musicOverlayOpen
            }
        }

        // Host the fixed player card without reserving compositor workspace.
        PanelWindow {
            id: musicWindow
            screen: screenScope.modelData
            color: "transparent"
            implicitWidth: 340
            implicitHeight: 134
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; right: true }
            margins { top: LazerTheme.barHeight + 4; right: statusWindow.implicitWidth + screenScope.safetyGap }
            mask: Region { item: musicOverlay.interactive ? musicHitArea : null }
            Item { id: musicHitArea; anchors.fill: musicOverlay }
            OsuMusicOverlay {
                id: musicOverlay
                anchors.top: parent.top
                titleText: Services.MediaControlService.hasMedia ? Services.MediaControlService.title : "暂无播放内容"
                artistText: Services.MediaControlService.hasMedia ? Services.MediaControlService.artist : ""
                playing: Services.MediaControlService.playbackState === "playing"
                progress: Services.MediaControlService.progress
                shuffleActive: screenScope.shuffleActive
                canGoPrevious: Services.MediaControlService.canGoPrevious
                canTogglePlayback: Services.MediaControlService.canTogglePlayback
                canGoNext: Services.MediaControlService.canGoNext
                onShuffleRequested: active => screenScope.shuffleActive = active
                onPreviousRequested: Services.MediaService.previous()
                onPlayPauseRequested: Services.MediaService.playPause()
                onNextRequested: Services.MediaService.next()
                onCloseRequested: {
                    screenScope.musicOverlayOpen = false
                    close()
                    utilityContent.musicButtonItem.forceActiveFocus()
                }
            }
        }

        // Show the music button's delayed two-line tooltip in its own surface.
        PanelWindow {
            id: tooltipWindow
            screen: screenScope.modelData
            color: "transparent"
            implicitWidth: 150
            implicitHeight: 48
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; right: true }
            margins { top: LazerTheme.barHeight + 4; right: statusWindow.implicitWidth + screenScope.safetyGap }
            mask: Region {}
            Rectangle {
                anchors.fill: parent
                radius: 7
                color: "#EE202129"
                opacity: screenScope.musicTooltipOpen ? 1 : 0
                transform: Translate { y: MotionTokens.reducedMotion ? 0 : (screenScope.musicTooltipOpen ? 0 : 2) }
                Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
                Column {
                    anchors.centerIn: parent
                    spacing: 1
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "音乐播放器"; color: "white"; font.pixelSize: 12; font.bold: true }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "播放控制"; color: LazerTheme.musicMuted; font.pixelSize: 10 }
                }
            }
        }

        // Host profile and system status at the right edge.
        PanelWindow {
            id: statusWindow
            screen: screenScope.modelData
            color: "transparent"
            implicitWidth: statusContent.implicitWidth + screenScope.sidePadding * 2
            implicitHeight: LazerTheme.barHeight
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; right: true }
            StatusZone {
                id: statusContent
                anchors.centerIn: parent
                username: root.username
                avatarSource: root.avatarSource
            }
        }
    }
}
