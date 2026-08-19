# osu Settings Layout Rules

这份文档记录 `/home/Sighthesia/0_Files/Producing/Software/Quickshell/osu` 中设置面板和相关 Form 控件的源码数值，作为 Afloat 设置面板后续视觉校准的参考基线。

## 适用范围

osu 当前同时存在两套设置控件体系：

- 旧版 `SettingsItem`：主要负责设置项的外层布局和传统控件。
- 新版 `SettingsItemV2` + `Form*`：使用 `FormControlBackground`、统一的 5px 圆角和独立的表单控件排版。

当前 Afloat 的设置面板视觉更接近新版 `Form*` 体系，因此下列规则优先采用新版数值。旧版数值单独列出，不应与新版混用。

## 面板级布局

| 规则 | 数值 | 来源 |
| --- | ---: | --- |
| 设置内容区域宽度 | 400px | `osu.Game/Overlays/SettingsPanel.cs:44` |
| 设置侧栏宽度 | `SettingsSidebar.EXPANDED_WIDTH` | `osu.Game/Overlays/SettingsPanel.cs:39` |
| 面板总宽度 | 侧栏宽度 + 400px | `osu.Game/Overlays/SettingsPanel.cs:49` |
| 内容外边距 | 20px | `osu.Game/Overlays/SettingsPanel.cs:32` |
| 设置项内容左内边距 | 12px | `osu.Game/Overlays/SettingsPanel.cs:35` |
| 设置项内容右内边距 | 22px | `osu.Game/Overlays/SettingsPanel.cs:35` |
| 新版设置项垂直间距 | 4px | `osu.Game/Overlays/Settings/SettingsSection.cs:38`; `SettingsSubsection.cs:42-45` |
| 旧版设置项垂直间距 | 14px | `osu.Game/Overlays/Settings/SettingsSection.cs:37` |

`CONTENT_PADDING` 的右侧 22px 是为恢复默认按钮预留的空间，不应被解释为控件本体的右内边距。新版 `SettingsItemV2` 将整个设置项内容包在该 padding 中，恢复按钮位于同一内容容器的右上角：`osu.Game/Overlays/Settings/SettingsItemV2.cs:41-67`。

## 通用控件外观

新版 `FormControlBackground` 是下拉框、输入框、滑条等表单控件的共同背景层：

| 规则 | 数值 | 来源 |
| --- | ---: | --- |
| 控件圆角 | 5px | `osu.Game/Graphics/UserInterfaceV2/FormControlBackground.cs:45-48` |
| 圆角指数 | 2.5 | `osu.Game/Graphics/UserInterfaceV2/FormControlBackground.cs:19,48` |
| 聚焦边框厚度 | 2.5px | `osu.Game/Graphics/UserInterfaceV2/FormControlBackground.cs:20,49` |
| hover 状态 | `Background5 -> Dark4` 垂直渐变 + `Light4` 边框 | `osu.Game/Graphics/UserInterfaceV2/FormControlBackground.cs:96-100` |
| focused 状态 | `Background5 -> Dark3` 垂直渐变 + `Highlight1` 边框 | `osu.Game/Graphics/UserInterfaceV2/FormControlBackground.cs:102-106` |
| 普通状态 | `Background4.Darken(0.1)`，不显示边框 | `osu.Game/Graphics/UserInterfaceV2/FormControlBackground.cs:86-89,112-114` |

新版控件的聚焦框不是静态白色描边：背景和边框都通过 250ms `OutQuint` 过渡更新：`FormControlBackground.cs:112-114`。

## 下拉框

### 下拉框标题

`FormDropdown` 的标题是一个独立的 5px 圆角控件：

| 规则 | 数值 | 来源 |
| --- | ---: | --- |
| 标题圆角 | 5px | `osu.Game/Graphics/UserInterfaceV2/FormDropdown.cs:154-155` |
| 标题内容容器内边距 | 9px，四边 | `FormDropdown.cs:163-168` |
| 标题内垂直排版间距 | 4px | `FormDropdown.cs:170-176` |
| 标题与右侧 chevron 间的文本保留宽度 | 25px | `FormDropdown.cs:183-187` |
| chevron 尺寸 | 16x16px | `FormDropdown.cs:191-197` |
| chevron 右侧间距 | 5px | `FormDropdown.cs:197-198` |
| 标题与下拉列表之间的间距 | 5px | `FormDropdown.cs:47`; `FormDropdown.cs:303-306` |
| 标题最小结构高度 | 由内容自动计算 | `FormDropdown.cs:165-189` |

标题展开时使用 `VisualStyle.Focused`，而不是改变成普通 hover 背景：`FormDropdown.cs:240-254`。这正是 Afloat 当前下拉框应该遵循的状态切换方式。

### 下拉列表容器

| 规则 | 数值 | 来源 |
| --- | ---: | --- |
| 列表外层圆角 | 5px | `osu.Game/Graphics/UserInterface/OsuDropdown.cs:67-69` |
| 列表边框厚度 | 2.5px | `osu.Game/Graphics/UserInterfaceV2/FormDropdown.cs:294-296`; 厚度来自 `FormControlBackground.BORDER_THICKNESS` |
| 列表内边距 | 9px，四边 | `FormDropdown.cs:287-292` |
| 列表最大高度 | 200px | `FormDropdown.cs:39-43` |
| 列表展开动画 | 300ms，`OutQuint` | `OsuDropdown.cs:90-95,109-121` |
| 展开后与标题的 margin | 顶部 5px | `FormDropdown.cs:299-306` |

### 下拉选项

新版 Form 下拉列表最终复用 `OsuDropdown` 的选项 delegate：

