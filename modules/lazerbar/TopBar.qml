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
        property Item pendingLauncherOpener: null

        // Launcher palette bound explicitly at the mount site; independent of
        // old Wiki/News/Beatmap palettes and anchored on the osu pink family.
        readonly property var launcherPalette: ({
            kind: "pink",
            body: "#33202B",
            header: "#B23A62",
            sidebar: "#3A2531",
            light4: "#F492B8",
            light3: "#E56E97",
            dark4: "#AC3F63",
            dark3: "#75293F",
            text: "#FFF2F6",
            muted: "#D9BCC9",
            accent: LazerTheme.osuPink
        })
        readonly property var launcherContent: waveHost.contentItem
        readonly property string launcherTitle: launcherContent ? launcherContent.title : "Launcher"
        readonly property string launcherDescription: launcherContent ? launcherContent.description : ""

        function requestOverlay(target, opener) {
            musicTooltipOpen = false
            if (target === "launcher") {
                requestLauncher(opener)
                return
            }
            overlayCoordinator.request(target, opener)
        }

        // Launcher activation goes through the standalone service open path so
        // session visibility stays the single source of truth; the opener Item
        // is recorded for focus restoration once the surface closes.
        function requestLauncher(opener) {
            if (Services.LauncherService.visible) {
                if (overlayCoordinator.activeTarget === "launcher") {
                    // Opening an already-open launcher refocuses its live search
                    // session instead of creating a second surface instance.
                    if (launcherContent)
                        Qt.callLater(launcherContent.focusSearch)
                    return
                }
                overlayCoordinator.request("launcher", opener, true, true)
                return
            }
            pendingLauncherOpener = opener || null
            Services.LauncherService.open()
        }

        function syncLauncherSurface() {
            var service = Services.LauncherService
            if (service.visible) {
                overlayCoordinator.request("launcher", pendingLauncherOpener, true, true)
                // Opening grabs surface focus; land typing in the live search session.
                Qt.callLater(function() {
                    if (screenScope.launcherContent)
                        screenScope.launcherContent.focusSearch()
                })
            } else if (overlayCoordinator.activeTarget === "launcher") {
                overlayCoordinator.request("launcher")
            } else if (overlayCoordinator.transitioning && overlayCoordinator.pendingTarget === "launcher") {
                // The queued open is stale now that the session closed again.
                overlayCoordinator.pendingTarget = ""
            }
            pendingLauncherOpener = null
        }

        // Keyboard-shortcut IPC flips LauncherService visibility; mirror it onto
        // the wave surface so shortcuts open and close the same single instance.
        Connections {
            target: Services.LauncherService
            function onVisibleChanged() { screenScope.syncLauncherSurface() }
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
                if (owner === "wave") waveHost.openRoute(target, null)
                else if (owner === "settings") settingsOverlay.openFrom(null, true)
                else if (owner === "music") musicOverlay.open()
            }
            onCloseRequested: owner => {
                if (owner === "wave") waveHost.close()
                else if (owner === "settings") settingsOverlay.closeWithoutFocusRestore()
                else if (owner === "music") musicOverlay.close()
            }
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

        // Keep the launcher wave below the bar while only its internal viewport moves.
        PanelWindow {
            id: waveWindow
            screen: screenScope.modelData; color: "transparent"
            implicitWidth: screenScope.modelData.width; implicitHeight: screenScope.modelData.height
            exclusionMode: ExclusionMode.Ignore
            anchors { top: Services.SettingsService.bar.position === "top"; bottom: Services.SettingsService.bar.position === "bottom"; left: true }
            margins { top: Services.SettingsService.bar.position === "top" ? screenScope.floatingMargin + Services.SettingsService.bar.height : 0; bottom: Services.SettingsService.bar.position === "bottom" ? screenScope.floatingMargin + Services.SettingsService.bar.height : 0 }
            mask: Region { item: waveHost.visible ? waveHost : null }
            // Take keyboard only while the launcher is up so typing reaches its
            // search field and global keys stay free when closed.
            WlrLayershell.keyboardFocus: waveHost.interactive
                    ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WaveSurfaceHost {
                id: waveHost; anchors.fill: parent
                title: screenScope.launcherTitle
                description: screenScope.launcherDescription
                breadcrumb: "osu! / " + screenScope.launcherTitle
                sidebarEntries: screenScope.launcherContent ? screenScope.launcherContent.sidebarEntries : []
                activeSidebarId: screenScope.launcherContent ? screenScope.launcherContent.activeMode : ""
                palette: screenScope.launcherPalette
                contentComponent: launcherPageComponent
                onSidebarSelected: id => {
                    if (screenScope.launcherContent)
                        screenScope.launcherContent.handleModeSelected(id)
                }
                onClosed: {
                    overlayCoordinator.ownerClosed("wave")
                    if (Services.LauncherService.visible)
                        Services.LauncherService.close()
                }
            }
        }

        Component {
            id: launcherPageComponent
            LauncherPage { session: Services.LauncherService }
        }

        // Keep Settings in a dedicated left-side owner with no full-screen mask.
        PanelWindow {
            id: settingsWindow
            screen: screenScope.modelData; color: "transparent"
            implicitWidth: Math.min(LazerTheme.settingsPanelWidth, screenScope.modelData.width)
            implicitHeight: screenScope.modelData.height
            exclusionMode: ExclusionMode.Ignore
            anchors { top: Services.SettingsService.bar.position === "top"; bottom: Services.SettingsService.bar.position === "bottom"; left: true }
            margins { top: Services.SettingsService.bar.position === "top" ? screenScope.floatingMargin + Services.SettingsService.bar.height : 0; bottom: Services.SettingsService.bar.position === "bottom" ? screenScope.floatingMargin + Services.SettingsService.bar.height : 0 }
            mask: Region { item: screenScope.settingsMaskActive ? settingsOverlay : null }
            // Take keyboard only while settings is open so typing reaches its
            // text fields and global keys stay free when closed.
            WlrLayershell.keyboardFocus: settingsOverlay.interactive
                    ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
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
                radius: 0
                color: Qt.alpha(LazerTheme.bgDark, 0.93)
                opacity: screenScope.musicTooltipOpen ? 1 : 0
                transform: Translate {
                    y: MotionTokens.reducedMotion ? 0 : (screenScope.musicTooltipOpen ? 0 : 2)
                    Behavior on y { NumberAnimation { duration: MotionTokens.fast } }
                }
                Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
                Column {
                    anchors.centerIn: parent
                    spacing: 1
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: utilityContent.musicButtonItem.titleText; color: LazerTheme.textPrimary; font.pixelSize: 12; font.bold: true }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: utilityContent.musicButtonItem.subtitleText; color: LazerTheme.musicMuted; font.pixelSize: 10 }
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
