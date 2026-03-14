//@ pragma UseQApplication
import Quickshell
import qs.modules.bar
import qs.modules.background
import qs.modules.notifications
import qs.modules.launcher

// Shell entry point. Instantiate top-level windows only and keep behavior in modules/services.
ShellRoot {
    BackgroundWindow {}
    BarWindow {}
    SettingsPanelWindow {}
    ContextMenuBackdrop {}
    WidgetPickerWindow {}
    WallpaperPickerWindow {}
    NotificationPopupWindow {}
    NotificationHistoryPanel {}
    LauncherPanel {}
    MediaControlPanel {}
}
