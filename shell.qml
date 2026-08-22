import QtQuick
import Quickshell
import "modules/lazerbar" as LazerBar
import "modules/bar" as Bar

// Mount the desktop wallpaper behind the layout-driven top bar and notifications.
ShellRoot {
    LazerBar.WallpaperBackground {}

    Bar.TopBar {}

    LazerBar.NotificationHost {}
}
