# Technical Design

## Architecture

将设置项重构为三层职责：

1. `LazerSettingsRow` 作为唯一卡片宿主和布局 owner。
2. `LazerSettingsTextField/Choice/Slider/Toggle` 作为唯一控件交互 owner，只暴露稳定尺寸、状态和操作信号。
3. `LazerSettingsContent` 作为 viewport 与临时 overlay owner，只在 dropdown 打开时创建/启用菜单输入层，tooltip 始终是非交互视觉层。

页面文件继续只负责声明设置数据和 row composition，不直接参与 pointer arbitration。

## Row Contract

`LazerSettingsRow` 保留已有公开输入：`labelText`、`descriptionText`、`enabled`、`searchQuery`、`defaultValue`、`currentValue`、`resetCallback`。

新增或收敛为以下内部契约：

- `layoutMode: standard | inline | split | choice`，由控件 presentation contract 单向提供；
- `cardItem` 是唯一可见卡片背景和 bounds owner；
- `contentItem` 是唯一内容布局域；
- `controlItem` 的实际 bounds 由 Row 一次性布局，控件内部不再被外部第二个 y-binding 重定位；
- `rowHovered` / `rowHighlighted` 只作为视觉和 tooltip 活跃状态，不拥有输入；
- `revertButtonItem` 仅在可恢复时启用并位于固定预留区。

Row 的布局计算应先计算 `cardRect`、`contentRect` 和 `controlRect`，再将结果赋给 Item，避免 `implicitHeight -> contentHost.height -> controlHost.height -> control.y` 的循环推导。

## Control Contract

- TextField：root 仍是 FocusScope；editor 是唯一键盘焦点 owner；root bounds 等于 field surface bounds。
- Choice：root/header bounds 一致；菜单不作为 Choice 子树中的普通可见命中区域，打开状态由 Content overlay owner 控制。
- Slider：root bounds 等于 track bounds；track/root 自己处理点击和拖动；thumb 只作为 visual/tooltip geometry source，不独立扩大输入区。
- Toggle：root bounds 等于 capsule bounds；点击和键盘操作由 Toggle 自己处理。

所有控件保留 `enabled`, `rowEnabled`, `activeFocusOnTab`, `hovered`, `debugHoverScenePoint` 等现有测试/页面所需接口；不通过新增全屏 MouseArea 解决命中。

## Overlay Ownership

- `viewport` 只裁剪当前页面，页面外内容不可命中。
- `scrollShadow`、`emptyState`、tooltip 的装饰层明确 `enabled: false`，或者在不可用时 `visible: false` 并不留在输入树中。
- dropdown overlay 的 parent visibility 由 `dropdownOpen` 这一 Content 状态控制；outside catcher 仅在 dropdown 打开时启用。
- tooltip `enabled: false`, `activeFocusOnTab: false`，仅用于绘制与跟随 source geometry。
- bridge 继续只传输 source identity；Content 负责 owner tree 校验和 overlay 生命周期。

## Migration Order

1. 先在 Row 中收敛布局和命中矩形，使用 TextField 作为代表性 standard Row。
2. 迁移 Choice 与 split/inline 控件，删除外部重复 y-binding 和重叠输入 owner。
3. 重构 Content viewport/overlay 命中边界。
4. 扩展到 Appearance、Bar、Notifications 页面并补生命周期回归。

## Compatibility And Rollback

- 页面注入接口和设置保存语义不变。
- 每一步保留现有 aliases、signals 和 test-facing properties；需要删除的属性必须提供同语义 alias 或在迁移前更新全部调用方。
- 若某一步造成 dropdown/tooltip 回归，回滚到上一步的 Row/Content owner边界，不回退设置服务或 persisted data。

## Risks

- QML implicit size 与显式 size 混用可能隐藏 binding loop，需要 `qmllint` 和静态几何断言。
- `PanelWindow.mask` 仍是 compositor 输入边界，组件重构不能扩大 mask；必须验证 mask 只覆盖 settings overlay 可见区域。
- 当前 QML 测试入口受 `qrc:/qs-blackhole` 环境故障影响，需使用可运行的静态/配置验证补足，并明确报告剩余缺口。
