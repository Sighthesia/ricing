# Task 2 Report — Build the per-screen BarPopupHost

## 改动
- 修改 `modules/bar/BarPopupHost.qml`：由占位 `Item` 重建为固定几何的 `PanelWindow` 宿主，满足简报接口与生命周期：
  - 消费 intent `{ widgetId, instanceKey, title, iconSource, summary, actionKind, anchorX, screenWidth, barPosition }`，暴露 `intent`, `open`, `widgetHovered`, `popupHovered`, `direction`, `anchorX`, `screenWidth`，信号 `actionRequested(string)`, `closeRequested()`，方法 `showIntent(intent)`, `requestClose()`, `cancelClose()`。
  - 固定 PanelWindow：`exclusionMode: ExclusionMode.Ignore`、`color: "transparent"`、`implicitWidth/Height` 为屏幕宽度/高度（`screen ? screen.width : screenWidth`），`anchors` 随 `direction` 锚到与 bar 同侧（`down`→`top`、`up`→`bottom`），`margins` 偏移 `effectiveBarHeight + floatingMargin`，窗口尺寸全程固定，per-frame 不触及 layer-shell commit。
  - 内层 `Item` 承载 `TwoLayerPopup { orientation: Vertical; direction: direction==="up"?Up:Down }`，`x` 由 `BarHoverLogic.clampAnchor(anchorX, width, screenWidth, 8)` 计算，`y=0`（窗口已偏移），`mask: Region { item: open ? popupContainer : null }` 在关闭时禁用输入。
  - Hover 桥接与关闭计时：`requestClose()` 启动 `MotionTokens.fast` 计时器，`cancelClose()` 停止；计时触发时仅当 `BarHoverLogic.shouldClose(widgetHovered, popupHovered, true)` 为真才 `open=false`、`closeRequested()`、`popup.revealProgress=0`；非阻塞 `HoverHandler` 负责 `popupHovered`，`widgetHovered` 由外部 owner 驱动。
  - 清理：退出 reveal 完成后（`popup.revealDuration+40`）才 `intent=null`，保证淡出层完整；`sidebarData`/`contentData` 以 alias 直通 `TwoLayerPopup`，宿主本身保持空内容，Task 3 再注入操作。
  - 未恢复 `BarPopupService`、`BarTrayMenu`、`BarContextMenu`、`WidgetHoverPopup` 等旧状态机；仅复用 `BarHoverLogic` 与 `MotionTokens`/`TwoLayerPopup`。
- 修改 `modules/bar/qmldir`：新增 `BarPopupHost 1.0 BarPopupHost.qml` 注册，其余条目保持不变。
- 新建 `tst_bar_popup_host.qml`（repo 根）：qs 行为 harness，按 qml-testing skill 规范以 `Qt.callLater` 分步执行、Timer 等待关闭延迟、打印 `PASS`/`Totals` 并以 `Qt.quit()` 结束：
  - 注入 `top` intent 断言 `open`、`direction==="down"`、`popupItem.direction===Down`、`anchorX/screenWidth/intent`、`sidebarData/contentData` 存在；
  - 切换 `bottom` intent 断言 `direction==="up"`、`popupItem.direction===Up`、`orientation===Vertical` 且保持 `open`；
  - `widgetHovered=false, popupHovered=true` 时 `requestClose` 后等待 `MotionTokens.fast+40` 仍 `open===true`；
  - 双悬停释放后 `requestClose` 等待同延迟后 `open===false` 且 enum 保持 `Up`，最终 `Totals: 15 passed, 0 failed`。

## 命令

### qmllint
```bash
/usr/lib/qt6/bin/qmllint modules/bar/BarPopupHost.qml
```
**结果（exit 0，仅警告，符合既有 TopBar 现状）：**
```
Warning: modules/bar/BarPopupHost.qml:9:1: Type PanelWindow is not creatable. [uncreatable-type]
Warning: modules/bar/BarPopupHost.qml:76:5: unknown grouped property scope margins. [unqualified]
Warning: modules/bar/BarPopupHost.qml:76:5: Type margins is used but it is not resolved [unresolved-type]
```

### qs harness
```bash
qs -p tst_bar_popup_host.qml
```
**结果（exit 0）：**
```
INFO: Launching config: "/home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat/tst_bar_popup_host.qml"
INFO: Configuration Loaded
PASS: showIntent opens host (top)
PASS: top bar direction is down
PASS: TwoLayerPopup direction Down for top bar
PASS: anchorX stored
PASS: screenWidth stored
PASS: intent preserved
PASS: sidebarData alias exists
PASS: contentData alias exists
PASS: bottom bar direction is up
PASS: TwoLayerPopup direction Up for bottom bar
PASS: still open after intent swap
PASS: orientation is Vertical
PASS: requestClose while popupHovered keeps open
PASS: close after both hovers released
PASS: TwoLayerPopup direction Up after bottom bar
Totals: 15 passed, 0 failed
```

## diff check
```bash
git diff --check
# 无尾随空白/冲突标记（仅聚焦文件）
```

## 未阶段化的保留项
- 保持未跟踪调试产物 `142bpm.mp3`, `aubio.err`, `live_beats.txt`, `tst_count.qml`, `tst_ghost_debug.qml`, `tst_rapid_debug.qml`, `tst_sweep.qml` 不入本次提交。
- Services 层无改动，已避免恢复 `BarPopupService` 状态机。

## Concerns
- `PanelWindow` 的 `margins` 在 `qmllint` 中报 `unknown grouped property` 为 Quickshell 类型系统在离线 lint 时的已知警告（`TopBar.qml` 同款三处 warnings，exit 0），非功能回归；`PanelWindow is not creatable` 亦为 `quickshell-window.qmltypes` 标记 `isCreatable:false` 导致，运行时通过 Quickshell 插件可创建。
- `BarPopupHost` 的 `screen` 在 harness 中为 `null`，回落到 `screenWidth`（默认 1920，harness 用 1000）；生产环境 `TopBar` 将在 Variants 每屏 Scope 中传入真实 `screen`，届时 `implicitWidth/Height` 走 `screen.width/height` 分支，`screenWidth` 仅作 anchor 夹紧的逻辑宽度，需与后续 Task 4 传入的 `screenWidth` 保持一致。
- 关闭清理分两段：`MotionTokens.fast`（100ms）内仅 `open=false` 与 `closeRequested`，`intent` 则延后 `revealDuration+40`（约 740ms）才清零；harness 仅等待第一段即断言 `open`，若 Task 5 需观测 `intent` 是否已空，需额外等待第二段。
- `BarHoverLogic.clampAnchor` 的 margin 取 8（与旧 popup 框架一致），而非 `floatingMargin`，若后续视觉要求与 bar 浮动边距对齐，需在 Task 5 统一定位策略时再校准。
- `Qt.quit()` 在 Quickshell 环境不接受 exit code 参数（传参会报 Too many arguments），harness 已改为无参调用并以 `Totals` 零失败判定成功；CI 若依赖进程退出码区分失败，需外部包裹器解析 `FAIL` 行。
