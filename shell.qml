import QtQuick
import Quickshell
import "modules/lazerbar" as LazerBar

// Mount the lazer-inspired top bar as the shell's first visible surface.
ShellRoot {
    LazerBar.TopBar {
        username: "Sighthesia"
    }
}
