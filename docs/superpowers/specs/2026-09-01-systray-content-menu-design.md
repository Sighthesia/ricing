# 系统托盘内容菜单设计

日期：2026-09-01
状态：已确认

## 目标

悬停系统托盘图标时，现有双层弹窗的第二层直接展示该图标的原生 DBus 菜单。带子菜单的行悬停后展开一级二级面板。不恢复旧的独立托盘菜单窗。

## 范围

- 覆盖 `BarPopupHost` 中 `actionKind === "tray"` 的内容层。
- 支持根菜单与一层子菜单。
- 支持普通项、勾选项、分隔线、禁用项、空菜单。
- 保留托盘图标本身的左键 `activate()` 与右键 `secondaryActivate()`。

不在本次范围：三级及以上级联、独立浮动托盘窗、改其他 widget 的 hover 内容。

## 架构

悬停仍由 `Tray.qml` 发布 intent 给每屏 `BarPopupHost`。第一层继续用 `BarPopupIdentity` 显示图标与名称。第二层不再使用 Open / Menu 按钮，改为托盘菜单内容组件。

`Tray.qml` 的 payload 增加 DBus 菜单句柄：`menuHandle` 来自 StatusNotifier 项的 `menu`（仅当 `hasMenu` 为真）。现有 `trayItem`、`onActivate`、`onSecondaryActivate` 保留。

内容组件在弹窗内用 `QsMenuOpener` 绑定根句柄，行模型来自 `opener.children`。二级再用一个 opener，句柄指向当前悬停的子菜单项。

## 视觉与交互

根菜单行使用设置面板行卡片：`settingsCard` / `settingsCardHover`、点击闪烁、禁用态降不透明度。分隔线是细分隔，不可点。带子菜单的行右侧有方向提示。

二级面板垫在一级内容脸面之下，opacity 恒为 1，靠遮挡揭示。揭示从锚定行近侧滑出。二级顶部只用父行文字做标题，不复制托盘图标那套身份摘要层。

悬停带子菜单的行即展开二级；悬停普通根行或离开时收回。收回时条目数据保活到退场动画结束，避免高度塌成细条。重定向到另一条子菜单行时只换锚点与 entry，不重播揭示。一级与二级之间保留输入走廊，穿越间隙不算离开。根菜单高度平滑，避免应用刷新菜单时一帧塌缩把静止指针甩出遮罩。

点普通项执行并关闭整个弹窗。点勾选项切换选中，菜单可保持打开。禁用项可见不可点。没有菜单句柄或根菜单为空时，第二层显示空状态文案，不回退到 Open / Menu。

菜单过长时根菜单内容可滚，最大高度不超过屏幕可用高度的约 70%，下限约 180px。

## 组件边界

- `Tray.qml`：把 `menuHandle` 放进 payload。
- `BarPopupActions`：`tray` 内容槽改为挂载托盘菜单内容，删除 Open / Menu 按钮。
- 新增托盘菜单内容组件（建议 `modules/bar/BarTrayMenuContent.qml`）：拥有 opener、根行列表、二级表面、走廊桥、开合状态机。
- 行委托可内嵌在内容组件中，但折叠“悬停普通行关闭二级”的规则必须限定为根级行，避免指针进入二级行时把自己关掉。
- 不恢复 `BarTrayMenu.qml` 独立窗，不重新启用 `TrayMenuService` 作为弹出宿主。

## 错误处理

- `hasMenu` 为假或 `menu` 为空：空状态，不创建 opener 绑定。
- 根菜单异步尚未返回：保持上一帧高度，不先塌再弹。
- 切换托盘图标：关闭二级并换句柄；新 opener 未返回前沿用高度。
- 菜单项 `triggered` 失败：忽略，不让弹窗卡在半开。

## 测试

用假菜单树（不依赖真实 StatusNotifier）覆盖：

- 根菜单按条目渲染，分隔线不可点。
- 点普通项会调用 triggered，并请求关闭宿主。
- 点勾选项会切换，不强制关闭。
- 无句柄或空 children 显示空状态。
- `openSubmenu` 保活 entry；progress 回到 0 才清空。
- 根级普通行会折叠二级；二级行不会折叠自己。
- payload 切换会关闭二级。

无头环境不测真实指针走廊；走廊与高度平滑作为实现契约，用几何/状态断言锁住。

## 非目标

- 不恢复旧 `BarPopupService` / 独立 `BarTrayMenu` 窗口。
- 不做三级菜单。
- 不改变托盘图标的 click / secondary click。
- 不把托盘菜单做成设置面板业务项。
