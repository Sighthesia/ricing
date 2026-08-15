# 研究：osu!lazer 全屏面板与 Afloat QML 映射

- **Query**：基于本地 osu!lazer 源码研究 Wiki、News、Beatmap Listing 全屏面板，并提炼 Afloat 前端重做可采用的结构、交互与视觉原则。
- **Scope**：内部源码研究；主证据为 `/home/Sighthesia/0_Files/Producing/Software/Quickshell/osu` 当前源码及其视觉测试。
- **Date**：2026-08-15

## 1. 执行摘要

只复制颜色、按钮、圆角不会像 osu，是因为 osu 的辨识度首先来自**持久的全屏页面模型**，而不是局部皮肤：所有三个页面都进入同一条 `OsuFocusedOverlayContainer → WaveOverlayContainer → FullscreenOverlay<THeader> → OnlineOverlay<THeader>` 骨架；页面只替换 header/content/sidebar 和数据状态。全屏尺寸、波浪背景、输入阻塞、滚动容器、加载层、页面切换和进出场生命周期因此保持一致，而 Wiki、News、Beatmap Listing 又分别通过面包屑、归档侧栏、筛选/结果流表达自己的信息架构。

最重要的可迁移结论是：Afloat 应先建立一个固定的 overlay owner 和路由状态，再做页面 slot；先复制**空间层级、滚动和状态切换**，最后才做颜色、阴影和卡片 polish。若把三个页面做成三个独立弹窗，即使使用相同圆角和配色，也会失去 osu 的“同一产品中的页面系统”感。

## 2. 共享架构与生命周期

### 2.1 继承与组合

```text
OsuFocusedOverlayContainer
  └─ WaveOverlayContainer
      └─ FullscreenOverlay<THeader>
          └─ OnlineOverlay<THeader>
              ├─ WikiOverlay : OnlineOverlay<WikiHeader>
              ├─ NewsOverlay : OnlineOverlay<NewsHeader>
              └─ BeatmapListingOverlay : OnlineOverlay<BeatmapListingHeader>
```

- `OsuFocusedOverlayContainer` 实现全局 Back/Select key binding，并默认阻断非位置输入；Back 直接 `Hide()`（`osu.Game/Graphics/Containers/OsuFocusedOverlayContainer.cs:18-27,102-118`）。它还接管屏幕外点击关闭、全屏鼠标命中和 overlay manager 的 blocking overlay（同文件 `:67-90,124-169`）。因此页面不需要各自重新实现“点外部关闭”和基础输入隔离。
- `WaveOverlayContainer` 将 `Content` 指向 `WaveContainer`，创建覆盖全尺寸的 waves，设为 start hidden，并关闭 overlay 层重复播放的 pop 音效（`osu.Game/Overlays/WaveOverlayContainer.cs:10-32`）。Pop-in 显示 waves 后 100ms 淡入；Pop-out 先隐藏 waves、按 disappear duration 淡出，完成后才调用基类（同文件 `:35-49`）。
- `FullscreenOverlay<T>` 重新创建具体 header，设置 `RelativeSizeAxes = Both`、`RelativePositionAxes = Both`、宽度为父宽的 `0.85f`，顶部居中、mask 和空心阴影（`osu.Game/Overlays/FullscreenOverlay.cs:19-73`）。它拥有 `ColourProvider`、背景 Box 和内容容器，并把四层 wave 颜色和背景色统一更新（同文件 `:76-113`）。
- `OnlineOverlay<T>` 固定提供 `OverlayScrollContainer ScrollFlow`、`LoadingLayer Loading` 和可替换的 `content`。ScrollFlow 内部是纵向 flow：`Header → content`，外加 context menu/popover；Loading 是覆盖全尺寸的另一层（`osu.Game/Overlays/OnlineOverlay.cs:15-75`）。加载完成时把 scroll-to-top proxy 提到固定 header 之上；loading layer 的 top padding 随 header 与 scroll 位置计算，避免遮挡 header（同文件 `:78-92`）。

