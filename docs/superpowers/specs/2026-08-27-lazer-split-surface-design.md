# Lazer Split Surface Design

## Objective

抽象设置面板左侧边栏所使用的两层独立面板效果，供 bar 组件弹出菜单复用。弹出菜单的外层背景、分隔线、内容背景和内容本身必须共同参与揭示过程，避免只有文本发生位移而纯色背景瞬间出现。

## Architecture

新增 `modules/lazerbar/LazerSplitSurface.qml` 作为公共视觉壳：

- `headerSurface` 使用 `LazerTheme.settingsRail`，独立控制第一层的 opacity 和位移。
- `contentSurface` 默认使用 `LazerTheme.settingsPanel`，独立控制第二层的 opacity 和位移。
- `divider` 固定为 1px，表达两层之间的结构关系。
- `revealProgress` 是唯一的外部进度输入，内部根据 `MotionTokens` 拆分为 `headerProgress` 和 `contentProgress`。
- 默认内容通过 `contentData` 挂载到 `contentSurface`，保证背景和控件属于同一 owner layer。
- `interactable` 同时控制公共壳和内容层的输入状态。

公共壳只动画内部 surface，不改变宿主 Loader 或 layer-shell 的几何尺寸。所有动效受 `MotionTokens.reducedMotion` 门控，并沿用设置面板的 OutQuint 进入、InQuad 退出及阶段延迟。

## Migration

- `BarPopupFrame` 组合公共壳，并保留标题、图标、附加文本布局。
- `BarTrayMenu`、`BarContextMenu` 使用公共壳提供两层背景，移除各自重复的揭示背景逻辑。
- `LazerSettingsPanel` 接入公共壳作为设置内容的统一 owner；`LazerSettingsSidebar` 继续负责导航内容和选择指示器。
- `BarPopupHost` 继续只驱动一个 `deformProgress`，不动画 Loader 的宽高。

## Behavior

打开时先揭示侧栏色 header，再延迟揭示内容色 surface；内容控件与内容背景同步进入。关闭时按同一进度反向退场。重新打开和内容切换必须从当前进度连续反转，不产生纯色面板闪现。

## Verification

验证设置面板、音量、亮度、日历、媒体、通知、托盘和右键菜单的双层背景，以及中途关闭、重新打开和 reduced-motion 状态。运行相关 `qmllint`、QML 测试和 `qs -p .`，并修复所有 WARN/ERROR 输出。
