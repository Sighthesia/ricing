import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services" as Services

// Create the bar and three independently sized overlay owners per screen.
Variants {
    id: root
    property string username: "Sighthesia"
    property url avatarSource
    model: Quickshell.screens

    // Coordinate one screen's overlay state without mixing their visual containers.
    Scope {
        id: screenScope
        required property var modelData
        readonly property int sidePadding: 12
        readonly property int safetyGap: 16
        readonly property int floatingMargin: Services.SettingsService.bar.floating
                ? Math.max(0, Math.min(24, Number(Services.SettingsService.bar.floatingMargin) || 0)) : 0
        readonly property int utilityBudget: Math.max(LazerTheme.targetSize,
            modelData.width - leftWindow.implicitWidth - statusWindow.implicitWidth
            - sidePadding * 2 - safetyGap * 2)
        readonly property bool settingsMaskActive:
            Services.SettingsService.settingsMaskOverride !== "off"
            && settingsOverlay.blocksDesktop
        readonly property string activeOverlay: overlayCoordinator.activeTarget
        property bool musicTooltipOpen: false
        property bool shuffleActive: false

        function requestOverlay(target, opener) {
            musicTooltipOpen = false
            overlayCoordinator.request(target, opener)
        }

        // Route explicit diagnostics through the same coordinator as the bar button.
        Connections {
            target: Services.SettingsService
            function onHoverDebugOpenTokenChanged() {
                if (Services.SettingsService.hoverDebugEnabled
                        && screenScope.modelData.name === Services.SettingsService.hoverDebugOpenScreen) {
                    settingsOverlay.prepareDebugOpen()
                    if (Services.SettingsService.hoverDebugCategory.length > 0)
                        settingsOverlay.panel.selectedCategory = Services.SettingsService.hoverDebugCategory
                    overlayCoordinator.request("settings", null, true, true)
                }
            }
        }

        OverlayCoordinator {
            id: overlayCoordinator
            onOpenRequested: (owner, target) => {
                if (owner === "wave") fullscreenHost.openRoute(target, null)
                else if (owner === "settings") settingsOverlay.openFrom(null, true)
                else if (owner === "music") musicOverlay.open()
            }
            onCloseRequested: owner => {
                if (owner === "wave") fullscreenHost.close()
                else if (owner === "settings") settingsOverlay.closeWithoutFocusRestore()
                else if (owner === "music") musicOverlay.close()
            }
            onRouteRequested: target => fullscreenHost.openRoute(target, null)
        }

        BarBackground { targetScreen: screenScope.modelData }

        // Host system and mode controls at the left edge.
        PanelWindow {
            id: leftWindow
            screen: screenScope.modelData; color: "transparent"
            implicitWidth: leftContent.implicitWidth + screenScope.sidePadding * 2
            implicitHeight: Math.max(40, Math.min(64, Number(Services.SettingsService.bar.height) || 48))
            exclusionMode: ExclusionMode.Ignore
            anchors { top: Services.SettingsService.bar.position === "top"; bottom: Services.SettingsService.bar.position === "bottom"; left: true }
            margins { top: screenScope.floatingMargin; bottom: screenScope.floatingMargin; left: screenScope.floatingMargin }
            LeftZone { id: leftContent; anchors.centerIn: parent; settingsActive: screenScope.activeOverlay === "settings"; onSettingsRequested: screenScope.requestOverlay("settings", settingsButtonItem) }
        }

        // Host utilities against the status zone without a full-width hit area.
        PanelWindow {
            id: utilityWindow
            screen: screenScope.modelData; color: "transparent"
            implicitWidth: utilityContent.implicitWidth + screenScope.sidePadding * 2
            implicitHeight: Math.max(40, Math.min(64, Number(Services.SettingsService.bar.height) || 48))
            exclusionMode: ExclusionMode.Ignore
            anchors { top: Services.SettingsService.bar.position === "top"; bottom: Services.SettingsService.bar.position === "bottom"; right: true }
            margins { top: screenScope.floatingMargin; bottom: screenScope.floatingMargin; right: statusWindow.implicitWidth + screenScope.safetyGap + screenScope.floatingMargin }
            UtilityZone {
                id: utilityContent; anchors.centerIn: parent
                availableWidth: screenScope.utilityBudget - screenScope.sidePadding * 2
                musicActive: screenScope.activeOverlay === "music"
                onMusicOverlayRequested: screenScope.requestOverlay("music", musicButtonItem)
                onRouteRequested: (route, opener) => { if (route) screenScope.requestOverlay(route, opener) }
                onMusicTooltipRequested: visible => screenScope.musicTooltipOpen = visible && screenScope.activeOverlay !== "music"
            }
        }

        // Keep the wave owner screen-sized while only its internal viewport moves.
        PanelWindow {
            id: waveWindow
            screen: screenScope.modelData; color: "transparent"
            implicitWidth: screenScope.modelData.width; implicitHeight: screenScope.modelData.height
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true }
            mask: Region { item: fullscreenHost.visible ? fullscreenHost : null }
            FullscreenOverlayHost {
                id: fullscreenHost; anchors.fill: parent
                barPosition: Services.SettingsService.bar.position
                barHeight: Services.SettingsService.bar.height
                onClosed: overlayCoordinator.ownerClosed("wave")
            }
        }

        // Keep Settings in a dedicated left-side owner with no full-screen mask.
        PanelWindow {
            id: settingsWindow
            screen: screenScope.modelData; color: "transparent"
            implicitWidth: Math.min(LazerTheme.settingsPanelWidth, screenScope.modelData.width)
            implicitHeight: screenScope.modelData.height
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true }
            mask: Region { item: screenScope.settingsMaskActive ? settingsOverlay : null }
            LazerSettingsOverlay {
                id: settingsOverlay; anchors.fill: parent
                panel.appearanceSettings: Services.SettingsService.appearance
                panel.barSettings: Services.SettingsService.bar
                panel.notificationSettings: Services.SettingsService.notifications
                panel.saveCallback: Services.SettingsService.save
                panel.appearanceDefaults: Services.SettingsService.appearanceDefaults
                panel.barDefaults: Services.SettingsService.barDefaults
                panel.notificationDefaults: Services.SettingsService.notificationDefaults
                panel.settingsReset: Services.SettingsService.resetCategorySetting
                panel.wallpaperService: Services.WallpaperService
                debugHoverEnabled: Services.SettingsService.hoverDebugEnabled
                debugHoverToken: Services.SettingsService.hoverDebugToken
                debugMaskOverride: Services.SettingsService.settingsMaskOverride
                debugMaskActive: screenScope.settingsMaskActive
                debugScreenName: screenScope.modelData && screenScope.modelData.name
                        ? String(screenScope.modelData.name) : "unknown"
                onClosed: overlayCoordinator.ownerClosed("settings")
            }
        }

        // Keep Now Playing local to the music entry instead of the wave viewport.
        PanelWindow {
            id: musicWindow
            screen: screenScope.modelData; color: "transparent"
            implicitWidth: 340; implicitHeight: 130
            exclusionMode: ExclusionMode.Ignore
            anchors { top: Services.SettingsService.bar.position === "top"; bottom: Services.SettingsService.bar.position === "bottom"; right: true }
            margins { top: Services.SettingsService.bar.position === "top" ? Services.SettingsService.bar.height + 4 : 4; bottom: Services.SettingsService.bar.position === "bottom" ? Services.SettingsService.bar.height + 4 : 4; right: statusWindow.implicitWidth + screenScope.safetyGap }
            mask: Region { item: musicOverlay.openState || musicOverlay.openProgress > 0 ? musicOverlay : null }
            OsuMusicOverlay {
                id: musicOverlay; anchors.fill: parent
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
                onCloseRequested: screenScope.requestOverlay("music", utilityContent.musicButtonItem)
                onClosed: overlayCoordinator.ownerClosed("music")
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
            anchors { top: Services.SettingsService.bar.position === "top"; bottom: Services.SettingsService.bar.position === "bottom"; right: true }
            margins { top: Services.SettingsService.bar.position === "top" ? Services.SettingsService.bar.height + 4 : 4; bottom: Services.SettingsService.bar.position === "bottom" ? Services.SettingsService.bar.height + 4 : 4; right: statusWindow.implicitWidth + screenScope.safetyGap }
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
            screen: screenScope.modelData; color: "transparent"
            implicitWidth: statusContent.implicitWidth + screenScope.sidePadding * 2
            implicitHeight: Math.max(40, Math.min(64, Number(Services.SettingsService.bar.height) || 48))
            exclusionMode: ExclusionMode.Ignore
            anchors { top: Services.SettingsService.bar.position === "top"; bottom: Services.SettingsService.bar.position === "bottom"; right: true }
            StatusZone { id: statusContent; anchors.centerIn: parent; username: root.username; avatarSource: root.avatarSource }
        }
    }
}
