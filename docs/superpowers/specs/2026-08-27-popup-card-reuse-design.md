# 弹出菜单两层卡片复用设计（Popup Card Reuse）

日期：2026-08-27
状态：已确认（方案 A：两张独立卡片 surface 复用左侧栏契约）
关联：`docs/superpowers/specs/2026-08-27-popup-two-layer-design.md`、`docs/superpowers/plans/2026-08-27-popup-two-layer-plan.md`

## 背景与目标

左侧设置面板的“两层卡片”是两张独立 surface：`LazerSettingsPanel.sidebarLayer`（`settingsRail`）与 `contentLayer`（`settingsPanel` + `backgroundExtend`），各自拥有背景并由 `progress` 驱动 `x` 位移；内容层内部再以 `LazerSettingsSection`（`settingsSection`）套 `LazerSettingsRow`（`cardSurface radius 6 / settingsCard→settingsCardHover / 1.5px accent 边框 / clickFlash / pressScale 0.985`）构成二次分层。当前弹窗把“标题文字+内容文字”绑在同一 `Rectangle` 内做 `Translate y`，背景靠 `z:-1` 补位，未复用样本的独立 surface 与卡片配方，导致无明显两层错位。

目标：全部 `BarPopupHost` 承载的弹出统一为两张独立直角卡片，复用左侧栏的层级、令牌与动效契约。

## 范围

- 覆盖：`BarPopupFrame` 承载的 4 类（`BarSliderPopup / BarCalendarPopup / BarMediaPopup / BarNotificationsPopup`）、`BarTrayMenu` 一/二级、`BarContextMenu`。
- 不变：`BarPopupService` 状态机、`BarPopupHost` 输入遮罩与贴栏定位、`LazerSettings*` 权威文件本身。

## 设计

### 共享契约

- 令牌：`LazerTheme.settingsRail / settingsPanel / settingsSection / settingsCard / settingsCardHover / settingsAccent / divider / textPrimary / textMuted`；`MotionTokens.settingsSidebarFade 500 / settingsContentDelay 200 / settingsSidebarStagger 40 / slow 240 / fast 100 / pressScale 0.985 / clickFlashOpacity 0.3 / clickFlashDuration 800 / clickFlashEasing OutQuint`。
- 时序：进入 `Easing.OutQuint 700ms（200 delay + 500 fade）`，退出 `Easing.InQuad 700ms`，标题层立即、内容层延迟 `200ms`，位移 `header 12px`、`content 14px`，通过 `BarPopupMotion.js` 的 `headerProgress/contentProgress/offset` 统一计算。
- 形状：全部直角 `radius 0` 外层，卡片 `radius 6`，分割线 `1px divider`，无 `popupBorder`。

### 容器结构

- 弹窗根由 `Rectangle` 改为 `Item` 固定 owner，内部两张兄弟层：
  - `headerCard: Rectangle { color: settingsRail; height: 48; opacity: headerProgress; Translate y: -offset(12) }`，含 `Row(icon 16 + Text 14 DemiBold)`。
  - `contentCard: Rectangle { color: settingsPanel; opacity: contentProgress; Translate y: offset(14) }`，内部再按需放置 `Flickable + Column`，行使用下方卡片配方。
  - `divider: Rectangle 1px` 置于两卡之间，归属 header 底沿。
  - `clip: true` 仅在外层 `Item` 的内容裁切需要时启用，不参与动画。
- `BarPopupFrame` 作为共享框架提供 `title/iconSource/extraText/headerHeight/revealProgress/headerProgress/contentProgress`，默认 `contentData` 注入 `contentCard`。
- `BarPopupHost` 保持固定 `frameX/frameY` 与 `deformProgress` 单进度驱动，不再对 `Loader` 宽高做 `Behavior`，避免逐帧重布局。

### 行卡片配方（复用 LazerSettingsRow）

- 表面：`Rectangle radius 6 color: hover ? settingsCardHover : settingsCard; border.width: hover ? 1.5 : 0; border.color: settingsAccent`，`Behavior on color/fast`。
- 反馈：`HoverHandler blocking:false` + 独立闪烁层 `Rectangle color textPrimary opacity 0`，`NumberAnimation from clickFlashOpacity to 0 duration 800 easing OutQuint`，`TapHandler` 触发 `restartFlash()`；按压 `scale pressScale`，受 `reducedMotion` 门控。
- 布局：行高 `32-40`，`anchors.margins 2`，`spacing 2`，`listGap 8` 折入高度，禁用时 `opacity disabledOpacity`。
- 托盘行需保留 `checkIndicator` 与 `chevron`，但表面统一为上述卡片。

### 各弹出

- `BarSliderPopup/BarCalendarPopup/BarMediaPopup/BarNotificationsPopup`：以 `BarPopupFrame` 为根，标题直通 frame，内容仅保留原控件列。
- `BarTrayMenu`：一级为上述双卡；二级 `submenuSurface` 改为同构双卡（`submenuHeaderCard + submenuContentCard`），复用同一 `revealDuration/headerProgress/contentProgress`，走廊桥与 `yLocked/heldHeight/frozenX/Y` 契约保持。
- `BarContextMenu`：外层 `Item` 上置 `headerCard`，下分 `railSurface + railFlickable` 与 `contentArea`，两者皆用 `contentProgress` 与 `settingsCard` 行。

## 非目标

- 不新增持久化设置项。
- 不修改 `LazerSettingsRow/Section/Panel/Sidebar` 权威实现，仅复用其令牌与配方。
- 不引入 `Scale` 或外层几何动画。

## 验证

- `qmllint modules/bar/BarPopup*.qml modules/bar/BarTrayMenu.qml modules/bar/BarContextMenu.qml` 无 Error。
- `qs -p shell.qml` 无 `ERROR/Failed to load`。
- `git diff --check` 通过。
- 手动：逐个 hover 触发，标题与内容色块各自错位、分割线完整、行 hover/点击闪烁与左侧一致、无卡顿。

## 风险与回退

- 文本过长 `ElideRight`，二级标题同样处理。
- 若双卡高度计算回归，保留 `heldHeight/rawColumnHeight` 高度保持逻辑，仅迁移高度来源至 `contentColumn.implicitHeight`。
- 回退：保留单容器结构仅对齐令牌（方案 B），无需改宿主。