### 2.2 尺寸、遮挡与 slot

固定骨架由 overlay owner、wave/background、header 和 ScrollFlow 组成；页面可替换 slot 是 `CreateHeader()`、`OnlineOverlay.Content` 的实际 child，以及页面内部自己的 sidebar/content。`OverlayHeader` 本身只有 header background、title row、可选 header content 三个层；`CreateBackground()`、`CreateContent()`、`CreateTitle()` 是明确的替换点（`osu.Game/Overlays/OverlayHeader.cs:12-103`）。

`OnlineOverlay` 的 content slot 是动态加载的：`LoadDisplay()` 先 `ScrollToStart()`，异步完成后替换 child，再隐藏 Loading（Wiki：`osu.Game/Overlays/WikiOverlay.cs:86-94`；News：`osu.Game/Overlays/NewsOverlay.cs:125-133`）。这意味着 loading owner 属于共享 overlay，而不是每张 card 或每个页面自行覆盖全屏。

### 2.3 Show/Hide、PopIn/PopOut 与刷新时机

- `FullscreenOverlay.Show()` 在已经 visible 时触发 state change 以便重新浮到前景，否则走基类 show（`osu.Game/Overlays/FullscreenOverlay.cs:90-101`）。
- Fullscreen pop-in 在基础 wave transition 上补 shadow fade；pop-out 先淡出 shadow，完成后调用可覆写的 `PopOutComplete()`（同文件 `:115-129`）。
- Wiki 和 News 都把 `displayUpdateRequired` 设为 true，首次 pop-in 才触发请求，pop-out 完成后重新标记；这避免 overlay 尚未被用户看到就请求数据（Wiki：`osu.Game/Overlays/WikiOverlay.cs:69-84`；News：`osu.Game/Overlays/NewsOverlay.cs:90-105`）。
- `OsuFocusedOverlayContainer` 在 visible/hidden 状态变更时通知 overlay manager 显示/隐藏 blocking overlay，并播放进出音效（`osu.Game/Graphics/Containers/OsuFocusedOverlayContainer.cs:124-158`）。

## 3. Header 系统

### 3.1 分层

`OverlayHeader` 是横向自适应、纵向自动尺寸的容器，`HeaderInfo` 以纵向 flow 叠加背景与 title row，随后是页面的 `CreateContent()`；默认内容左右 padding 等于 wave 的 `HORIZONTAL_PADDING = 50`（`osu.Game/Overlays/OverlayHeader.cs:39-102`；`osu.Game/Overlays/WaveOverlayContainer.cs:25-27`）。

`OverlayTitle` 统一提供 icon + title 的横向组合，icon 30px、间距 10、20px regular 字体和约 15px 垂直留白；`Description` 是无形但供 named overlay component 使用的语义字段（`osu.Game/Overlays/OverlayTitle.cs:14-29,47-73`）。

`OverlayHeaderBackground` 是 80px 高、横向撑满、masked 的延迟加载背景图；图片加载完成后 500ms `OutQuint` fade-in（`osu.Game/Overlays/OverlayHeaderBackground.cs:12-46`）。这是一层 header visual，不是另一个窗口。

`TabControlOverlayHeader<T>` 在 header info 内放置水平 tab control，固定 tab 高 47px；可在另一侧插入 `CreateTabControlContent()`，默认为空（`osu.Game/Overlays/TabControlOverlayHeader.cs:21-90,92-124`）。`BreadcrumbControlOverlayHeader` 将 tab control 换成 breadcrumb control，47px 高、accent 来自 `Light2`，激活时不加粗而只 fade hover（`osu.Game/Overlays/BreadcrumbControlOverlayHeader.cs:12-54`）。

### 3.2 页面差异

