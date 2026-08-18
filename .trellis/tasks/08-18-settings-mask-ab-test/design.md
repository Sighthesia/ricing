# Technical Design

## State Ownership

将诊断状态放在 `SettingsService` 的内存属性中，因为它已经拥有 Settings IPC；状态不进入 adapter、JsonAdapter 或任何 persisted settings object。

```qml
property string settingsMaskOverride: "auto"
property IpcHandler ipc: IpcHandler {
    function maskOverride(mode: string) { root.setSettingsMaskOverride(mode) }
}
```

`setSettingsMaskOverride()` 只接受 `auto`、`on`、`off`，并递增诊断 token、输出日志。

## Data Flow

`qs ipc call settings maskOverride off`
-> `SettingsService.settingsMaskOverride`
-> `TopBar.screenScope`
-> `settingsWindow.mask`
-> Wayland input region。

Effective mask expression:

```qml
mask: Region {
    item: settingsMaskActive ? settingsOverlay : null
}
```

其中 `settingsMaskActive` 为 `override === "off" ? false : settingsOverlay.blocksDesktop`；`on` 只在 overlay active 时使用 settingsOverlay，避免 closed 状态创建无意义 mask。

## Safety And Rollback

- 默认 `auto`，与当前代码等价。
- override 只用于诊断，关闭 shell 即清除。
- 不增加新的输入捕获层，不改变 QML scene geometry。
- 实验完成后可删除 IPC、属性和 TopBar binding，回滚边界集中在 `SettingsService.qml` 与 `TopBar.qml`。

## Verification

- `qs ipc -p . show` 确认函数。
- `qs ipc -p . call settings maskOverride auto|on|off` 后检查日志。
- `qs ipc -p . call settings openHoverDebug eDP-1` 与 `snapshotHover` 记录同一 overlay 状态。
- 使用 Wayland pointer 注入工具将鼠标移动到已知 scene 坐标，比较 mask on/off 时 Row/control hover。
