import QtQuick
import Quickshell
import Quickshell.Wayland
import "services" as Services
import "modules/background" as Background
import "modules/bar" as Bar
import "modules/island" as Island
import "modules/workspace-hint" as WorkspaceHint

// Keep the shell root minimal while layering reusable screen surfaces.
ShellRoot {
    // Sync managed compositor hotkeys, enumerate system fonts, and prewarm
    // the desktop entries cache (DesktopEntries.applications.values) so the
    // launcher's first search does not stall on cold-start desktop file I/O.
    Component.onCompleted: {
        Services.NiriService.syncManagedHotkeys()
        Services.FontService.init()
        DesktopEntries.applications.values; // prewarm cold cache
    }

    // Render wallpaper on each screen behind all other surfaces.
    Background.BackgroundWindow {
    }

    // Blurred/tinted wallpaper niri renders inside its overview backdrop.
    Background.OverviewBackgroundWindow {
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

    // Workspace/window hint OSD shown while mod key is held. Only the
    // floating-capsule layout uses this independent overlay; attached-island
    // mode extends the island itself (see IslandBody).
    Loader {
        active: Services.SettingsService.appearance.windowHintMode === "floating-capsule"
        sourceComponent: WorkspaceHint.WorkspaceHintWindow {
        }
    }

}
