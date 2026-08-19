---
name: lazer-settings-surface-details
description: 修改 Afloat 的 lazer 设置面板、设置 row、恢复默认按钮、分类区块、搜索栏、滑条或控件反馈时使用。固化已验证的设置面板层级、尺寸、z-order、伪月牙默认按钮、滑条刻度闪烁与轻微震动、hover/press 输入隔离和进入退出动效，避免破坏现有视觉与交互契约。
---

# Lazer 设置面板细节规范

这份 skill 是 `osu-sharp-design-language` 的实现级补充。修改设置面板前先确认以下契约，优先复用现有属性和层级，不要另起一套视觉状态。

## 表面层级

- 内容区整体使用 `LazerTheme.settingsPanel`。
- 搜索栏是全宽直角色带：使用 `LazerTheme.settingsRail`，不使用胶囊背景、不设置左右/上下缩进、不设置圆角。
- 分类区块使用 `LazerTheme.settingsSection`，是直角矩形；与相邻分类之间保留约 `4px` 间距。
- row 内容以 `settingsCard` / `settingsCardHover` 表达层次；row 背景和分类背景通过亮度差区分，不新增大圆角边框。
- 设置分类标题保留底部细分隔线；它是结构线，不是圆角外框。
- row 的控件内容通常保留 `8px` 左右内缩；默认按钮区域不应改变 row 内容的预留宽度契约。

## Row 几何

- 普通 row 的卡片圆角由 `LazerSettingsRow.cardRadius` 统一控制，当前为 `6px`。
- 默认按钮逻辑宽度为 `revertZoneWidth = 28px`；内容布局预留宽度仍使用这个值。
- 默认按钮视觉宽度为 `revertZoneWidth + cardRadius`，当前为 `34px`。
- 默认按钮最终右边缘与 row 右边缘重合；额外的 `cardRadius` 宽度向左覆盖 row 背景。
- 默认按钮位于 row 背景之下（button `z` 小于 card surface），由 row 背景的圆角裁掉左上/左下角，形成伪月牙几何效果。
- 默认按钮自身右侧保留 row 的圆角，左侧保持直角；图标应以实际可见的 `28px` 区域为中心，而不是以扩展后的视觉宽度为中心。

## 默认按钮状态

- 按钮拥有独立的 `HoverHandler` 和 `TapHandler`；不要让 row 的全尺寸 hover catcher 覆盖按钮区域。
- hover、press、keyboard focus 的颜色和图标状态使用按钮自身状态；hover/press 可使用 `settingsResetSurfaceHover` 和 `settingsAccent`。
- 按下反馈使用 `MotionTokens.pressScale`，不要用透明度代替点击反馈。
- 默认值不匹配时按钮可见；值恢复默认时按钮仍保持挂载并从左侧滑回 row 背景下方；没有默认值时才隐藏。
- 不能用 `opacity` 作为默认按钮出现/消失的主要动效。

## 默认按钮动效

- 出现：从 row 背景下方的隐藏位置向右滑入。
- 消失：向左滑回 row 背景下方，路径与出现方向对称。
- 使用 `x` 的 `Behavior`，动画采用 `MotionTokens.fast` 与 `Easing.OutQuint`。
- 遵守 `MotionTokens.reducedMotion`：降低动效时直接切换位置，不保留位移动画。
- 不在进入/退出时改变 row 高度、内容预留宽度或整体面板尺寸。

## Row hover 与输入隔离

- row 的 hover/highlight 只覆盖 row 表面和内嵌控件，不覆盖默认按钮的可见区域。
- `rowHoverArea` 应在 `revertVisibleX` 处截止；不要重新使用 `anchors.fill: parent` 覆盖整个 row。
- 根级 `HoverHandler` 即使被用于观察完整 row，也必须排除默认按钮区域；默认按钮 hover 不得触发 row 的 focus/highlight 边框。
- 默认按钮位于较低 z 层时，检查上方的 `MouseArea`、`HoverHandler` 和 `Rectangle` 是否会吞掉它的 pointer/hover 事件。
- 使用独立按钮 handler 解决输入，不要通过把按钮重新提到 row 背景之上来绕过事件问题，否则会破坏伪月牙裁切。

## 滑条刻度反馈

- 滑条值经过新的离散刻度并真正改变 normalized value 时，才触发反馈；初始化、外部同步和重复设置当前刻度不触发。
- 点击、拖动、键盘左右移动和恢复默认值必须进入同一个 `setValue()` 触发路径，避免不同输入方式产生不同反馈。
- 闪烁层只覆盖已填充的进度本体，不覆盖空余轨道；它应与 `fillRect` 的位置、宽度和高度保持绑定。
- 闪烁层必须是非交互的视觉层，不得改变 slider 的命中区域、布局尺寸、thumb、默认刻度或 row 高度。
- 闪烁参数遵循 osu!lazer `OsuAnimatedButton` 的权威规则：白色等效叠加 `0.3` opacity、`800ms`、`Easing.OutQuint`。
- 闪烁触发时，整个 slider 使用中心锚定的 `Scale` 变换轻微放大到 `1.015`，再用 `220ms`、`Easing.OutQuint` 回到 `1.0`；只能变换视觉，不得修改 `width`/`height`。
- 连续经过刻度时重启反馈，但不允许 scale 累积；每次从 `1.015` 回落到 `1.0`。
- `MotionTokens.reducedMotion` 开启时闪烁 opacity 必须保持 `0`，scale 必须保持 `1.0`，并停止相关动画。
- 测试应覆盖：进度填充范围、非交互层、闪烁时长/曲线、重复刻度、恢复默认、连续触发、reduced-motion 和布局尺寸不变。

## 验证清单

- 检查默认按钮最终宽度、右边缘、z-order 和 row 圆角半径的关系。
- 检查 hover 默认按钮时 `rowHovered` / `rowHighlighted` 仍为 false。
- 检查 hover 时按钮背景和图标变色，按下时有 `pressScale` 反馈，并且点击只触发一次 reset callback。
- 检查从非默认值恢复到默认值后，按钮向左滑回；移除 `defaultValue` 后才变为不可见。
- 修改 QML 后运行相关 `qmllint`、`pytest` 和 `qs -p .`；QML 测试若被 `qrc:/qs-blackhole` 环境资源阻塞，要明确记录。
- 修改滑条反馈后额外检查 `flashOverlay` 是否锚定 `trackFillItem`，以及 `Scale` 是否以 slider 中心为 origin；不要用 width/height 动画制造震动。
