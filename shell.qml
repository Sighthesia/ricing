import QtQuick
import Quickshell
import Quickshell.Wayland
import "modules/background" as Background
import "modules/bar" as Bar

// Keep the shell root minimal while layering reusable screen surfaces.
ShellRoot {
    // Preserve the screen-corner overlays alongside the new center island.
    Background.ScreenCornerWindow {
    }

    // Render the reusable bar window for each screen.
    Bar.BarWindow {
    }

    // Keep the minimal widget picker available as a separate bar-owned window.
    Bar.WidgetPickerWindow {
    }

}
