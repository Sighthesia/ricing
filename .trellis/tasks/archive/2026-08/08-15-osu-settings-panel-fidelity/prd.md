# 还原 osu 设置面板结构与 stagger 动效

## Goal

依据本地 osu!lazer `SettingsPanel` 与 `SettingsSidebar` 源码，重构 Afloat 设置界面的侧栏、主体分离结构、搜索体验、组件布局和 stagger 动效，修正当前“单块面板整体平移”的低还原实现，同时保留现有设置能力与即时保存行为。

## Background

- 当前 Afloat `LazerSettingsOverlay.qml` 只移动一个 `panelHost`，`LazerSettingsPanel.qml` 在同一 Item 内同时绘制导航 rail、header 和内容 viewport。
- osu!lazer `SettingsPanel` 使用两个独立视觉层：`SettingsSidebar` 与 `ContentContainer`。
- osu!lazer Sidebar 展开宽度为 `170px`、收起宽度为 `70px`；Settings 主内容固定为 `400px`，完整展开宽度为 `570px`。
- 本任务采用手动 `70px / 170px` 折叠切换；每次新打开默认展开，关闭期间不持久化折叠状态；不实现悬停自动展开，因为原作 `ExpandOnHover = false` 且构造时 `Expanded = true`。
- 主内容初始 X 为 `-570px + ExpandedPosition`，Sidebar 初始 X 为 `-170px`；二者分别在 `600ms / OutQuint` 内移动到终点。
- 主内容背景向左额外延伸，用于在 Sidebar 与 Content 分离运动时保持连续遮盖，但两者仍是独立 owner layer，而不是一个整体矩形。
- Sections 延迟 `TRANSITION_LENGTH / 3`，即约 `200ms` 后加载，避免重负载干扰初始转场。
- Sidebar 按钮在加载后逐项出现，每项比前一项增加 `40ms` 延迟，并使用 `500ms / OutQuint` 淡入。
- 原作内容主体包含 expandable header、固定搜索框、纵向 settings sections、footer 和滚动阴影；当前 Afloat 使用顶部分类标题加三个并列持久页面，结构并不一致。

## Source Anchors

- osu!lazer `osu.Game/Overlays/SettingsPanel.cs:90-160`: `ContentContainer` is separate from `SettingsSidebar`; content width is `PANEL_WIDTH = 400`, sidebar width is `170`.
- osu!lazer `osu.Game/Overlays/SettingsPanel.cs:175-209`: Content and Sidebar animate independently over `TRANSITION_LENGTH = 600`; content uses `ExpandedPosition`, Sidebar moves from `-sidebar_width`; fade and focus are separate.
- osu!lazer `osu.Game/Overlays/SettingsPanel.cs:181-185`: section loading is delayed by `TRANSITION_LENGTH / 3`.
- osu!lazer `osu.Game/Overlays/SettingsPanel.cs:228-265`: section/footer/search loading and sidebar buttons use `500ms / OutQuint`, with `40ms` per-button stagger.
- osu!lazer `osu.Game/Overlays/Settings/SettingsSidebar.cs:20-39`: Sidebar supports `70px` contracted and `170px` expanded widths, starts expanded, and does not auto-expand on hover.
- 当前 Afloat `modules/lazerbar/LazerSettingsOverlay.qml:15-79`: 一个 `panelHost` 同时拥有位移、尺寸和完整面板内容。
- 当前 Afloat `modules/lazerbar/LazerSettingsPanel.qml:180-310`: 背景、header、viewport 与 rail 全部由同一组件布局，三个页面保持挂载以保存滚动位置。
- 当前 Afloat `modules/lazerbar/LazerSettingsAppearance.qml:35-136`、`LazerSettingsBar.qml:24-49`、`LazerSettingsNotifications.qml:23-31`: 所有可搜索项已使用 `LazerSettingsRow`，可在通用行组件建立标题/描述匹配契约。

## Requirements

