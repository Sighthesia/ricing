# Technical Design

## Experiment Boundary

实验沿输入链路逐层确认：

`Wayland pointer -> PanelWindow Region mask -> LazerSettingsOverlay -> LazerSettingsPanel -> Content viewport -> page Flickable -> Row/control HoverHandler`。

已有 QML debug snapshot 作为状态采样器；本任务不新增全屏 HoverHandler，不改变普通输入 ownership。

## Diagnostic Mode

- 增加一个默认关闭、非持久化的 mask diagnostic switch，或使用临时 harness 对现有 `settingsWindow.mask` 做对照。
- 正常模式保持 `Region { item: settingsOverlay.blocksDesktop ? settingsOverlay : null }`。
- 对照模式只改变 mask 是否存在，不改变 overlay/page/row geometry、enabled、opacity 或 settings state。
- 所有日志包含 `experiment`, `screen`, `mask`, `pointerPoint`, `sceneRects`, `hover`, `focus`, `tooltipSource`。

## Sampling

1. 打开 settings overlay 并等待 contentReady。
2. 采样 Appearance 的 wallpaper、Choice、panel opacity slider、enable blur toggle、blur surface slider。
3. 切换 Bar 和 Notifications，重复首行、中间行和控件内部采样。
4. 滚动当前 page 后重复采样，并执行关闭/重开。
5. 对每个坐标先 mask=true，再 mask=false，再恢复 mask=true。

## Interpretation

- mask=true 无 hover，mask=false 有 hover：根因在 PanelWindow/Region 或 compositor 输入区域。
- 两种模式都无 hover，但 scene rect/point 正常：根因在 QML input owner、Flickable 或控件层。
- 两种模式都无 scene point：优先检查 pointer 是否进入该 PanelWindow、屏幕实例、窗口可见性和 layer-shell 状态。
- hover/focus 正常但视觉不变：再检查卡片 visual binding 或 opacity/z，不再调整输入层。

## Compatibility And Rollback

- 诊断开关默认关闭，不写入 SettingsService persisted state。
- 不改变 `SettingsOverlayBridge`、页面注入、保存/重置 API。
- 实验代码若进入生产文件，必须在实验结束后移除或单独保留为明确的默认关闭 diagnostics，并在 commit 中标注。
