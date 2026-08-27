# 弹出菜单两层样式设计（Popup Two-Layer）

日期：2026-08-27
状态：已确认（方案 C：共享框架 + 设置面板色彩；贴栏直角下拉）

## 背景与目标

当前 bar hover 弹出（托盘菜单、音量/亮度滑条、时钟日历、媒体、通知、BarContextMenu）为单层卡片，标题与内容混在同一容器内，与设置面板的“侧边栏 rail + 内容区”视觉不统一。需统一为垂直两层：靠近顶栏的标题层显示组件/托盘名，底部为具体内容，复用 `LazerSettings` 已验证的表层、字阶与分割线语言。

## 范围

- 覆盖所有 `BarPopupHost` 承载的弹出：`BarTrayMenu`（含一级/二级）、`BarSliderPopup`（volume/brightness）、`BarCalendarPopup`、`BarMediaPopup`、`BarNotificationsPopup`、`BarContextMenu`。
- 一级与二级菜单均使用同一标题层语言（二级标题为父条目标签）。

## 设计

### 共享框架 `modules/bar/BarPopupFrame.qml`

- 外层：`color: LazerTheme.settingsPanel`、`border.color: LazerTheme.popupBorder`、`radius: 0`、`clip: true`。所有主表面沿用设置侧栏的直角语言，不再呈现浮动卡片。
- 标题层：`height: 48`（对齐 `barLiveHeight`），`color: LazerTheme.settingsRail`，底沿 1px `divider` 隔离内容；内部 `Row`：可选 `Image 16`（tray 图标/组件图标）+ `Text 14 DemiBold textPrimary elide`，左右 `16` 边距，垂直居中。
- 内容层：`anchors.top: header.bottom` 至底，`topPadding` 由调用方决定，默认 `12`，作为 `default property alias contentData` 的 slot 容器；对外暴露 `implicitHeight = header.height + 1 + content.implicitHeight`。
- 行为：无自身动画，依赖宿主 `BarPopupHost` 的单轴垂直揭示；取消缩放。减少动议时静默。

### 各弹出改造

- **BarTrayMenu**：根菜单与 `submenuSurface` 均以 `BarPopupFrame` 为容器重写。根标题取 `payload.title || payload.tooltipTitle || payload.id || "Tray"`；二级标题取 `submenuEntry.text`。条目列保持 `Flickable`，头部不参与滚动与遮挡逻辑（`menuFace` 调整为仅覆盖内容区或移除，二级揭示仍以根整体的 face 遮挡为准）。
- **BarSliderPopup**：原标题 Row 移入 frame 标题（含图标与百分比）；内容区仅保留 `LazerSettingsSlider` 与静音块。
- **BarCalendarPopup**：frame 标题固定为 `Calendar`（或本地化“日历”），内部原“年 月 + 翻月按钮”降为内容区二级头；日历网格不变。
- **BarMediaPopup**：frame 标题为 `Now Playing` / `Media`，内容区保留曲名/歌手/进度/操作。
- **BarNotificationsPopup**：frame 标题为 `Notifications`，内容区保留两行操作。
- **BarContextMenu**：保持 `railWidth + contentWidth` 双列主体，但在外层顶部叠加 `BarPopupFrame` 标题层（显示 `selectedEntry.label`），或将现有 `headerSlot` 提升为 frame 标题以满足“靠近顶栏一层为名称”；rail 与内容区下移至标题下方，保持现有选择与操作逻辑不变。

### 视觉令牌

- 直接复用 `LazerTheme.settingsRail / settingsPanel / popupBorder / divider / textPrimary`，字号 `13-14`、字重 `DemiBold`（标题），分割线 `1`，主表面圆角 `0`。
- 子菜单使用直角双层表面，保留横向 `Translate` 以从一级菜单边缘展开，取消 `Scale`。

### 贴栏定位与揭示

- 弹出面板与顶栏直接相接：顶部栏面板 `y: 0`，底部栏面板贴窗口底部；移除原有 `4px` 间隙。
- 水平位置以触发组件左边缘对齐；越过右侧安全边距时转为右边缘对齐。
- 宿主仅沿垂直轴平移以在顶栏遮挡区内展开/收回；不使用 `Scale`，不围绕组件居中。

### 非目标

- 不改变 `BarPopupService` 状态机；调整 `BarPopupHost` 定位与揭示以实现贴栏下拉。输入遮罩逻辑保持。
- 不引入新的持久化设置项。

## 验证

- 重载后逐个 hover 触发，确认标题层贴顶、名称正确、内容不溢出、圆角与分割线完整。
- 托盘二级菜单展开/收回与走廊桥接、纵轴锁定、高度平滑仍有效（复用既有探针）。
- `qmllint` 无新增警告；`qs -p` 无 ERROR。

## 风险与回退

- 文本过长时标题需 `ElideRight`，二级标题过长同样处理。
- 子菜单异步高度保持与 `heldHeight` 逻辑随容器改为 frame 后需同步高度来源（`contentColumn.implicitHeight`）。
- 若视觉过重，可将标题层改为透明仅文字+分割线（方案 A 降级），无需改宿主。