| 规则 | 数值 | 来源 |
| --- | ---: | --- |
| 选项 Foreground 内边距 | 2px，四边 | `osu.Game/Graphics/UserInterface/OsuDropdown.cs:230-235` |
| 选项圆角 | 5px | `OsuDropdown.cs:237-239` |
| 选项文字左侧额外内边距 | 15px | `OsuDropdown.cs:298-304` |
| 子菜单 chevron 尺寸 | 8px | `OsuDropdown.cs:287-294` |
| 子菜单 chevron 左右 margin | 3px | `OsuDropdown.cs:294-296` |

关键结论：列表背景应贴近列表边框，仅保留列表容器自身的 9px 内边距和选项 delegate 的 2px Foreground 内边距。若把整个 `ListView` 再额外缩进 4px 或同时给选项 delegate 加较大的外边距，就会出现“列表背景离边框不贴”的视觉问题。

## 输入框

新版 `FormTextBox` 与下拉框共享相同的背景层：

| 规则 | 数值 | 来源 |
| --- | ---: | --- |
| 外层内容内边距 | 9px，四边 | `osu.Game/Graphics/UserInterfaceV2/FormTextBox.cs:103-108` |
| caption 与输入内容的垂直间距 | 4px | `FormTextBox.cs:107-109` |
| 输入框相对宽度 | 100% | `FormTextBox.cs:118-123` |
| 内部文本框高度 | 16px | `FormTextBox.cs:211-216` |
| 内部文本框左右 padding | 0，由外层 9px 提供 | `FormTextBox.cs:198-205` |
| 输入框圆角和聚焦框 | 统一由 `FormControlBackground` 提供 | `FormTextBox.cs:97`; `FormTextBox.cs:178-195` |

输入框失焦后会回到 Normal 或 Hovered 状态；只有 `textBox.Focused.Value` 为真时才进入 Focused：`FormTextBox.cs:178-195`。

## 滑条

`FormSliderBar` 的排版比普通输入框更复杂，使用左右两列：左侧数值输入区，右侧滑条。

### 外层与左侧数值区

| 规则 | 数值 | 来源 |
| --- | ---: | --- |
| 外层内容上下 padding | 5px | `osu.Game/Graphics/UserInterfaceV2/FormSliderBar.cs:213-221` |
| 外层内容左 padding | 9px | `FormSliderBar.cs:217-221` |
| 外层内容右 padding | 5px | `FormSliderBar.cs:217-221` |
| 左侧区域宽度 | 50% | `FormSliderBar.cs:225-231` |
| 左侧区域右 padding | 10px | `FormSliderBar.cs:232-236` |
| 左侧区域上下 padding | 4px | `FormSliderBar.cs:232-236` |
| caption 与数值内容垂直间距 | 4px | `FormSliderBar.cs:225-230` |
| 数值 label 右 padding | 5px | `FormSliderBar.cs:265-269` |

### 右侧滑条

| 规则 | 数值 | 来源 |
| --- | ---: | --- |
| 滑条区域宽度 | 50% | `FormSliderBar.cs:274-280` |
| 滑条高度 | 40px | `FormSliderBar.cs:464-469` |
| 滑块/范围补偿宽度 | 5px | `FormSliderBar.cs:458-469`，`NUB_WIDTH = 10` 后取一半 |
| 滑条圆角 | 5px | `FormSliderBar.cs:474-478` |
| 滑条内部左右 padding | 5px | `FormSliderBar.cs:496-499`，由 `RangePadding` 提供 |

## 复选框与侧栏参考

| 规则 | 数值 | 来源 |
| --- | ---: | --- |
| 设置侧栏整体 padding | 40px | `osu.Game/Overlays/Settings/SettingsSidebar.cs:73` |
| 侧栏项目间距 | 5px | `SettingsSidebar.cs:82-83` |
| 侧栏按钮高度 | 46px | `SidebarIconButton.cs:60-63` |
| 侧栏按钮内部 padding | 5px | `SidebarIconButton.cs:63` |
| 侧栏选中指示条宽度 | 4px | `SidebarIconButton.cs:91-94` |
| 侧栏选中指示条 inactive 高度 | 10px | `SidebarIconButton.cs:91-98` |

## Afloat 对齐建议

针对当前下拉列表“背景离边框不贴”的问题，优先按以下顺序校准：

1. 将下拉列表外层背景和边框绑定在同一个矩形上，圆角使用 5px。
2. 列表外层保留 9px 内边距，不要在外层再叠加额外的 4px 缩进。
3. 选项本身只保留约 2px 的内部 foreground padding；文字左侧按 15px 的 osu 参考值排版。
4. 标题与列表之间保留 5px 空隙，标题内部使用 9px padding，右侧 chevron 使用 16px 尺寸和 5px 右间距。
5. 菜单展开时标题和列表都应进入 Focused 状态；普通 hover 只进入 Hovered 状态，不应使用固定的常驻白色描边。
6. 滑条使用 40px 高度，整体上下 5px、左 9px、右 5px；右侧轨道两端应考虑 5px 的滑块范围补偿。

## 证据边界

- 上述数值均来自 osu 源码中的显式常量、`MarginPadding`、`Spacing`、`Width`、`Height`、`CornerRadius` 或 `RangePadding` 设置。
- 未列出的默认值（例如 Framework 基类的默认菜单 item 高度、字体实际字高、边框默认颜色）不应从本文件推导。
- `OsuDropdown` 的旧版菜单使用 5px `ItemsContainer.Padding`，而 `FormDropdownMenu` 覆盖为 9px；Afloat 对齐新版 Form 设置面板时应采用 9px，而不是旧版 5px。
