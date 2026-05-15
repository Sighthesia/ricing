pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Own wallpaper state via SettingsService, trigger color extraction on change.
QtObject {
    id: root

    readonly property string currentWallpaper: SettingsService.appearance.wallpaperPath
    signal wallpaperChanged(string path)

    function changeWallpaper(path) {
        if (!path || path === SettingsService.appearance.wallpaperPath) return
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
