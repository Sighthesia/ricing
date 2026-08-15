# 研究 osu 全屏面板实现

## Goal

基于 `/home/Sighthesia/0_Files/Producing/Software/Quickshell/osu` 的实际源码，解释 osu!lazer 的 Wiki、新闻、谱面列表等全屏面板如何构建，并提炼 Afloat 前端重做时可以直接采用的结构、交互和视觉原则。

## Background

- 当前 Afloat 界面与 osu!lazer 的页面组织和视觉层级差异明显，不能只靠颜色、圆角或按钮样式接近。
- CodeGraph 初步证据显示 Wiki、新闻和谱面列表都继承 `OnlineOverlay` / `FullscreenOverlay` / `WaveOverlayContainer`，共用全屏生命周期、Header、滚动和 loading 机制。
- 页面差异主要位于 Header 类型、内容布局、侧栏、筛选器、列表/详情状态和数据加载策略，而不是各自创建独立全屏窗口。

## Requirements

### R1. Shared Architecture

- 追踪 `WaveOverlayContainer -> FullscreenOverlay -> OnlineOverlay -> concrete overlay` 的继承与调用路径。
- 说明全屏尺寸、背景、Header、ScrollFlow、Loading、Child 交换、打开/关闭和 Escape/back 行为。
- 区分固定骨架、可替换 slot 和页面自己管理的状态。

### R2. Wiki

- 分析 Wiki 索引页、文章页、面包屑、目录侧栏、Markdown 和滚动同步。
- 说明首页双栏/全宽 panel 与文章页固定侧栏布局的差异。

### R3. News

- 分析新闻 Header、年份/月归档侧栏、文章列表、分页加载和列表/详情切换。
- 明确当前源码中新闻文章详情是否完整实现，避免把占位逻辑描述成成品。

### R4. Beatmap Listing

- 分析谱面列表 Header、搜索输入、过滤器行、背景封面、卡片尺寸切换、结果网格、分页和空状态。
- 说明 Escape 的分层语义：先清搜索/回顶部，再关闭 overlay。

### R5. Transfer To Afloat

- 输出 osu 机制到 Quickshell/QML 的映射：窗口所有权、状态模型、布局分层、滚动、异步加载、动效和输入。
- 标注不可直接照搬的 osu-framework 特性，并给出等价 QML 机制。
- 提供按优先级排序的 Afloat 重做建议，但不在本任务修改产品代码。

## Acceptance Criteria

- [x] 研究报告包含共享架构图和三个具体页面的数据/交互流。
- [x] 每项关键结论都有准确的源码路径、符号和行号证据。
- [x] 明确共同骨架与页面特例，不把三个页面描述为三套独立实现。
- [x] 明确 News 文章详情等尚未实现或不完整的部分。
- [x] 输出可用于后续 Afloat 设计任务的组件分层和迁移优先级。
- [x] 全程只读 osu 仓库，不修改 osu 或 Afloat 产品代码。

## Out Of Scope

- 不在本任务实现或重写 Afloat 全屏面板。
- 不逐像素复刻 osu!lazer，也不复制其受框架限制的内部 API。
- 不研究游戏内 HUD、谱面编辑器、Mod Select 等与本次页面系统无关的全屏界面。
- 不评估 osu web 前端实现。

## Open Questions

无阻塞问题。输出以本地 osu 仓库当前源码为唯一实现依据。
