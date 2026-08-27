# 双层弹出菜单抽象设计

日期：2026-08-27
状态：已确认

## 目标

将设置面板当前“侧栏层 + 主栏层”分离、独立揭示和错位入场的结构抽象为无业务状态的 QML 容器，供设置面板、bar 组件和右键菜单复用。旧的 bar 弹出实现已经不稳定并被置空，本次不恢复旧状态机或旧宿主。

## 组件

新增 `modules/lazerbar/TwoLayerPopup.qml`。

- 根节点是固定几何的 `Item`，不因动画修改自身尺寸。
- 通过 `sidebarData` 和 `contentData` 两个 slot 注入两层内容，并暴露 `sidebarLayer`、`contentLayer` 供宿主绑定尺寸和状态。
- 每层拥有独立 surface、opacity 和 Translate；主栏按 `contentDelay` 延迟进入。
- `revealProgress` 由消费者驱动，`beginReveal()` 和 `endReveal()` 提供标准生命周期；`MotionTokens.reducedMotion` 时直接落到终态。
- `orientation` 支持横向设置面板和纵向弹出菜单；纵向 `direction` 支持 `Up` 与 `Down`。
- 横向模式允许消费者指定两层打开位置，保留设置面板现有的独立 owner 几何；纵向模式根据方向和层尺寸自动排列。
- 组件不持有菜单数据、不处理 pointer 事件、不引入外部状态机。

## 设置面板迁移

`LazerSettingsPanel` 使用 `TwoLayerPopup` 承载现有 `LazerSettingsSidebar` 和 `LazerSettingsContent`。侧栏、内容区的公开 alias、z-order、宽度计算、焦点和滚动逻辑保持不变；原有位置绑定迁移到组件提供的打开位置属性。

## 未来消费者

bar 组件和右键菜单可以将 `orientation` 设为纵向，按触发位置选择 `direction: Up` 或 `Down`，分别向上或向下展开。它们只需注入侧栏标题/工具层和主内容层，不依赖设置面板类型。

## 验证

- QtTest 验证两层 slot、上下方向的最终几何、主栏延迟进度和 reduced-motion。
- `qmllint` 检查新增组件及设置面板。
- 运行 `qmltestrunner`，确认无失败、警告或错误输出。
- `git diff --check` 通过。

## 非目标

- 不恢复 `BarPopupHost`、`BarContextMenu` 或任何旧 bar 弹出业务。
- 不修改 `BarPopupService`，不新增持久化设置。
- 不把菜单行、点击闪烁或设置业务逻辑塞进共享容器。
