# 校准 osu 设置控件还原度

## Goal

逐项检查并校准 Afloat Settings 内滑条、布尔开关、下拉选择、文本框、设置项排版及操作按钮，使其组件类型、尺寸、视觉状态和交互反馈与本地 osu!lazer Settings 控件体系一致，而不改变现有设置数据与持久化格式。

## Confirmed Findings

### P0: Boolean control uses the wrong component model

- 当前 `modules/lazerbar/LazerSettingsToggle.qml:23-71` 是 `46×26px` 的移动 thumb 开关：底色切换，`20px` 圆形 thumb 在左右两端平移。
- osu!lazer `osu.Game/Graphics/UserInterface/Nub.cs:21-25` 使用 `50×15px` 固定 Nub，白色 `3px` 边框；状态通过内部填充、主体宽度和边框厚度变化表达，而不是 thumb 平移。
- osu checked 在 `200ms / OutElasticHalf` 内将主体宽度扩展到 `1.0`、边框增至 `8.5px`；unchecked 以 `200ms / OutQuint` 收到 `0.75` 宽度并恢复 `3px` 边框。
- hover 使用 `40ms` 高亮后接 `800ms / OutQuint` 的 accent/glow 缓和变化，不是简单背景换色。

### P0: Slider omits the defining osu control

- 当前 `modules/lazerbar/LazerSettingsSlider.qml:93-125` 只有 `4px` track、pink fill 和右侧常驻数值文字，没有可见 nub。
- osu!lazer `osu.Game/Graphics/UserInterface/RoundedSliderBar.cs:62-120` 高度为 `15px`，track 为 `5px`，带 `50×15px` Nub 和 `25px` range padding。
- osu nub 随值以 `250ms / OutQuint` 移动，hover/drag 时发光，focus 时 track 有 hollow glow。
- osu slider 支持拖动 nub、点击/拖动 track，以及双击 nub 恢复默认值；当前 Afloat 只支持点击 track 和键盘步进。
- 当前常驻数值标签改变了原作横向构图；osu 默认通过 tooltip 呈现数值。

### P0: Choice is not a dropdown

- 当前 `modules/lazerbar/LazerSettingsChoice.qml:43-67,75-101` 点击、Space 或 Right 会直接循环到下一个值，没有展开菜单、当前项列表、键盘菜单导航或点击外部关闭。
- osu!lazer `osu.Game/Overlays/Settings/SettingsDropdown.cs:15-57` 使用真正的 `OsuDropdown`；header 为全宽控件。
- osu `OsuDropdownHeader` 高 `40px`、圆角 `5px`、底部 margin `4px`、内部 padding `10px`，使用向下 chevron；菜单项具有 preselect/selected/hover 反馈。
- 当前 Afloat `36px` 高、`9px` 圆角、右箭头 `›` 胶囊外观与原作结构不符。

### P1: Text field styling and commit behavior diverge

- 当前 `modules/lazerbar/LazerSettingsTextField.qml:97-136` 为填充式 `38px` 胶囊、`9px` 圆角，并只在 Enter 时 commit。
- osu!lazer `osu.Game/Overlays/Settings/SettingsTextBox.cs:10-16` 使用全宽 `OutlinedTextBox`，并设置 `CommitOnFocusLost = true`。
- 当前 hover 通过整块背景换色表达；原作重点是 outlined border、焦点边界和 SettingsItem 纵向流布局。

### P1: Settings rows use a card layout absent from osu

- 当前 `modules/lazerbar/LazerSettingsRow.qml:57-112` 每项都有独立圆角背景卡片，宽屏时标题/描述在左、控件在右。
- osu!lazer `osu.Game/Overlays/Settings/SettingsItem.cs:189-245` 使用全宽纵向 flow：左侧保留 `20px` revert-to-default 区，内容左 padding `20px`，label 与 control 纵向间隔 `5px`。
- osu SettingsItem 不为每行绘制独立 card；disabled label alpha 为 `0.3`。
- 原作 description 主要作为 tooltip，而当前 Afloat 将其常驻为第二行说明文字，信息密度和垂直节奏不同。