| 页面 | Header 类型 | Header 特例 |
|---|---|---|
| Wiki | `WikiHeader : BreadcrumbControlOverlayHeader` | index、subtitle、title 面包屑；GitHub 编辑按钮；`Headers/wiki`；橙色 scheme（`osu.Game/Overlays/Wiki/WikiHeader.cs:25-45,47-72,74-119`；`WikiOverlay.cs:41-43`） |
| News | `NewsHeader : BreadcrumbControlOverlayHeader` | front page 与 article slug 动态 breadcrumb；`Headers/news`；紫色 scheme（`osu.Game/Overlays/News/NewsHeader.cs:16-29,31-64`；`NewsOverlay.cs:18,39-40`） |
| Beatmap Listing | `BeatmapListingHeader : OverlayHeader` | 不使用 breadcrumb；title 下直接放完整筛选控件，蓝色 scheme（`osu.Game/Overlays/BeatmapListing/BeatmapListingHeader.cs:13-27`；`BeatmapListingOverlay.cs:49-52,124-126`） |

## 4. Wiki

### 4.1 数据与页面交换

Wiki 以 `Main_page` 为 index path，维护 `path`、`wikiData`、language 和可取消 request。path 变化会发起 `GetWikiRequest`，语言变化则用同一路径重载；请求期间显示 Loading，成功后按 response layout 分流（`osu.Game/Overlays/WikiOverlay.cs:19-55,107-149`）。index 显示 `WikiMainPage`，其他路径显示 `WikiArticlePage`；失败也显示 article markdown 错误页和返回主页链接（同文件 `:151-180`）。

页面交换是 `Child = loaded`，而不是新建全屏窗口。每次交换前 ScrollFlow 回到顶部；旧请求和取消 token 会取消，dispose 也会取消（同文件 `:86-94,107-129,189-193`）。

### 4.2 Index 双栏/全宽 panel

`WikiMainPage` 将 API 返回的 markdown 当作 HTML 解析，先提取 blurb，再提取 `wiki-main-page-panel`。普通 panel 每两个组成一行双栏；带 `wiki-main-page-panel--full` 的 panel 占全宽，并以 null 第二列补齐 grid（`osu.Game/Overlays/Wiki/WikiMainPage.cs:18-47,49-103`）。因此 index 的布局不是单一文章流，而是“介绍 + 可混合双栏/全宽模块”的页面。

### 4.3 Article、侧栏与滚动同步

文章页是两列 grid：左侧 `SidebarContainer` 宽度自适应，右侧 Markdown；Markdown 左 30、右 50、上下 20 padding，并在解析 heading 时回调 sidebar（`osu.Game/Overlays/Wiki/WikiArticlePage.cs:15-65,68-79`）。

`WikiSidebar` 只接收 heading level 2/3，level 3 作为缩进 entry，生成 Table of Contents（`osu.Game/Overlays/Wiki/WikiSidebar.cs:18-47`）。overlay 每帧/每次 children update 设置 sidebar 高度为 overlay 高度，并将 Y clamp 到主 ScrollFlow 的当前滚动位置，使侧栏在文章滚动时保持可见但不超出文章范围（`osu.Game/Overlays/WikiOverlay.cs:96-105`）。这不是独立滚动窗口，而是 sidebar 的几何位置跟随主 scroll。

## 5. News

### 5.1 列表、归档与分页

News 内容是固定左 sidebar + 右 content 的两列 grid（`osu.Game/Overlays/NewsOverlay.cs:39-70`）。sidebar metadata 来自列表请求 response；`NewsSidebar` 将帖子按月/年分组，按年份和月份降序排列，并默认展开最新月份（`osu.Game/Overlays/News/Sidebar/NewsSidebar.cs:16-75`）。`YearsPanel` 从 metadata 生成年份按钮，非当前年份点击调用 `ShowYear(year)`（`osu.Game/Overlays/News/Sidebar/YearsPanel.cs:20-79,82-119`）。

