import QtQuick
import Quickshell
import Quickshell.Wayland
import "../lazerbar"
import "../../services" as Services

// Mount the layout-driven bar plus the launcher wave owner per screen.
Variants {
    model: Quickshell.screens

    Scope {
        id: screenScope

        required property var modelData

        // Keep the theme's bar metrics tracking settings; the singleton itself
        // stays service-free so component suites run without Quickshell.
        Binding {
            target: LazerTheme
            property: "barHeightSetting"
            value: Services.SettingsService.bar.height
        }

        readonly property bool floating: Services.SettingsService.bar.floating
        readonly property int floatingMargin: floating
                ? Math.max(0, Math.min(24, Number(Services.SettingsService.bar.floatingMargin) || 0)) : 0
        readonly property int effectiveHeight:
            Math.max(40, Math.min(64, Number(Services.SettingsService.bar.height) || 48))

        // Desktop-blocking mask only when the debug override demands it.
        readonly property bool settingsMaskActive:
            Services.SettingsService.settingsMaskOverride !== "off"
            && settingsOverlay.blocksDesktop

        // Serialize launcher transitions; settings/music owners live elsewhere.
        OverlayCoordinator {
            id: overlayCoordinator
            onOpenRequested: (owner, target) => {
                if (owner === "wave") launcherSurface.host.openRoute(target, null)
                else if (owner === "settings") settingsOverlay.openFrom(null, true)
            }
            onCloseRequested: owner => {
                if (owner === "wave") launcherSurface.host.close()
                else if (owner === "settings") settingsOverlay.closeWithoutFocusRestore()
            }
        }

        // Bar-side open intents (gear button) join the same serialized path.
        Connections {
            target: SettingsOverlayBridge
            function onOpenRequested() {
                overlayCoordinator.request("settings", null, true)
            }
        }

        PanelWindow {
            id: barWindow

            screen: screenScope.modelData
            color: "transparent"
            implicitHeight: screenScope.effectiveHeight
            exclusiveZone: screenScope.floating ? 0 : implicitHeight
            anchors { top: Services.SettingsService.bar.position === "top"; bottom: Services.SettingsService.bar.position === "bottom"; left: true; right: true }
            margins { top: screenScope.floatingMargin; bottom: screenScope.floatingMargin; left: screenScope.floatingMargin; right: screenScope.floatingMargin }

            // Paint the continuous sharp bar silhouette behind every widget.
            Rectangle {
                anchors.fill: parent
                radius: 0
                color: Services.SettingsService.appearance.colorScheme === "light" ? "#F2F0F5" : LazerTheme.bgDark
                opacity: Math.max(0.35, Math.min(1, Services.SettingsService.panelSurfaceOpacity))

                Behavior on color { ColorAnimation { duration: MotionTokens.fast } }
                Behavior on opacity { NumberAnimation { duration: MotionTokens.fast } }
            }

            BarContent {
                anchors.fill: parent
                screenName: screenScope.modelData ? String(screenScope.modelData.name || "") : ""
            }
        }

        // Hover popups live in their own overlay owner so menu/slider content
        // can escape the bar silhouette without resizing the bar surface.
        // Input stays limited to the visible popup via a mask region.
        PanelWindow {
            id: popupWindow

            screen: screenScope.modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: -1
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.layer: WlrLayer.Overlay
            // Take keyboard only while a popup is up so Escape reaches it and
            // global keys stay free when closed.
            WlrLayershell.keyboardFocus: Services.BarPopupService.visible
                    ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            mask: Region {
                item: popupHost.revealProgress > 0 ? popupHost.activeSurfaceItem : null
            }

            BarPopupHost {
                id: popupHost

                anchors.fill: parent
                barHeight: screenScope.effectiveHeight
                barTopAnchored: Services.SettingsService.bar.position === "top"
                floatingMargin: screenScope.floatingMargin
            }
        }

        // Keep the launcher wave below the bar while only its internal viewport moves.
        PanelWindow {
            id: launcherWindow
            screen: screenScope.modelData; color: "transparent"
            implicitWidth: screenScope.modelData.width; implicitHeight: screenScope.modelData.height
            exclusionMode: ExclusionMode.Ignore
            anchors { top: Services.SettingsService.bar.position === "top"; bottom: Services.SettingsService.bar.position === "bottom"; left: true }
            // Offset by the same clamped height the bar actually renders at.
            margins { top: Services.SettingsService.bar.position === "top" ? screenScope.floatingMargin + screenScope.effectiveHeight : 0; bottom: Services.SettingsService.bar.position === "bottom" ? screenScope.floatingMargin + screenScope.effectiveHeight : 0 }
            mask: Region { item: launcherSurface.host.visible ? launcherSurface.host : null }
            // Take keyboard only while the launcher is up so typing reaches its
            // search field and global keys stay free when closed.
            WlrLayershell.keyboardFocus: launcherSurface.host.interactive
                    ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            LauncherSurface {
                id: launcherSurface; anchors.fill: parent
                coordinator: overlayCoordinator
                session: Services.LauncherService
            }
        }

        // Keep Settings in a dedicated left-side owner with no full-screen mask.
        PanelWindow {
            id: settingsWindow
            screen: screenScope.modelData; color: "transparent"
            implicitWidth: Math.min(LazerTheme.settingsPanelWidth, screenScope.modelData.width)
            implicitHeight: screenScope.modelData.height
            exclusionMode: ExclusionMode.Ignore
            anchors { top: Services.SettingsService.bar.position === "top"; bottom: Services.SettingsService.bar.position === "bottom"; left: true }
            margins { top: Services.SettingsService.bar.position === "top" ? screenScope.floatingMargin + screenScope.effectiveHeight : 0; bottom: Services.SettingsService.bar.position === "bottom" ? screenScope.floatingMargin + screenScope.effectiveHeight : 0 }
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
    }
}
