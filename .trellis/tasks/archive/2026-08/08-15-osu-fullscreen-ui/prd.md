# 重构 osu 风格全屏界面

## Goal

将 Afloat 当前以顶部栏附属弹窗为主的界面，重构为接近 osu!lazer 的固定全屏 UI 系统：每屏一个稳定的全屏 owner，共享 backdrop、surface、header、主滚动 viewport、侧栏/content slot、loading 和统一关闭生命周期。页面只使用静态示例数据或现有本地状态，不接入 Wiki、新闻、谱面列表的业务数据。

## Background

- osu 研究报告位于 `.trellis/tasks/archive/2026-08/08-15-osu-fullscreen-panels/research/osu-fullscreen-panels.md`。
- osu 的辨识度主要来自统一全屏页面骨架、空间层级、持久 Header、主滚动区域、侧栏跟随、输入优先级和进出场连续性，而不是局部颜色或圆角。
- 当前 Afloat 已有 `LazerSettingsOverlay`、`LazerSettingsPanel`、`OsuMusicOverlay`、`NotificationHost` 和 per-screen `TopBar`，但这些表面仍是独立的 bar-attached `PanelWindow`，没有形成统一的全屏 route host。
- 当前设置/音乐/通知服务和已有面板行为必须保持可用；本任务重做 UI owner 与静态页面模板，不重写服务协议。

## Requirements

### R1. Shared Fullscreen Owner

- 每个 `Quickshell.screens` 实例只拥有一个用于全屏页面的固定 `PanelWindow`/overlay owner。
- owner 使用 `implicitWidth`/`implicitHeight`，不在动画过程中逐帧改变 layer-shell 宿主尺寸。
- owner 内部持有统一 backdrop、surface、header、主滚动 viewport、loading layer 和 modal input boundary。
- overlay route 由单一状态源管理；页面切换不能创建互相竞争的全屏窗口。

### R2. Static Page Templates

- 至少提供可切换的静态 UI 页面模板，用于验证空间结构，而不是业务数据：
  - Wiki-like：Breadcrumb header、文章目录侧栏、Markdown-like 内容块。
  - News-like：Breadcrumb header、归档侧栏、纵向卡片列表。
  - Beatmap-like：标题/header、搜索与筛选占位、卡片 grid/list。
- 页面内容使用本地静态模型或占位文本，不请求远程 API，不实现分页、搜索、过滤或真实文章解析。
- 页面模板必须共享 header/sidebar/content/loading contract，不能各自复制一套全屏容器。

### R3. Layout And Visual Hierarchy

- 采用 osu 研究中确认的层级：全屏 backdrop -> 固定 surface -> header -> scroll viewport -> sidebar/content。
- Header 必须有独立背景、标题/icon、导航区域和页面 slot；页面状态切换不改变全屏 owner。
- Sidebar 使用稳定宽度和独立滚动区域；主内容使用明确最大宽度、左右内边距和连续垂直节奏。
- 支持 Wiki-like 双栏/全宽 panel、News-like card list、Beatmap-like card grid 的静态布局差异。
- 优先使用层级、留白、字体权重、背景图/渐变、卡片密度和内容节奏体现 osu 风格；颜色和圆角只作为后续 polish。

### R4. Motion And Input

- 打开/关闭使用统一的 backdrop、surface、header 和 content transition；关闭完成后才清理 route/焦点。
- reduced motion 必须移除位移/缩放等空间过渡，但保留必要的 opacity/color feedback。
- Escape 处理优先级固定为：当前输入/可逆页面状态 -> 页面内部返回 -> overlay close。
- PanelWindow 不直接承载 `Keys.*`；焦点和键盘处理放在内部 focused Item。
- 点击 backdrop 可关闭，但不能让透明全屏层长期吞掉非 overlay 区域指针事件。

### R5. Integration And Compatibility

- 保持现有 `SettingsService`、`MediaService`、`NotificationService` 和现有静态测试契约。
- 现有 settings/music/notification 功能可继续通过新的 owner 接入或保持明确的迁移适配层。
- 使用 native QML、现有 `modules/lazerbar/qmldir` 和 per-screen `Variants`，不引入第三方 UI 框架。
- 所有 QML 主要声明遵守项目注释约定；所有可感知视觉属性变化遵守项目 transition 规则。

## Acceptance Criteria

- [ ] 每个屏幕只有一个全屏页面 owner，多个静态页面通过统一 route 切换。
- [ ] 全屏 UI 具备稳定的 backdrop、surface、header、主滚动区、sidebar/content slot 和 loading slot。
- [ ] Wiki-like、News-like、Beatmap-like 三种静态页面布局可切换并共享组件骨架。
- [ ] 页面不请求远程业务数据，不实现业务搜索、分页、过滤或文章解析。
- [ ] Header、侧栏、卡片列表/grid、双栏/全宽 panel 的空间层级接近 osu 研究报告中的结构。
- [ ] 打开、关闭、页面切换、Escape、焦点恢复和 reduced motion 有可测试契约。
- [ ] 不引入全屏透明 pointer catcher；mask/输入区域只覆盖实际 overlay 表面。
- [ ] 相关 QML 测试顺序通过，`qs -p .` 无新增 WARN/ERROR，`git diff --check` 通过。

## Out Of Scope

- 不接入 osu Wiki、News、Beatmap Listing 的 API 或任何远程业务数据。
- 不实现真实新闻归档、文章详情、谱面搜索、过滤、分页、cursor、卡片预览或 Markdown 解析。
- 不重写 `SettingsService`、`MediaService`、`NotificationService` 或数据协议。
- 不逐像素复制 osu!lazer 的资源、字体、音效或 C# framework 内部实现。
- 不修改用户已有的 `.opencode/package.json` 或 `docs/image.png`。

## Open Questions

无阻塞性产品决策。页面使用静态示例内容，重点是全屏结构和视觉层级。