- 采用单一 Settings `PanelWindow` 内拆分 owner layer 的架构：保留现有 overlay owner、设置页面实例和数据绑定，不新增 Wayland surface。
- Settings Sidebar 与 Content 必须作为可独立定位、独立动画和独立测试的视觉层，不再由单一 `panelHost` 整体平移。
- 常规布局采用原作 `170px` Sidebar 加 `400px` Content 的尺寸关系，总宽 `570px`；窄屏只允许安全压缩，不改变“侧栏 + 主体”的视觉类型。
- Sidebar 必须支持手动收起到 `70px` 和展开到 `170px`；切换时 Content 左边距同步过渡，header、搜索框和 section viewport 保持在独立 `400px` Content 内稳定布局。
- Sidebar 每次打开默认展开，只在当前打开周期内保存手动折叠状态，不修改设置持久化格式。
- Sidebar 与 Content 分别从左侧进入并退出，正常时长均为 `600ms / OutQuint`，且关闭中重开必须从当前进度反向。
- Sidebar 内导航项按原作 `40ms` 递增延迟出现，形成可见 stagger；关闭时统一淡出并随 Sidebar 退出，所有延迟和动画必须可中断。
- 内容重组件的首次激活延迟约 `200ms`，避免与初始入场争抢首帧；不得改变现有设置数据或持久化语义。
- 重做 Settings 的 expandable header、搜索框、section 列表、Sidebar 导航项、选中态、设置行和 footer 等主要布局与 UI 样式。
- 搜索框必须真实过滤当前分类中的设置行，大小写不敏感地匹配标题或描述；查询词在分类切换时保留并重新应用，空结果显示明确状态。
- 搜索过滤只改变可见性与布局，不卸载控件、不重置滚动位置之外的页面状态，也不触发保存。
- 保留现有 Appearance、Bar、Notifications 设置能力和即时保存行为，但可重新组织其呈现结构以贴近 osu!lazer sections。
- 保留键盘导航、Escape、最终焦点恢复、协调器互斥和 reduced motion 行为。
- reduced motion 下取消 Sidebar/Content 大幅位移及逐项空间 stagger，但保留短淡入和正确加载/焦点顺序。
- 动画仅作用于固定 `PanelWindow` 内部 Item，不逐帧调整 layer-shell window 尺寸或 mask 几何。

## Out of Scope

- 新增 osu!lazer 中 Afloat 没有对应数据源的完整设置分类。
- 复刻设置面板音效。
- 修改设置后端、配置文件格式或持久化 API。
- 跨分类全局搜索、搜索结果跳转或模糊匹配排序。
- 推动或缩放外部 Wayland 应用、bar、岛屿或其他 Afloat surface。

## Acceptance Criteria

- [ ] 入场时能明确看到 Sidebar 与 Content 作为两个独立层运动，而不是一整块面板同步滑入。
- [ ] 常规屏幕下 Sidebar、Content 与总宽分别对应 `170px`、`400px`、`570px`。
- [ ] 手动折叠后 Sidebar 为 `70px`，Content 仍保持可用，展开/折叠不会改变设置数据或焦点归属。
- [ ] 关闭后重新打开时 Sidebar 回到 `170px` 展开态，不新增任何持久化配置字段。
- [ ] Sidebar 导航项以每项 `40ms` 的递增延迟出现，快速关闭/重开时不残留、不跳位、不重复闪烁。
- [ ] 内容区包含可识别的 osu!lazer 式 header、搜索、sections、设置行和 footer 层级。
- [ ] 搜索可按当前分类设置项的标题或描述筛选，分类切换保留查询并重新筛选，无匹配项时显示空结果。
- [ ] Appearance、Bar、Notifications 的现有可用设置仍能即时保存并影响真实 shell。
- [ ] Escape、键盘焦点、协调器互斥和最终焦点恢复测试通过。
- [ ] reduced motion 下无大幅位移，生命周期和控件交互仍正确。
- [ ] 真实 Quickshell 配置加载时无本次改动引入的 WARN/ERROR。

## Risks And Deferred Items

- `400px` Content 会比当前内容区域更窄，现有 row/control 必须在该宽度下采用紧凑布局，避免文字和控件重叠。
- QML 对任意子项反射和动态遍历较脆弱；搜索契约固定由 `LazerSettingsRow` 和页面显式汇总，不建立运行时对象扫描。
- 原作完整 SettingsFooter 的账户、更新与版本能力不属于 Afloat 当前设置域；本任务只还原 footer 的视觉层级和 Afloat 可提供的静态信息/关闭入口。
