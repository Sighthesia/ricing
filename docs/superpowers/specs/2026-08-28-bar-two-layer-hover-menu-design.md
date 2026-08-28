# 顶部栏双层悬浮菜单设计

日期：2026-08-28
状态：已确认

## 目标

将 `TwoLayerPopup` 复用为顶部栏可操作组件与系统托盘图标的悬浮菜单。第一层承担设置侧边栏的身份信息职责，第二层承担设置内容区的具体操作职责。

## 范围

本次接入以下已有明确操作内容的入口：

- 系统托盘单个 StatusNotifier 图标。
- 音量。
- 亮度。
- 媒体。
- 通知。

时钟、活动窗口、工作区、启动器和设置按钮不在本次范围内。时钟仅有显示职责，未定义日历操作面，因此不新建菜单功能。

## 架构

新增每屏 `BarPopupHost`，由 `TopBar` 作为独立的 overlay layer-shell surface 挂载。它覆盖 bar 之外的可用屏幕区域，固定几何，不随 reveal 每帧改变窗口尺寸。

`BarContent` 负责收集可操作 widget 的 hover 意图并发布给宿主：组件类型、标题、状态摘要、图标、触发组件的屏幕内锚点和操作内容类型。系统托盘 delegate 以每个 SNI 图标为独立触发源。

宿主使用 `TwoLayerPopup` 的垂直模式：

- 顶部栏时使用 `TwoLayerPopup.Direction.Down`。
- 底部栏时使用 `TwoLayerPopup.Direction.Up`。

第一层通过 `sidebarData` 注入，为 `LazerTheme.settingsRail` 的直角身份层，显示图标、组件名称、标题与简短状态。第二层通过 `contentData` 注入，为 `LazerTheme.settingsPanel` 的直角操作层，只放置该组件已有的操作控件。

## 操作内容

- 系统托盘：触发 SNI 的 `activate()` 和 `secondaryActivate()`；若原生菜单项可用，后续在同一 content slot 追加，不改变宿主协议。
- 音量：滑块和静音开关。
- 亮度：滑块。
- 媒体：播放/暂停、上一首、下一首和进度信息。
- 通知：勿扰开关和清除已读。

## Hover 与输入

触发组件与菜单共享 hover 生命周期。鼠标离开触发组件时启动短关闭延迟；进入菜单前取消关闭，从图标移动至菜单不会闪退。菜单打开期间保留 pointer 输入；离开触发组件和菜单后关闭。组件的原有 click/wheel 快捷操作保持不变。

## 动效与视觉

- 复用 `TwoLayerPopup` 的固定 owner、stagger、opacity、Translate 与 reduced-motion 规则。
- 不恢复旧的 `BarPopupService` 状态机。
- 主表面保持直角；身份层使用 `settingsRail`，操作层使用 `settingsPanel`，小型操作控件遵循现有设置面板的 hover、click flash 和 press-scale 配方。
- 宿主位置以触发组件的横向中心为基准，在屏幕边缘内夹紧。

## 验证

- 纯逻辑测试覆盖顶部/底部方向选择、锚点夹紧和 hover bridge 的关闭时序。
- QML 测试覆盖 `TwoLayerPopup` 在 bar 场景的两层注入和方向。
- `qmllint` 检查新增和修改的 QML 文件。
- 使用 `qs` 行为 harness 检查 bar 可加载；`qmltestrunner` 不承担 Quickshell surface 行为验证。

## 非目标

- 不恢复旧的 `BarPopupService`、`BarTrayMenu`、`BarContextMenu` 或旧 hover popup 状态机。
- 不为没有既有操作面的 widget 设计新功能。
- 不改变 bar 的持久化布局模型。
