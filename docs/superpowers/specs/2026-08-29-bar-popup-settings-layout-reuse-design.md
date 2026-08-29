# Bar 弹出菜单复用设置布局设计

日期：2026-08-29
状态：已确认

## 目标

将设置面板已经验证过的“两层 surface + stagger 入场 + 固定 owner”布局复用到组件悬浮菜单和 bar 右键菜单。顶部栏时菜单从上到下展开，底部栏时从下到上展开；设置面板继续保留横向入场方式。

## 视觉结构

- 第一层使用设置面板侧栏的视觉职责，显示组件图标、组件名称、标题和状态摘要。
- 第二层使用设置面板主区域的视觉职责，显示组件已有的具体操作或右键操作项。
- 组件悬浮菜单使用窄型宽度，目标宽度约为 `260px`，不复用设置面板的横向宽度。
- 所有主要 surface 保持直角；颜色、点击反馈、stagger 和 reduced-motion 继续由 `LazerTheme` 与 `MotionTokens` 提供。

## 组件悬浮菜单

继续使用现有每屏 `BarPopupHost`：

- 使用 `TwoLayerPopup` 的垂直模式。
- 第一层注入 `BarPopupIdentity`。
- 第二层注入 `BarPopupActions`。
- 顶部栏使用 `TwoLayerPopup.Direction.Down`，底部栏使用 `TwoLayerPopup.Direction.Up`。
- 同屏只保留一个 host；托盘图标切换时原地更新 intent，不创建重叠窗口。
- 保留音量、亮度、媒体、通知和托盘已有的 click/wheel/服务操作。

## Bar 右键菜单

将 `BarContextMenu` 作为第二个业务消费者实现：

- 使用独立的每屏固定 owner，但复用同一 `TwoLayerPopup` 方向、尺寸、边缘夹紧、hover bridge 和退出生命周期。
- 第一层显示被选 widget 的名称、图标和状态摘要。
- 第二层承载已有 context menu 职责：移动组件、切换 section、打开组件设置、删除组件和退出菜单。
- 继续使用 `BarLayoutService.contextMenuVisible/contextMenuX/contextMenuWidgetKey/contextMenuWidgetId/contextMenuSection` 等状态，不恢复旧 `BarPopupService` 状态机。
- 右键菜单与组件悬浮菜单互斥；打开任一菜单时关闭另一菜单。

## 设置面板隔离

打开设置面板时，组件悬浮菜单和右键菜单必须关闭并释放其全屏 overlay owner。设置面板继续使用横向 `TwoLayerPopup`，其 owner 尺寸、位移和透明度归属不被垂直 bar 菜单覆盖。

## 输入与生命周期

- 触发 widget、popup 和右键菜单共享 hover bridge。
- popup 的 hover 观察必须是非阻塞的；离开所有相关 surface 后通过 `MotionTokens.fast` 延迟关闭。
- popup 退场完成前保留视觉内容，清理 timer 完成后再释放 intent 和窗口可见性。
- 所有关闭、切换和重新打开路径必须取消旧的清理 timer，避免旧菜单清除新内容。

## 验证

- 纯逻辑测试覆盖上下方向、中心和边缘锚点、右键菜单 payload。
- QML/qs harness 覆盖组件菜单与右键菜单的两层注入、互斥、切换和退场。
- 验证设置面板仍可见，横向入场位置随 progress 改变且不被垂直 host 裁剪。
- `qmllint`、相关 `qmltestrunner` 和 `qs -p shell.qml` 必须无新增错误。

## 非目标

- 不恢复或重新设计旧 `BarPopupService`、旧 `BarTrayMenu` 或旧 `WidgetHoverPopup` 状态机。
- 不为没有明确操作内容的 widget 新增悬浮菜单。
- 不修改设置面板的业务设置项或持久化布局模型。
