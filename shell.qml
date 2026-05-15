import QtQuick
import Quickshell
import Quickshell.Wayland
import "modules/background" as Background
import "modules/bar" as Bar
import "modules/notification" as Notification
import "modules/settings" as Settings

// Keep the shell root minimal while layering reusable screen surfaces.
ShellRoot {
    // Render wallpaper on each screen behind all other surfaces.
    Background.BackgroundWindow {
    }

    // Preserve the screen-corner overlays alongside the new center island.
    Background.ScreenCornerWindow {
    }

    // Render the reusable bar window for each screen.
    Bar.BarWindow {
    }

    // Context menu rendered in its own window to avoid bar-height clipping.
    Bar.BarContextMenu {
    }

    // Transient notification popups on overlay layer.
    Notification.NotificationWindow {
    }

    // Settings panel popup triggered from bar right-click.
    Settings.SettingsWindow {
    }

}
