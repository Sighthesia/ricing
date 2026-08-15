# Settings Control Fidelity Design

## Architecture

保留现有 Settings owner、Sidebar/Content 分层、页面常驻和服务绑定。此次只替换 Settings 内部控件的 presentation components 与 SettingsRow 布局，不新增 compositor surface，不修改配置 schema。

组件层次：

```text
LazerSettingsContent
  ├─ Settings action buttons / search field
  ├─ persistent category Flickable
  │   └─ LazerSettingsRow
  │       ├─ revert affordance
  │       ├─ label
  │       └─ one control
  │           ├─ LazerSettingsNub
  │           ├─ LazerSettingsSlider
  │           ├─ LazerSettingsChoice
  │           └─ LazerSettingsTextField
  ├─ tooltip layer
  └─ dropdown menu layer
```

Tooltip 和 dropdown 必须由 `LazerSettingsContent` 的顶层 overlay layer 承载，不能放入 category Flickable，否则会被 viewport clip。控件通过信号请求 Content 显示辅助层；Content 统一处理当前 owner、Escape、点击外部和焦点归还。

## Shared Nub Primitive

新增 `LazerSettingsNub.qml`，供 Toggle 和 Slider 复用：

- 基准尺寸 `50×15px`，白色 `3px` border。
- `checked` 模式：内部 accent fill；主体由 `0.75` 宽过渡到全宽，border 从 `3px` 过渡到 `8.5px`。
- Slider 模式：保持 Nub 轮廓与 hover glow，但不使用 checked 填充形变。
- hover/drag 时 accent 和 glow 增强；focus 时保留可见轮廓。
- normal transition 参考原作 `200ms`、`250ms`、`40ms + 800ms`；QML 无原生 OutElasticHalf 时使用项目批准的近似 bezier/spring-like easing，但测试固定时长和终态。
- reduced motion 直接到达几何终态，颜色仍短时淡变。

## SettingsRow Contract

`LazerSettingsRow` 从横向 card 变为全宽 vertical flow：

- 左侧 `20px` revert 区。
- 内容左 padding `20px`，右 padding `20px`。
- label 与 control 垂直间隔 `5px`。
- 无逐行背景 card；hover 仅用于 tooltip/revert 反馈。
- description 不参与默认高度，通过 tooltip 展示，但仍传入 `matchesSearch()`。
- disabled alpha 为 `0.3`，搜索可见性与 disabled 独立。
- 行接收 `defaultValue`、`currentValue` 和 `resetCallback`，派生 `hasDefault`、`isDefault`、`canReset`。
- revert affordance 仅在非默认值时显现；pointer/keyboard 激活调用页面提供的 reset callback，页面继续使用现有 save 路径。

为避免 QML 动态类型比较分散，默认值相等判断集中到 `LazerSettingsLogic.valuesEqual()`，覆盖 number/string/bool，数字允许很小的浮点误差。

## Slider Contract

- Slider 高 `15px`，track 高 `5px`，左右 range padding `25px`。
- 移除常驻右侧数值标签；hover、drag 或 focus 时通过 Content tooltip 显示 `displayText`。
- 支持 track click、pointer drag、Left/Right 键和 Nub 双击恢复 `defaultValue`。
- Nub X 使用 normalized fraction，值变化 `250ms / OutQuint`；用户 drag 时禁用追赶动画，直接跟指针。
- 拖动过程中通过现有 `valueModified` 实时保存，保持当前 shell 即时反馈。
- disabled 时整体 alpha `0.3`，停止 hover/drag/focus input。

## Toggle Contract

- `LazerSettingsToggle` 组合 `LazerSettingsNub`，不再拥有移动 thumb。
- pointer、Space、Enter/Return 仍触发 `toggled(!checked)`。
- checked/unchecked、hover、focus、disabled 与 reduced-motion 状态由 Nub 统一呈现。

## Dropdown Contract

`LazerSettingsChoice` 保留公开 `model/currentValue/valueSelected`，但改为真正 dropdown：

- header 高 `40px`、圆角 `5px`、padding `10px`、向下 chevron。
- pointer、Enter、Space 或 Alt+Down 打开菜单；Left/Right 不再直接修改值。
- 菜单包含全部 model items，当前项 selected，键盘 Up/Down preselect，Enter 选择，Escape 关闭。
- 点击 Content 内菜单外区域关闭并把 focus 还给 header。
- 菜单最大高度 `200px`；在 Content 宽度和剩余 viewport 内向下或向上放置。
- 菜单是 Content 内 Item，不新建 `PopupWindow`，避免增加 layer-shell/focus surface。

## Text Field Contract

- 改为 outlined 表面，圆角接近 `5px`，全宽布局。
- Enter 和 focus lost 均 commit；仅当 trimmed text 与最近已提交文本不同才发出，避免重复保存。
- 保留当前“编辑中外部更新延迟同步”的 focus ownership 机制。
- clear/reset 分离：row revert 恢复默认，字段自身不增加额外常驻清除按钮。

## Action Buttons And Icons

- 新增本地 SVG：close、chevron-left/right/down、search、undo/reset；遵循现有 `icons/*.svg` 纯静态资源方式。
- Settings header、search clear、collapse、Sidebar navigation/revert 使用 `Image` 图标和统一 hover/press/focus transition，不再使用 Unicode 占位符。
- 不引入外部 icon package 或运行时服务依赖。

## Default Values

默认值来自当前页面已有 fallback，作为显式控件输入：

- Appearance: `""`, `auto`, `0.9`, `false`, `0.35`, `0.56`, `0.22`, `true`, `true`。
- Bar: `48`, `top`, `false`, `4`, `12`。
- Notifications: `false`, `3`, `5`, `top-right`。

reset callback 修改同一 settingsObject 属性并调用同一 saveCallback。没有设置对象时 affordance disabled，不产生假保存。

## Focus And Escape

- Dropdown open 时 Escape 先关菜单；TextField 编辑时 Escape 保持现有 Overlay 关闭语义，除非未来另立编辑取消需求。
- Tooltip 不获取 focus。
- Dropdown 关闭后 focus 返回 header；过滤或切页时强制关闭旧菜单和 tooltip。
- Tab 只访问可见、enabled 的 row control 和 revert affordance。

## Compatibility

- 保留 Toggle `toggled`、Slider `valueModified`、Choice `valueSelected`、TextField `textCommitted/clearRequested` 信号。
- 保留现有测试需要的 control aliases；新增视觉内部 alias 只用于精确测试。
- 不改变值范围、normalize 函数、SettingsService 或 save callback。
- 不复用顶栏 `DropdownMenu.qml`：它的 `236px` popup/card 视觉和 menu item 契约不是 osu SettingsDropdown，强行复用会继续偏离原作。

## Risks

- QML pointer drag 与 Flickable 纵向滚动可能竞争；Slider handler 只在横向拖动占优后抓取，测试同时覆盖页面仍可纵向滚动。
- Content overlay tooltip/menu 的坐标映射需避免窄屏越界。
- focus-lost commit 与 reset callback 可能重复保存；TextField 必须维护 last committed value 去重。
- 浮点默认值比较必须使用 epsilon，不能直接严格相等。