### P1: Header/search/action buttons use generic placeholders

- 当前 `modules/lazerbar/LazerSettingsContent.qml:68-139,142-227` 使用文字 `×`、`«/»`、`⌕` 作为关闭、折叠和搜索图标，并用圆形 hover capsule 包裹。
- 这些操作缺少 osu icon、按压反馈和一致的 hover/glow 语言；搜索框也未复用 OutlinedTextBox 视觉契约。
- Sidebar navigation 使用自定义胶囊选中态，需要与 osu SidebarIconButton 的图标、颜色与选择反馈一并校准。

## Requirements

- 为 Toggle、Slider、Dropdown、TextField 和 SettingsItem 建立基于 osu!lazer 源码的明确尺寸、状态与动画契约。
- Toggle 必须改为 osu Nub 模型，不再显示左右移动 thumb。
- Slider 必须显示可拖动 Nub、`5px` track、hover/drag glow 和 focus feedback。
- Slider 必须支持通过 Nub 双击恢复控件显式提供的默认值；每行必须提供 osu 式 revert-to-default affordance，并只在当前值偏离默认值时显示或激活。
- Choice 必须成为真实 dropdown，支持展开菜单、选择项、键盘导航、Escape/外部关闭和 disabled 状态。
- TextField 必须采用 outlined 样式并支持失焦提交，同时保留现有外部文本同步与焦点所有权保护。
- SettingsRow 必须从独立 card 改为 osu 式全宽纵向 flow，并保留搜索过滤、disabled 状态和窄屏安全布局。
- SettingsRow 默认只显示主标签与控件；description 不再常驻占据第二行，而是在行或控件 hover、键盘 focus 时通过辅助 tooltip 展示。搜索仍匹配 description。
- 校准关闭、折叠、搜索清除、Sidebar 导航等 Settings 内操作按钮的图标和完整 hover/press/focus 状态。
- 所有可见状态变化遵守项目 transition 规则；reduced motion 下取消弹性、位移和 glow 扩张，但保留清晰终态。
- 不修改 SettingsService、配置 schema、值范围、即时保存 API 或三个分类的业务语义。
- 默认值只作为控件/SettingsRow 的显式视觉与交互输入，不写入新的持久化字段；恢复默认仍通过现有 saveCallback 写回原设置对象。

## Out of Scope

- 复制 osu 音效资源或实现 UI 音效。
- 新增 Afloat 不支持的设置项、颜色选择器或数字输入类型。
- 重做已完成的 Sidebar/Content 入退场 owner 架构。
- 修改其他非 Settings 页面使用的通用控件。

## Acceptance Criteria

- [ ] Toggle 视觉结构为 `50×15px` Nub，并通过填充/边框形变表达 checked，不存在移动 thumb。
- [ ] Slider 有 `15px` Nub、`5px` track，可点击和拖动，hover/drag/focus 状态清晰。
- [ ] Slider Nub 双击可恢复显式默认值；SettingsRow 的 revert affordance 可恢复对应设置且不会影响其他行。
- [ ] Choice 点击后打开真实菜单，选择、键盘和关闭行为完整，不再直接循环值。
- [ ] TextField 使用 outlined 状态并在 Enter 或失焦时提交，外部更新和编辑中同步行为不回归。
- [ ] Settings rows 不再呈现为重复卡片，label/control 的 flow、padding 和 disabled alpha 接近 osu。
- [ ] Description 不占据默认行高，hover/focus 时可访问，且仍可被搜索命中。
- [ ] Settings 操作按钮不再依赖 `×`、`«/»`、`⌕` 这类占位文字图标。
- [ ] 所有控件在 hover、press、focus、disabled、reduced motion 状态下均有测试和连续视觉反馈。
- [ ] 现有设置值、即时保存、搜索、页面常驻、键盘焦点与 Overlay 生命周期测试保持通过。

## Decisions

- 完整实现恢复默认：Slider Nub 双击恢复默认，每行提供 revert-to-default affordance。
- Description 改为 hover/focus 辅助 tooltip，不常驻占据行高，仍参与搜索。
