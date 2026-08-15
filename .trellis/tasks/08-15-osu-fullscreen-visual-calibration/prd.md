# 校准 osu 全屏界面设计

## Goal

依据本地 osu!lazer 真实源码重新设计 Afloat 全屏覆盖页面，消除当前居中圆角卡片与混合风格，使页面从屏幕底部出现并在展开后与顶部 bar 连续衔接。仅在设计及书面规格获批后实施。

## Background

- 当前 Afloat `FullscreenOverlayHost.qml` 将页面表现为有限宽高、居中的圆角 surface，与目标不符。
- 本地 `/home/Sighthesia/0_Files/Producing/Software/Quickshell/osu` 包含完整 osu!lazer 源码，可作为主要设计依据。
- osu!lazer 的 Wiki、News、Beatmap Listing 属于 `FullscreenOverlay<T>` 体系，而不是普通 `OsuScreen` 页面。
- `FullscreenOverlay<T>` 顶部居中、宽度为可用屏幕的 85%，启用裁切但未设置圆角；主体背景、header 与内容处于同一连续 surface。
- `WaveOverlayContainer` 使用 `WaveContainer` 驱动四层倾斜色带和主体从底部进入。主体入场时长为 800ms、`OutQuint`，退场时长为 500ms、`In`；wave 分别使用 `OutSine` 与 `InSine`。
- osu!lazer Toolbar 为固定顶部层；fullscreen overlay 在其下方视觉展开，而非带四周留白的独立浮动对话框。
- Afloat 虽支持底部 bar，但本任务的 osu!lazer fullscreen 几何只以顶部 bar 为设计基准，不镜像原作动效。
- Wiki 和 News 在共享 overlay 框架内提供专属 header、滚动内容与可选 sidebar；页面切换不创建新的顶层窗口。
- osu!lazer 的 Settings 不属于 fullscreen overlay：它是从左侧进入并推动/偏移主画面的侧栏。
- osu!lazer 的 Music 不属于 fullscreen overlay：Toolbar Music Button 控制独立的 Now Playing overlay。

## Requirements

- 视觉形态必须以 osu!lazer `FullscreenOverlay<T>`、`WaveOverlayContainer`、`WaveContainer` 的源码行为为准，不再沿用当前圆角玻璃卡片表达。
- 覆盖页面必须从屏幕底部进入，并在完全展开后与顶部 bar 形成连续边界；关闭时沿相反路径退回底部。
- 必须完整实现四层 wave 揭示，不得简化为双层色带或仅主体滑动；四层分别保留独立倾角、色阶和纵向运动。
- 主体入场采用 800ms `OutQuint`，退场采用 500ms `In`；wave 入场采用 `OutSine`，退场采用 `InSine`，以匹配 osu!lazer 源码节奏。
- 无论 Afloat bar 当前配置在顶部还是底部，fullscreen 始终从屏幕底部进入并停靠到屏幕顶部的基准位置；底部 bar 不触发从顶部进入的镜像动效。
- 覆盖页面主体宽度固定为可用屏幕的 85%，原样保留 osu!lazer 的左右背景留白比例，不扩展为全宽或响应式宽度。
- Wiki、News、Beatmap 每屏共享一个固定 Wave Fullscreen `PanelWindow` owner；Settings 与 Music 使用各自独立 owner。所有动画只作用于内部内容，避免逐帧调整 layer-shell surface 大小。
- Wiki、News、Beatmap 三个静态页面继续共享 overlay 生命周期，但各自保留 osu!lazer 对应的 header、sidebar 与内容结构差异。
- Wiki、News、Beatmap 的内部视觉也必须按 osu!lazer 对应实现重做，包括 header、主题色分区、sidebar、卡片比例与排版，不保留当前页面的混合视觉风格。
- 页面颜色使用 osu!lazer 固定 overlay colour scheme，不由 Afloat 壁纸动态主题替换：Wiki 使用 Orange、News 使用 Purple、Beatmap 使用原作对应 scheme，正文中性色从同一 overlay 色阶派生。
- 页面内容继续使用少量本地静态模型，只需撑起滚动、sidebar、列表与网格等主要排版验证；内容语义、完整度和真实数据密度不作为还原目标。
- Settings 必须恢复为 osu!lazer 风格的左侧滑入面板，不得继续表现为 wave fullscreen 页面。
- Settings 以覆盖桌面的方式从左侧进入，保留 osu!lazer 的 sidebar 加 400px 主内容比例与 600ms 转场；不得尝试移动外部 Wayland 应用窗口，也不推动 Afloat 自有 bar 或岛屿。
- Music 必须恢复为独立的 osu!lazer 风格 Now Playing overlay，不得继续表现为 wave fullscreen 页面。
- Settings、Music 与 fullscreen 页面共享互斥状态协调，但分别拥有与原作一致的视觉容器和进退场行为。
- 架构采用薄 `OverlayCoordinator` 加三类独立 owner：Wave Fullscreen、Settings Side Panel、Now Playing 分别拥有适合自身几何与输入范围的 `PanelWindow`；协调器不承载视觉内容。
- 三类 owner 必须互斥。跨类型切换时先完成或安全打断当前退场，再显示目标 owner，禁止多个 overlay 同时可交互。
- Settings 与 Music 不得因视觉重构失去打开、关闭、键盘控制和焦点恢复行为。
- 85% fullscreen overlay 左右露出的区域可点击关闭，这是面向桌面 shell 的明确适配；点击必须走完整退场生命周期，与 Escape 行为一致。
- reduced motion 下取消大幅位移及 wave 运动，保留短淡入淡出和完整生命周期语义。
- 不引入远程 API 或真实业务数据。

