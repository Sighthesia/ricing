> 迁移自旧 skill `lazer-settings-surface-details`。

# Lazer 设置面板细节规范

这份 skill 是 `lazer-ui-style` 的实现级补充。修改设置面板前先确认以下契约，优先复用现有属性和层级，不要另起一套视觉状态。

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
- 设置控件、`IconButton`、`MusicControlButton` 和 `MenuItem` 的已接受点击动作使用同一套 `clickFlashOpacity`、`clickFlashDuration` 与 `clickFlashEasing` tokens；键盘激活必须复用对应的统一 activate 路径。
- 文本框聚焦、搜索清除、设置导航、全屏导航和关闭动作不使用这套点击闪烁；这些动作保留各自的 focus、press 或空间过渡反馈。
- 共享点击闪烁参数固定为 `MotionTokens.clickFlashOpacity: 0.3`、`clickFlashDuration: 800` 和 `clickFlashEasing: Easing.OutQuint`；滑条刻度闪烁也必须复用这些 tokens。
- 点击闪烁层必须暴露为非交互视觉层，测试只通过只读 aliases 检查 `flashActive`、overlay geometry 和 animation timing，不新增生产环境控制入口。
- 侧栏收起/展开、返回和分类项也复用点击闪烁 tokens；闪烁只覆盖各自侧栏表面，不改变侧栏宽度、分类指示器、展开进度或导航布局。
- 测试应覆盖：进度填充范围、非交互层、闪烁时长/曲线、重复刻度、恢复默认、连续触发、reduced-motion 和布局尺寸不变。

## 验证清单

- 检查默认按钮最终宽度、右边缘、z-order 和 row 圆角半径的关系。
- 检查 hover 默认按钮时 `rowHovered` / `rowHighlighted` 仍为 false。
- 检查 hover 时按钮背景和图标变色，按下时有 `pressScale` 反馈，并且点击只触发一次 reset callback。
- 检查从非默认值恢复到默认值后，按钮向左滑回；移除 `defaultValue` 后才变为不可见。
- 修改 QML 后运行相关 `qmllint`、`pytest` 和 `qs -p .`；QML 测试若被 `qrc:/qs-blackhole` 环境资源阻塞，要明确记录。
- 修改滑条反馈后额外检查 `flashOverlay` 是否锚定 `trackFillItem`，以及 `Scale` 是否以 slider 中心为 origin；不要用 width/height 动画制造震动。

## 右键菜单的分页结构

顶栏 widget 的右键菜单是**一个表面内的分页列表**，不是一列不断变长的行，也不是挂在旁边的第二个表面：

- 根页只放能独立决定的命令，按「栏 / 小组件 / 外壳」分成三个区块卡片；块间空隙就是分组，块不画标题行。
- 会展开成控件或清单的东西各占一页（`move`、`widget-settings`、`add-widget`），从带 chevron 的行进入，用页头的返回箭头退出。页头里返回箭头是独立控件，页名只是标题，不做成可点行。
- 页高决定宿主几何：`pageHost` 的裁切高度必须**由滑动进度插值**（`pageClipHeight = from + (to - from) * pageSlideProgress`），不能给它单独的 `Behavior`——160ms 的裁切缓动配 240ms 的滑动，会让新页在整个过场期间被裁在上一页的高度上，面板要等滑动结束才补齐。换页前先把 `_pageSwapActive` 置位再改 `page`：页高是对 `page` 的绑定，先改页会让裁切直接求值到终点，插值形同虚设（实测首帧就是终点高度）。
- 旧的描述（`pageHost` 用 `medium/OutQuint` 过渡）已作废，见上一条。，非当前页 `visible: false`（不是只改 opacity），否则共享同一个节点时下层内容会从上层空隙里透出来，同时污染测量。
- 换页用宿主 hover 弹层交换的滑动：旧页向行进方向滑出、新页从行进方向滑入，各自交叉淡化，一个 `slow/OutCubic` 时钟驱动（`pageSlideProgress` + `pageSlideSign`）；返回根页取反方向。页头跟随所属页一起滑动，但离场期间标题仍写它正在离开的那一页。滑动进行中再换页要先落定旧滑（stop + progress=1），两轨重叠会让方向同时描述两次移动。
- 内容槽（`BarPopupHost` 的 `popupContentSlot`）的高度 `Behavior` 必须**排除 `kind === "context"`**：菜单页自己就在做高度动画（裁切按滑动进度插值），测量值每帧都变，而 `Behavior` 每次变化都从当前值重启、永远追不上——实测测量值 220→340 爬完整个滑动，槽却冻在 220，滑动结束后才补跑自己的 240ms，菜单永远落后自己一个完整动画，表现就是「内容超出面板、等过场结束才长高」。其他 intent 保留该缓动。
- 二级页在已落定的弹层里改高时，宿主必须**直接采纳测量值**，不能重起滑动：`BarPopupHost.retargetGeometry` 的兜底 `startGlide()` 会把 `transitionProgress` 归零，内容每帧长高就每帧归零，面板会一直停在起始高度直到内容长完（实测内容 340、面板卡在 280）。落定态没有别的运动，内容本身就是那段动画，面板贴着它走即可。反过来，内容槽自己的高度 `Behavior` 只能挂在交换期间：它画的是可见面，常开就等于第二套高度时钟（实测面板领先自己内容 164px）。
- 页头槽位必须**骑在滑动时钟上**（`32 * headerWeight`），不能等滑动结束再收：后者会让返回根页时菜单顶部整段留白直到退场完成。同理，包住「页头 + 页」的容器不能是 `Column`——带 `Behavior on height` 的子项在整个动画期间向父布局汇报旧高度，布局收不动；要用显式 y 偏移的两个槽位，页头槽高、间隔和页的 y 都从同一个时钟推导。
- widget 声明的设置项（`services/WidgetSettingsRegistry.js` 的 `controls`）在 `widget-settings` 页里用标准 `LazerSettingsRow` 渲染：`swatch` → `LazerSettingsSwatch`，`slider` → `LazerSettingsSlider`。
- 行的**形状**（kind / label / range / default）来自声明，行的**值**必须逐控件绑到服务读取，不能放进模型：每次写入都会 bump settings revision，模型一旦带值就会在拖动途中重建 delegate，指针下的 slider 直接消失。
- 写入走 `SettingsService.setWidgetInstanceSettingValue`，不要再额外调 `save()`；服务自己已有 debounce。
- 有设置页的 widget（clock / active-window / media 等）仍走设置面板；只有声明了 `controls` 的 widget 才有本地 `widget-settings` 页。
- 「添加小组件」是两列图标 + 名称网格，不是一列带描述的卡片：一个 widget 名字本身就是要做的决定，第二行说明只会把页面撑长。