列表请求保存 `displayedYear` 和 API `Cursor`。首次加载创建 `ArticleListing`，后续 `getMorePosts()` 用 cursor 请求下一页并将 cards append 到已有 listing（`osu.Game/Overlays/NewsOverlay.cs:142-177`）。`ArticleListing` 是纵向 flow，每张 card 间距 10，末尾 `ShowMoreButton` 负责继续加载并依据是否有 cursor 显示（`osu.Game/Overlays/News/Displays/ArticleListing.cs:22-85`）。

### 5.2 Card 与状态

`NewsCard` 是带 hover 的可点击容器，圆角 6；图片区域高 160，延迟加载封面，右上角显示日期，下面是标题、preview、作者（`osu.Game/Overlays/News/NewsCard.cs:23-40,43-122`）。源码只明确证明这些布局与 hover 色，不足以推断完整运行时视觉效果。

News 的 route state 是 `article`（null 表示 listing）、`displayedYear`、`lastCursor` 和 `displayUpdateRequired`；front page、year、article 分别由 `ShowFrontPage/ShowYear/ShowArticle` 进入（`osu.Game/Overlays/NewsOverlay.cs:20-37,107-123`）。

**重要限制**：`loadArticle()` 当前明确注释为“not yet implemented nor called from anywhere”，它只设置 Header、显示 Loading，然后 `LoadDisplay(Empty())`（`osu.Game/Overlays/NewsOverlay.cs:180-187`）。因此当前源码证明了列表/归档分页，不证明 News 文章详情成品存在。

## 6. Beatmap Listing

### 6.1 Header、搜索和筛选层

`BeatmapListingHeader` 的 title 下直接插入 `BeatmapListingFilterControl`（`osu.Game/Overlays/BeatmapListing/BeatmapListingHeader.cs:13-27`）。Filter control 是纵向 flow：上方 search/filter 面板，下方 40px sort bar；右侧 card-size tab 与左侧 sort tab 并列（`osu.Game/Overlays/BeatmapListing/BeatmapListingFilterControl.cs:77-133`）。

Search control 包含动态封面背景、搜索框和多行过滤器（general、ruleset、category、genre、language、extra、rank、played、explicit），搜索框输入会触发 `TypingStarted`（`osu.Game/Overlays/BeatmapListing/BeatmapListingSearchControl.cs:81-150,175-205`）。Filter 的查询变更会 reset sort/search，未登录则停止；文本变化 debounce 500ms，其他筛选 100ms，然后从第 0 页重新请求（`osu.Game/Overlays/BeatmapListing/BeatmapListingFilterControl.cs:145-186,209-225,284-295`）。

### 6.2 Cursor、结果 flow、卡片尺寸与空态

请求把上次 response 的 cursor 传给 `SearchBeatmapSetsRequest`；空结果或 null cursor 标记 no-more-results，结果通过 `SearchResult` 区分普通结果与 supporter-only filters（`osu.Game/Overlays/BeatmapListing/BeatmapListingFilterControl.cs:227-281,304-350`）。

overlay 收到第 0 页结果时创建带间距 10 的 `ReverseChildIDFillFlowContainer<BeatmapCard>`，结果 content 淡入；后续页面 append，并按 OnlineID 去重。card size 改变会异步重建现有 cards；无结果显示 250px 高 NotFoundDrawable，supporter-only filters 显示单独 placeholder（`osu.Game/Overlays/BeatmapListingOverlay.cs:155-251,260-360`）。

搜索 control 的背景封面来自第一个结果 `BeatmapSet`，使用 `UpdateableOnlineBeatmapSetCover` 且 transform immediate（`osu.Game/Overlays/BeatmapListing/BeatmapListingSearchControl.cs:91-100,208-211`）。滚动接近底部 500px 且没有进行中的加载时自动 `FetchNextPage()`（`osu.Game/Overlays/BeatmapListingOverlay.cs:362-378`）。

