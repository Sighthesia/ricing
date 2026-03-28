//@ pragma UseQApplication
import Quickshell
import QtQuick
import qs.services
import qs.modules.bar
import qs.modules.background
import qs.modules.notifications

// Shell entry point. Instantiate top-level windows only and keep behavior in modules/services.
ShellRoot {
    id: root

    Component.onCompleted: {
        LauncherService.ensureInitialized()
    }

    Component {
        id: _normalShellContent

        Item {
            BackgroundWindow {}
            BarWindow {}
            ContextMenuBackdrop {}
            WidgetPickerWindow {}
            WallpaperPickerWindow {}
            NotificationPopupWindow {}
            MediaControlPanel {}
        }
    }

    Loader {
        active: true
        sourceComponent: _normalShellContent
    }
}
