import QtQuick
import Quickshell
import Quickshell.Wayland
import "modules/background" as Background
import "modules/bar" as Bar
import "modules/island" as Island
import "modules/notification" as Notification
import "modules/osd" as Osd
import "modules/settings" as Settings
import "modules/launcher" as Launcher
import "modules/workspace-hint" as WorkspaceHint

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

    // Dynamic Island: center content owner (collapsed clock + expanded launcher).
    Island.IslandWindow {
    }

    // Context menu rendered in its own window to avoid bar-height clipping.
    Bar.BarContextMenu {
    }

    // Widget picker rendered in its own window so empty sections can recover widgets.
    Bar.WidgetPickerWindow {
    }

    // Transient notification popups on overlay layer.
    Notification.NotificationWindow {
    }

    // OSD popup for volume/brightness/media feedback.
    Osd.OsdWindow {
    }

    // Settings panel popup triggered from bar right-click.
    Settings.SettingsWindow {
    }

    // Full-screen launcher overlay triggered from context menu.
    Launcher.LauncherWindow {
    }

    // Workspace/window hint OSD shown while mod key is held.
    WorkspaceHint.WorkspaceHintWindow {
    }

}