### 6.3 Escape/back 的分层语义

测试明确验证三层顺序：普通 Escape 隐藏 overlay；有搜索文本时第一次 Escape 清空搜索但保持可见；已滚到底部时第一次 Escape 同时清空搜索并回到顶部，第二次才隐藏（`osu.Game.Tests/Visual/Online/TestSceneBeatmapListingOverlay.cs:92-135`）。这说明“Back”优先处理页面内部可逆状态，再传播给共享 overlay 的 `GlobalAction.Back → Hide()`（共享 fallback：`osu.Game/Graphics/Containers/OsuFocusedOverlayContainer.cs:102-118`）。

测试还覆盖 card size 在 Normal/Extra 间重建 100 张卡、空态恢复、分页 cursor 重复 beatmap 只显示一次，以及 supporter-only filter placeholder（`osu.Game.Tests/Visual/Online/TestSceneBeatmapListingOverlay.cs:149-250`）。

## 7. 三页面比较矩阵

| 维度 | Wiki | News | Beatmap Listing |
|---|---|---|---|
| 共同骨架 | `OnlineOverlay<WikiHeader>`，橙色 | `OnlineOverlay<NewsHeader>`，紫色 | `OnlineOverlay<BeatmapListingHeader>`，蓝色 |
| 页面状态 | path、language、wikiData、当前 display | article、displayedYear、cursor、metadata | query/filter/sort、CurrentPage、cursor、card size、noMoreResults |
| Header | breadcrumb + GitHub | breadcrumb + front/article | 普通 title + filter control |
| 侧栏 | 文章 TOC，固定几何跟随主 scroll | 年份 + 月份归档，独立 sidebar scroll | 无 sidebar |
| 内容布局 | index blurb + 双栏/全宽 panels；article 两列 markdown | 垂直 NewsCard listing | 结果 card flow/grid 语义，卡片可切尺寸 |
| 异步加载 | path request，可取消；成功替换 child | 首页/年份 request；详情 placeholder | debounce request，可取消；卡片异步构建 |
| 分页 | 无源码证据 | API cursor + Show More | API cursor + 接近底部自动拉下一页 |
| 空态/失败 | 错误 markdown article | 当前详情为空；列表无专门错误实现证据 | NotFound、supporter-required |
| 滚动 | 每次换页回顶部；sidebar Y 同步 | 每次换 listing/显示回顶部；sidebar Y 同步 | 回顶部、接近底部自动分页；Escape 可回顶部 |
| 退出语义 | 共享 Back/Hide；header 可回 parent/index | 共享 Back；header 可回 front page | 先清 search/回顶部，再共享 Hide |
| 页面色系 | Orange scheme + wiki header | Purple scheme + news header | Blue scheme；背景 override 为 Background6 |

## 8. 对 Afloat 的 QML 映射

### 8.1 机制映射

