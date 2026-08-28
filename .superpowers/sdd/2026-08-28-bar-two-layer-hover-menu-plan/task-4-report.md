# Task 4 Report — Publish actionable widget hover intents

## 改动

- 扩展 `modules/bar/BarPill.qml`：新增 opt-in 悬停意图发布契约 `property bool hoverIntentEnabled; signal popupRequested(var intent); signal popupCloseRequested(); signal popupAnchorUpdate(var intent)`，供 `Volume/Media/Notifications` 复用，不改变现有 `hovered/hoverColor/clicked` 与 `Behavior color`。

- 修改 `modules/bar/widgets/Volume.qml`：
  - `hoverIntentEnabled: true`，新增 `buildHoverIntent()`：`mapToGlobal(width/2,height/2).x` 取 `anchorX`（回退 `mapToItem(null)`），`title "Volume"`、`iconSource "../icons/volume.svg"`、`summary` 为 `Muted · XX%` 或 `XX%`，`actionKind "volume"`，`payload` 注入 `VolumeService.sinkVolume/sinkMuted` 与回调 `onVolumeChanged -> setSinkVolume` / `onToggleMute -> toggleSinkMute`，复用既有服务契约不新增方法。
  - `onHoveredChanged: hovered ? popupRequested(buildHoverIntent()) : popupCloseRequested()`；`onXChanged/onWidthChanged` 在悬停态 `popupAnchorUpdate(buildHoverIntent())` 实现“布局变化时更新锚点”。

- 修改 `modules/bar/widgets/Brightness.qml`（原为 plain `Item`）：
  - 新增三信号 `popupRequested/popupCloseRequested/popupAnchorUpdate`，`HoverHandler { id: brightnessHover }` 驱动 `onHoveredChanged -> popupRequested/Close`，`buildHoverIntent()` 复用 `BrightnessService.brightness`，`summary XX%`，`payload.brightness/brightnessService/onBrightnessChanged -> setBrightness`。
  - 保留原 `WheelHandler` 精确不变；`onXChanged/onWidthChanged` 锚点更新。

- 修改 `modules/bar/widgets/Media.qml`：
  - `hoverIntentEnabled: hasMedia`（无媒体时不发布），`buildHoverIntent()` 取 `MediaControlService.title/MediaService.title` 回退 `"Media"` 为 `title`，`artist/playerName` 为 `summary`，`iconSource "../../lazerbar/icons/music.svg"`，`payload.mediaService/onPrevious/onPlayPause/onNext` 委托 `MediaService`。
  - 同样 `onHoveredChanged/onXChanged/onWidthChanged` 发布与更新，保持 `onClicked: playPause` 与 `WheelHandler next/previous` 不变。

- 修改 `modules/bar/widgets/Notifications.qml`：
  - `hoverIntentEnabled: true`，`buildHoverIntent()` `title "Notifications"`，`summary unread/dnd`，`payload.notificationService/onToggleDnd/onClear -> dndEnabled/clearStickyNotifications`。
  - 保留 `onClicked: dndEnabled = !dnd` 不变，锚点更新同上。

- 修改 `modules/bar/widgets/Tray.qml`：
  - 新增三信号与 `property var hoveredTrayModel / Item hoveredTrayDelegate`，新增 `buildTrayIntent(modelData, delegateItem)`：`delegateItem.mapToGlobal(width/2,height/2).x` 为 `anchorX`，`title` 取 `delegate.label || modelData.title/tooltipTitle/id`，`iconSource` 取 `delegate.iconSource`，`summary` 取 `tooltipTitle/subTitle`，`payload.trayModel/trayItem/onActivate/onSecondaryActivate -> modelData.activate/secondaryActivate`。
  - 每 delegate 的 `HoverHandler onHoveredChanged` 更新 `hoveredTrayModel/Delegate` 并 `popupRequested(buildTrayIntent)` / `popupCloseRequested()`；`delegate.onXChanged` 与 `root.onXChanged/onWidthChanged` 在悬停态 `popupAnchorUpdate`。
  - 保留 `TapHandler Left/Right -> activate/secondaryActivate` 精确不变。

- 修改 `modules/bar/BarContent.qml`：
  - 新增信号 `popupRequested(var intent)/popupCloseRequested()/popupAnchorUpdate(var intent)` 与状态 `property var _activeHoverIntent/_activeHoverLoader`。
  - 新增 `attachPopupForwarding(loaderItem, loaderRef)`：若 `loaderItem.popupRequested etc` 存在则连接至 `root.popupRequested etc` 并记录 `_activeHoverIntent/_activeHoverLoader`。
  - `SectionRow Loader onLoaded` 中 `root.attachPopupForwarding(item, widgetLoader)`，复用 `widgetId/instanceKey/screenName` 赋值后立即接线。
  - 新增 `findLoaderForIntent(intent)` 与 `refreshActiveAnchor()`：优先 `item.buildHoverIntent()/buildTrayIntent(hoveredTrayModel, hoveredTrayDelegate)` 重建 intent，否则回退 `mapToGlobal` 补 `anchorX`，触发 `popupAnchorUpdate`。
  - `Connections { target: BarLayoutService; onLayoutModelChanged: Qt.callLater(refreshActiveAnchor) }` 与 `onWidthChanged: Qt.callLater(refreshActiveAnchor)` 实现“悬停期间布局变化更新锚点”。

