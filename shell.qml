//@ pragma UseQApplication
import Quickshell
import qs.modules.bar
import qs.modules.background
import qs.modules.notifications
import qs.modules.launcher

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