| osu 机制 | QML/Quickshell 等价物 | 不可直接照搬之处 |
|---|---|---|
| 全屏 overlay owner | 每屏一个固定 `PanelWindow`/layer-shell owner，内部 persistent overlay surface | osu 的 `Drawable` 树、dependency injection、`FocusedOverlayContainer` 不是 QML API |
| 单一 overlay route | `route`/`page` 状态 + `Loader` 或固定 content host | 不应为每页创建独立 layer-shell 窗口，否则失去共享生命周期 |
| Header slot | `Header` QML component，`headerMode` 为 breadcrumb/tab/filter | osu 的泛型 C# header 与 bindable 不可直接移植，用 QML properties/signals |
| Content slot | 固定 `Item`/`Loader`，异步完成时替换 `sourceComponent` 或 model | QML Loader 的销毁/重建语义需明确，不能假设等价于 `LoadComponentAsync` |
| Sidebar slot | 固定宽度 `Item` + `ListView`，文章侧栏通过 `contentY`/clamp 跟随 | 不要让 sidebar 进入主内容 layout 的高度变化；同步的是 geometry，不是第二份文章 scroll state |
| ScrollFlow | `Flickable`/`ListView`/`ScrollView`；scroll-to-top button 置于 header z 层 | QML anchors 与 osu auto-size grid 不同，需明确 contentHeight 与 viewportHeight |
| Loading owner | overlay 级 `Loading` Item，覆盖 content 但不覆盖 header，按 header/scroll geometry 调整 | 不要让每个异步 delegate 自己创建全屏 loading |
| Wiki markdown | Markdown renderer 或预处理 HTML + `Flickable`; heading parser 输出 TOC model | Markdig 的 heading callback、Drawable markdown layout 不能原样复制 |
| News listing | `ListView` + cursor model + append；年份/月 sidebar model | `ShowMoreButton` 与自动分页是两种触发策略，需在状态模型中区分 |
| Beatmap cards | `GridView`/可变列数 delegate，`cardSize` 绑定；封面 `Image` asynchronous | osu 的 reverse child ID 是 Z-order 细节，QML 用显式 z/overlay detail layer 替代 |
| 输入优先级 | focused inner item 先处理 Escape；未消费才由 route owner close | PanelWindow 不是 Item，Keys/焦点应在内层 focus Item 上 |
| PopIn/PopOut | `visible/openProgress` + Behavior/Transition；关闭完成 signal 再清 route | osu 的 sample、preview track manager、EdgeEffect/wave compositor 行为需用项目已有服务等价实现 |

### 8.2 推荐目标组件树与状态模型

```text
PerScreenOverlayWindow (固定 PanelWindow owner)
└─ OverlayHost (focus + modal input + openProgress)
   ├─ Backdrop / WaveLikeBackground
   ├─ OverlaySurface (固定尺寸、clip、shadow)
   │  ├─ PersistentHeader
   │  │  ├─ OverlayTitle
   │  │  └─ HeaderSlot(route)
   │  ├─ ScrollViewport
   │  │  ├─ LoadingLayer(owner = route loader)
   │  │  └─ PageLayout
   │  │     ├─ SidebarSlot(route)
   │  │     └─ ContentSlot(route)
   │  └─ ScrollToTopProxy
   └─ Close/interaction boundary
```

```text
overlay = {
  open: false,
  route: "wiki-index" | "wiki-article" | "news-list" | "news-year" |
         "news-article" | "beatmap-list",
  query: {...},
  data: {...},
  loading: false,
  requestToken: 0,
  scrollY: 0,
  innerBackState: "search-text" | "scrolled" | "none"
}
```

边界责任应保持单一：请求层负责取消、cursor 和 payload 解码；route reducer 负责决定 page/slot；页面负责把已解码 model 映射成 List/Grid/Markdown；渲染层只负责视觉和输入，不直接解析 API payload。

## 9. Afloat 迁移优先级

### P0：先建立“像 osu”的结构

1. 一个固定的 per-screen overlay owner 和一个 route host，而不是三个独立窗口。
2. 固定 surface 尺寸、backdrop、header、主滚动 viewport、sidebar/content 分栏和 overlay-level loading。
3. 统一 open/close 生命周期：open progress、blocking input、点击外关闭、Escape fallback、关闭完成后清理异步请求。
4. 先实现一个可替换 header/content/sidebar contract，再接 Wiki/News/Beatmap 三种页面。
5. 为 Escape 建立消费优先级：输入框清文本 → 页面回顶部 → route 回父页 → overlay close。

### P1：补足页面信息架构

1. Wiki index 的双栏/全宽 panel 与 article 的 TOC sidebar/scroll sync。
2. News 的年份/月归档、listing append、cursor/Show More 和明确的详情未实现状态。
3. Beatmap 的 search/filter/sort/card-size model、封面、grid/list delegate、空态和 near-end pagination。
4. 将 loading、错误、空态作为页面状态而非零散 overlay。