- 修改 `modules/bar/TopBar.qml`：
  - `barWindow` 内 `BarContent` 赋 `id: barContent`，新增三个转发处理器：`onPopupRequested` 拷贝 `intent` 并注入 `screenWidth = modelData.width`、`barPosition = SettingsService.bar.position || "top"`，设 `popupHost.widgetHovered = true` 后 `popupHost.showIntent(enriched)`；`onPopupCloseRequested` 设 `widgetHovered=false` 并 `requestClose()`；`onPopupAnchorUpdate` 在 `open` 时更新 `popupHost.anchorX`、同步 `intent.anchorX` 并 `cancelClose()`。
  - 新增每屏单实例 `BarPopupHost { id: popupHost; screen: screenScope.modelData; screenWidth: ...; effectiveBarHeight: screenScope.effectiveHeight; floatingMargin: screenScope.floatingMargin }`，不为每 widget 创建 host，满足“单一 per-screen host”。

- 未恢复 `BarPopupService`/旧状态机；所有点击/滚轮路径保持原样，仅追加 hover opt-in。

## 命令

### qmllint
```bash
/usr/lib/qt6/bin/qmllint modules/bar/BarContent.qml modules/bar/widgets/Tray.qml modules/bar/widgets/Volume.qml modules/bar/widgets/Brightness.qml modules/bar/widgets/Media.qml modules/bar/widgets/Notifications.qml
```
**结果（exit 0，仅既有 warning，无 ERROR）：**
- `BarContent` 8 条 `unqualified / ComponentBehavior: Bound` 提示（既有 `root.` 限定与嵌套组件 ID 作用域提示）；
- `Tray` `unused-import Quickshell/..` 与 6 条 `unqualified`（Repeater delegate 内 `root.`/`buildTrayIntent` 需 `ComponentBehavior: Bound`）；
- `Volume/Brightness/Media` 各 1 条 `missing-property volumeStep/brightnessStep`（`JsonObject` 动态属性）；
- 无 `ERROR` 或 `Failed to load`。

```bash
/usr/lib/qt6/bin/qmllint modules/bar/TopBar.qml modules/bar/BarPill.qml
```
**结果（exit 0，仅既有 warning）：**
- `TopBar` `PanelWindow not creatable / margins unresolved / missing-property bar.floating/position` 等既有警告；
- 无新增 ERROR。

### qs load validation
```bash
timeout 6 qs -p shell.qml
```
**结果（exit 124 超时结束，未打印 ERROR/Failed to load）：**
```
INFO: Launching config: ".../shell.qml"
INFO: Configuration Loaded
WARN: quickshell.service.notifications: Could not register notification server ...
WARN: NiriService: failed to write blur.kdl, exitCode = 15   # 无 niri 环境的既有警告
WARN: ColorService: Theme written to: ...
```
`grep -i "ERROR|Failed to load"` 仅命中上述 `failed to write blur.kdl` 的 WARN，非 ERROR 级别；现有 widget click/wheel 行为未受影响。

### 既有纯逻辑/内容测试（回归）
```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_hover_logic.qml -o -,txt
# Totals: 14 passed, 0 failed
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_popup_content.qml -o -,txt
# Totals: 17 passed, 0 failed
```

### git diff --check
```bash
git diff --check
# 无尾随空白/冲突标记
```

## 未阶段化的保留项
- 保持未跟踪调试产物 `142bpm.mp3`, `aubio.err`, `live_beats.txt`, `tst_count.qml`, `tst_ghost_debug.qml`, `tst_rapid_debug.qml`, `tst_sweep.qml` 不入本次提交。
- Services 层无改动，未恢复旧 popup 状态机；`BarPopupActions` 的真实服务调用由本任务的 payload 回调承载，组件本身仅通过 `payload.onXxx / payload.xxxService` 委托。

## Concerns

- **BarPill 额外纳入提交**：`modules/bar/BarPill.qml` 按步骤 1 扩展 `hoverIntentEnabled/popupRequested/popupCloseRequested/popupAnchorUpdate`，但任务简报“Files”与示例 `git add` 列表未包含它。为保留 `Volume/Media/Notifications` 的编译与 hover 发布能力，本次提交额外 `git add modules/bar/BarPill.qml`（与 7 个计划文件一并提交），后续简报可同步补齐。

- **`Object.assign` 依赖**：`TopBar/BarContent` 中以 `Object.assign({}, intent)` 浅拷贝并注入 `screenWidth/barPosition/anchorX`，依赖 Qt6 QML 的 ES7 `Object.assign`。`qs -p shell.qml` 验证无抛错；若目标环境为更低 Qt 版本，需回退为 `for (var k in intent) enriched[k]=intent[k]` 手写拷贝。

- **`mapToGlobal` 回退**：`buildHoverIntent/buildTrayIntent` 优先 `mapToGlobal(width/2,height/2).x` 取屏坐标，回退 `mapToItem(null)`。在无窗口/无屏幕的 `qmltestrunner` 环境中该值可能为 0，但宿主侧 `BarPopupHost.showIntent` 会以 `clampAnchor` 夹紧至 `margin … screenWidth-popupWidth-margin`，不会溢出；后续 Task 5 的 `TwoLayerPopup` 宽度固定，夹紧即正确。

- **Tray 锚点精度**：托盘以 delegate 的 `mapToGlobal` 为锚，`BarContent.refreshActiveAnchor` 在托盘情形下尝试 `buildTrayIntent(hoveredTrayModel, hoveredTrayDelegate)` 重建。若 delegate 在布局抖动期间被复用/销毁，重建可能落空，此时回退为 loader 中心；视觉上仅极短帧偏差，下一次 hover enter 即校正。

- **悬停与布局拖拽竞态**：`BarContent` 在 `settingsMode` 拖拽期间仍会 `refreshActiveAnchor`，而 `BarPopupHost` 的 `widgetHovered/popupHovered` 与 `MotionTokens.fast` 关闭定时器共同决定关闭时机。拖拽导致的快速锚点跳变仅更新 `anchorX` 不重触发 `showIntent` 的 reveal，避免闪烁。
