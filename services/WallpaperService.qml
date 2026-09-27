pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Own wallpaper state via SettingsService, trigger color extraction on change.
QtObject {
    id: root

    readonly property string currentWallpaper: SettingsService.appearance.wallpaperPath
    signal wallpaperChanged(string path)

    // Global point (screen coordinates) the next wallpaper reveal grows from.
    // Null means the screen centre. It is published before the key write so
    // every screen picks it up during the same change notification, and the
    // wallpaper surface clears it once the reveal has consumed it.
    property var revealOrigin: null

    // `origin` is the pointer position that asked for the switch, in screen
    // coordinates; omit it to reveal from the screen centre.
    function changeWallpaper(path, origin) {
        if (!path || path === SettingsService.appearance.wallpaperPath) return
        root.revealOrigin = origin ? Qt.point(Number(origin.x), Number(origin.y)) : null
        SettingsService.appearance.wallpaperPath = path
        SettingsService.save()
    }

    // Single handler for all wallpaperPath changes (from changeWallpaper, settings panel, or file edit)
    property Connections _conn: Connections {
        target: SettingsService.appearance
        function onWallpaperPathChanged() {
            var path = SettingsService.appearance.wallpaperPath
            if (path) {
                root.wallpaperChanged(path)
                ColorService.extractColors(path)
            }
        }
    }
}