### P2：最后做视觉 polish

1. 波浪/渐变背景、header image fade、阴影、卡片 hover、圆角和细微间距。
2. 进出场 easing、卡片 stagger、封面 fade 和 scroll-to-top feedback。
3. 颜色 token、字体权重和 icon 细节。

核心判断：P2 之前若 P0/P1 不成立，视觉细节只会制造“osu 颜色的普通弹窗”，不会产生 osu 的页面系统感。

## 10. 风险、不确定性与证据边界

- 本报告只把源码明确表达的尺寸、颜色 scheme、层级、状态和测试行为作为事实；仅凭资源名、颜色名或 class 名推断出的视觉感受均未当作运行时结论。
- `NewsOverlay.loadArticle()` 明确是 `Empty()` 占位且未被调用（`osu.Game/Overlays/NewsOverlay.cs:180-187`），不能把 News 详情描述成已完成页面。
- CodeGraph 对某些泛型基类和全局输入分发只返回了符号关系；关键完整基类已用原始文件补足，尤其是 `OsuFocusedOverlayContainer.cs:18-171`。未找到的具体 Escape override 不应被声称存在；Beatmap 的分层行为由视觉测试证明。
- osu-framework 的异步 Drawable loading、dependency injection、preview audio、wave rendering、EdgeEffect 和 `ReverseChildIDFillFlowContainer` 没有 QML 一比一 API。Afloat 迁移只能保留所有权、状态、层级和交互语义，不能复制 C# 类名或内部生命周期。
- News 的列表测试源码未证明完整文章详情；Beatmap 测试证明了空态、分页去重、card size 和 Escape 行为，但不等于证明所有运行时网络错误状态。
- 资源背景和字体的最终视觉效果仍受运行时 texture/font 资源影响；本报告的视觉结论以布局与源码参数为边界。

## 11. 主要证据索引

- `osu.Game/Graphics/Containers/OsuFocusedOverlayContainer.cs:18-171`：输入阻塞、屏幕外点击、Back、blocking overlay、状态转换。
- `osu.Game/Overlays/WaveOverlayContainer.cs:10-49`：wave owner、start hidden、PopIn/PopOut。
- `osu.Game/Overlays/FullscreenOverlay.cs:19-129`：尺寸、背景、header、shadow、PopOutComplete。
- `osu.Game/Overlays/OnlineOverlay.cs:15-92`：ScrollFlow、Loading、header/content slot、scroll-to-top proxy。
- `osu.Game/Overlays/OverlayHeader.cs:12-103`、`OverlayTitle.cs:14-73`、`OverlayHeaderBackground.cs:12-46`：header 分层与基础视觉参数。
- `osu.Game/Overlays/TabControlOverlayHeader.cs:21-124`、`BreadcrumbControlOverlayHeader.cs:12-54`：tab/breadcrumb header。
- `osu.Game/Overlays/WikiOverlay.cs:19-195`、`WikiMainPage.cs:18-105`、`WikiArticlePage.cs:15-81`、`WikiSidebar.cs:18-69`：Wiki 数据流、index/article、TOC、scroll sync。
- `osu.Game/Overlays/NewsOverlay.cs:18-203`、`NewsSidebar.cs:16-77`、`YearsPanel.cs:20-119`、`ArticleListing.cs:22-91`、`NewsCard.cs:23-163`：News archive/list/card 与详情占位。
- `osu.Game/Overlays/BeatmapListingOverlay.cs:46-380`、`BeatmapListingHeader.cs:13-31`、`BeatmapListingFilterControl.cs:29-350`、`BeatmapListingSearchControl.cs:81-212`：搜索、筛选、cursor、card flow、空态、封面、分页。
- `osu.Game.Tests/Visual/Online/TestSceneBeatmapListingOverlay.cs:83-250`：Escape 分层、card size、空态、分页去重、supporter-only 状态。