## Out of Scope

- 复刻 osu!lazer 的在线数据请求、分页、搜索和筛选业务逻辑。
- 深入制作 Wiki 正文、News 文章内容、Beatmap 元数据或其他内容资产；本任务聚焦主要排版和 UI 样式。
- 修改顶部 bar 本身与本任务无关的按钮、服务或数据源。
- 为适配底部 bar 而镜像 fullscreen 进退场方向。
- 通过 compositor 或窗口管理器移动、缩放外部应用，以模拟 osu!lazer Settings 推动游戏主画面的效果。
- 复刻 osu!lazer 音效。
- 完全复制 osu!lazer“点击 overlay 外侧不关闭”的输入行为；Afloat 明确保留外侧点击关闭。

## Acceptance Criteria

- [ ] 打开 Wiki、News 或 Beatmap 时，界面不再显示为四周悬浮的圆角卡片。
- [ ] 主体从屏幕底部滑出；顶部 bar 配置下最终顶部边缘与 bar 下沿无缝相接，底部 bar 配置下最终停靠屏幕顶边；关闭时均退回屏幕底部。
- [ ] 视觉层次能对应 osu!lazer 的四层 wave 揭示、连续背景、header、内容区和 sidebar 结构。
- [ ] 四层 wave 在快速打开、关闭及反向打断时保持正确层序，不穿出 85% overlay 边界。
- [ ] 点击 overlay 左右外侧区域触发完整 wave 退场，而不是立即隐藏、闪退或把点击穿透到底层桌面。
- [ ] 快速打开、关闭、换路由时没有闪白、跳位、旧页面残留或 owner 尺寸抖动。
- [ ] Settings、Music、Wiki、News、Beatmap 路由以及 Escape 和焦点恢复回归测试通过。
- [ ] Settings 从左侧进入，Music 使用独立 Now Playing 呈现，二者均不套用 fullscreen wave surface。
- [ ] Settings 打开和关闭期间，外部应用与其他 Afloat surface 保持原位，面板自身平滑完成 600ms 横向转场。
- [ ] Wiki、News、Beatmap 即使隐藏文字内容，也能通过 header、主题色、sidebar 与主体布局辨认出各自对应的 osu!lazer 页面类型。
- [ ] 切换壁纸或 Afloat 动态主题时，三个页面的 osu!lazer 固定主题身份不发生漂移。
- [ ] reduced motion 模式下无大幅滑动，但页面仍能正确打开、关闭和切换。
- [ ] 真实 Quickshell 配置加载时无本次改动引入的 WARN/ERROR。

## Technical Notes

- 当前 `.trellis/spec/frontend/quality-guidelines.md` 的 `Shared Fullscreen Route Owner` 场景记录了上一版将 Settings、Music 与三种页面放入同一 owner 的规则。实施时必须将该规则迁移为“协调器加按视觉类型拆分 owner”，避免新代码与项目规范冲突。
- 本任务为复杂视觉重构，必须在实施前完成 `design.md` 与 `implement.md` 并获得用户对书面规格的再次确认。
