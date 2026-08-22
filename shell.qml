import QtQuick
import Quickshell
import "modules/lazerbar" as LazerBar

// Mount the desktop wallpaper behind the lazer top bar and notifications.
ShellRoot {
    LazerBar.WallpaperBackground {}

    LazerBar.TopBar {
        username: "Sighthesia"
    }

    LazerBar.NotificationHost {}
}
