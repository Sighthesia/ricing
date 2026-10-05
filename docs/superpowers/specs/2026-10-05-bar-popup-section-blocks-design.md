# 音量与 Wi-Fi 悬浮面板：分类底板统一设计

- **日期**：2026-10-05
- **状态**：待审阅
- **目标分支**：`lazer`

## 原始需求

> 分析wifi和音量hover菜单目前这样详细情况下如何优化，以及能否复用设置面板的根据分类划分的背景的布局（同trayhover菜单）

## 目标

把音量与 Wi-Fi 两个悬浮面板的分组方式，换成托盘 hover 菜单已经在用的
「分类底板 → 行卡片」两层结构，让同一族弹层只有一种分组语言。

顺带解决两个由「做得太详细」直接引出的问题：面板装不下自己的内容，以及滚动
时唯一不能离开视野的主控先消失。

## 非目标

- 不改任何服务边界：`VolumeService` / `NetworkService` 的读写、轮询、错误分类全部不动。
- 不改弹层的宿主机制：`BarPopupHost` 的 surface、两层结构、方向、入场 stagger、
  悬停桥、退出生命周期全部不动。
- 不给分类块加逐块入场动画。设置面板与 Wave 的入场词汇不外扩到弹层。
- 不做折叠/展开的分类块（accordion）。本轮只解决分组视觉与首屏可见性。
- 不动亮度、媒体、电池、通知、日历、窗口提示、右键菜单等其它弹层。

---

## 现状

### 弹层已有的三层色阶

`LazerTheme` 里这三个 token 是同一套明度阶梯（暗色方案的 fallback 值）：

| token | fallback | 角色 |
| --- | --- | --- |
| `settingsRail` | `#131217` | 最深。身份栏 `BarPopupIdentity` |
| `settingsPanel` | `#18161D` | 次深。设置面板内容底、托盘的分类底板 |
| `settingsCard` | `#221F2B` | 中间。行卡片 |
| `settingsSection` | `#282532` | 最浅。设置面板的分类块、弹层的内容面 |

行卡片永远落在「比它底的那一层」和「比它更深的背景」之间，所以两种堆叠方向都成立。

### 托盘已经是目标形态

`BarTrayMenuContent.qml` 里：

- `menuFace`（z:2）铺 `settingsSection`，`x: -submenuPad`，宽 `primaryMenuWidth + 16`。
- `trayMenuSection`（`BarTrayMenuContent.qml:755`）铺 `settingsPanel`，宽 `menuColumn.width`，
  高度 = 内部列的 `implicitHeight`，块间距 4。
- 行卡片 `trayMenuRowSurface` 铺 `settingsCard` / `settingsCardHover`，圆角 4。

即：`settingsSection` 面 → `settingsPanel` 分类块 → `settingsCard` 行。极性是
「外浅 → 分类深 → 行中」。

### 音量与 Wi-Fi 缺的就是中间那层

两个面板的行卡片也是 `settingsCard`，直接浮在宿主铺的 `settingsSection` 面上
（`BarPopupHost.qml:1984` 的 `popupContentSurface`）。分组只靠
`BarAudioDeviceList` / `BarAudioMixer` 各自那段 16px 高的
「小标题 + 1px 细线」（`audioSectionHeader` / `mixerHeader`）。所以同一个弹层家族里
现在有两种分组语言：托盘有底板，音量和 Wi-Fi 没有。

### 高度账

按当前写死的行高折算（`LazerSettingsRow` 的标准形态是 `10 + 标签 + 5 + 控件 + 10`，
`LazerSettingsSlider` 高 30、`LazerSettingsToggle` 高 20，`listGap` 8）：

**音量**（`implicitWidth` 360）

| 块 | 组成 | 高度 |
| --- | --- | --- |
| 主音量 | `BarPopupSlider` = 滑条行 ~82 + 静音行 ~72 | ~154 |
| 输出 | 标题 16 + 间隙 6 + 3 行 × 38 + 2 × 4 | ~144 |
| 输入 | 同上 | ~144 |
| 应用 | 标题 16 + 间隙 6 + 4 行 × 48 + 3 × 4 | ~226 |
| 块间距 | `volumeColumn.spacing` 12 × 3 | 36 |
| 上下内边距 | `contentColumn` 8 × 2 | 16 |
| **合计** | | **~720** |

上限是写死的 `volumeContent.viewportCap = 540`（`BarPopupActions.qml:1102`）。
也就是说在一台有 3 输出 / 3 输入 / 4 路播放的机器上，面板**一打开就已经溢出约 180px**。

**Wi-Fi**（`implicitWidth` 260）

| 块 | 组成 | 高度 |
| --- | --- | --- |
| 当前连接读数卡 `linkDetails` | 16 + 接口名 12 + 3 行 × 14 + 间距 | ~73 |
| 有线端口卡 | 每口 16 + 端口头 16 + 每配置 32 + 间距 | ~104+ |
| Wi-Fi 开关行 | `LazerSettingsRow` + toggle | ~72 |
| 网络列表 | 5 行 × 36 + 4 × 6 | 204 |
| Rescan | | 32 |
| 间隙 | `wifiColumn.spacing` 8 × 7 | 56 |
| **合计** | | **~537** |

`wifiColumn` 有 8 个子项，`Column` 连不可见的也照样排（现有注释已经记下了这条：
「a Column measures an invisible child at its full geometry」），所以隐藏的错误文案、
忘记按钮和密码框也要各自吃掉一个 8px 的间隙。

`networkContent.height = wifiColumn.height`，**没有上限**。

---

## 问题清单

1. **分组没有底板。** 三个音量块（以及 Wi-Fi 的有线卡）靠一条 1px 细线分组，
   行卡片浮在面板面上。托盘和设置面板是两层。同族弹层出现两种分组语言。
2. **滚动时主控先走。** `volumeScroll` 把 `BarPopupSlider` 包在里面，滚到应用列表
   时主音量条就滚出视野 —— 面板里唯一必须一直看得见的控件恰好是最先消失的那个。
3. **Wi-Fi 没有高度上限。** 有线配置一多，面板可以长到超过屏幕；而且 Rescan 在最脚部，
   滚动就够不到。
4. **和身份栏重复表达。** 身份栏已经说了「Wi-Fi · SSID · 信号」和「音量 · 65%」；
   面板里的 Wi-Fi 开关行再说一遍，`linkDetails` 的接口名行再说一遍。
5. **行高五套、圆角两套。** 38 / 48 / 36 / 32 / 设置行 ~74；行卡片圆角全是 6，
   托盘行是 4。密度对不齐，整面板像三次拼接。
6. **Wi-Fi 密码框是裸 `TextInput`**（`BarPopupActions.qml:2328`），没有走
   `LazerSettingsTextField`，因此没有外观统一、没有焦点环。
7. **同一块底色被画了三遍。** 托盘打开时，`popupContentSurface`（宿主）、
   `trayContentBackground`（`BarPopupActions.qml:2560`）、`menuFace`
   （`BarTrayMenuContent.qml:395`）是三张同尺寸同色的 260 宽矩形叠在一起。

---

## 设计决策

### D1 分类底板组件

新增 `modules/bar/PopupSectionBlock.qml`，契约：

| 属性 | 值 |
| --- | --- |
| `title` | `string`，`""` 表示无标题块 |
| `scope` | `string`，可选的副标题（沿用设备列表现在那个「抬升的硬件前缀」位置） |
| 底板色 | `LazerTheme.settingsPanel`，圆角 `0`（主 surface 保持直角） |
| 标题 | 11px DemiBold，`LazerTheme.settingsNavInactive`，与托盘一致 |
| 标题带 | 高 16，标题与内容之间 6 |
| 块内边距 | 上下各 8 |
| 块内行距 | 4（与托盘 `sectionColumn` 一致） |
| 内容注入 | `default property alias content` 指向一个 `spacing: 4` 的 `Column` |

高度是纯算式：`8 + (title !== "" ? 16 + 6 : 0) + content.implicitHeight + 8`。

**为什么极性跟托盘而不是跟设置面板。** 设置面板是「外深 → 分类浅 → 行中」，托盘是
「外浅 → 分类深 → 行中」。托盘和这两个面板是同一个弹层家族、同一个 `settingsSection`
内容面、同一个 8px 边框；设置面板在另一块 surface、另一套尺寸、横向入场。同族里
的邻居比远处的权威更权威，而且托盘已经在线上跑了。

### D2 必须支持无标题块

音量第一块（主音量）**不带标题**：身份栏已经写了「音量」，滑条行的标签又写了
「Volume」，再加一个「主音量」标题就是同一件事说三遍。这条是无标题块存在的唯一理由，
所以组件不许把标题当必填。

### D3 音量面板结构

```
身份栏  settingsRail   🔊 音量 · 65%
─────────────────────────────────  内容面 settingsSection
┌ 块1（无标题）──────────────────┐  settingsPanel
│  [Volume            ——●——  65%]│  settingsCard
│  [Mute                     ( )]│  settingsCard
└───────────────────────────────┘
┌ 块2「输出」────────────────────┐
│  [Built-in Audio         100% ]│
│  [Headphones                  ]│
└───────────────────────────────┘
┌ 块3「输入」────────────────────┐
│  [Built-in Microphone   100% ]│
└───────────────────────────────┘
┌ 块4「应用」────────────────────┐
│  [firefox  music…          🔇] │
│  [——— 80% ——]      [Out: HDMI] │
└───────────────────────────────┘
```

- 块间距 4，与托盘一致（现在的 12 是为了在没有底板时把两类东西分开；有了底板之后
  12 会读成四块各自独立的浮岛）。
- 块3 的列表为空时整块不出现，不留空标题。
- 混音默认可见行数 4 → 2，滚动仍能到全部。

### D4 Wi-Fi 面板结构

```
身份栏  settingsRail   📶 Home-5G · 82%
─────────────────────────────────
┌ 块1「当前连接」────────────────┐
│  IP 192.168.1.24              │
│  Gateway 192.168.1.1          │
│  DNS 192.168.1.1, fd00::1     │
└───────────────────────────────┘
┌ 块2「有线」────────────────────┐
│  enp3s0  Connected            │
│  ┌ Home Wired ┐                │
└───────────────────────────────┘
┌ 块3「Wi-Fi」──────────────────┐
│  [Wi-Fi                  ( )] │
│  [Home-5G            82% 1170]│
│  [Neighbour-4G           61%  ]│
│  ─────────────────────────────│  块脚
│           ⟳ Rescan            │
└───────────────────────────────┘
```

- 块1 删掉接口名行（身份栏已经说了），并且只在有链路时出现。
- 块2 把多个有线口合并成一块，端口头降级成块内的分组小标题。
- 块3 把开关、列表、Rescan 收进同一块，Rescan 变成块脚（块内一条 1px `divider`）。
  错误文案和「忘记已存配置」也落在这块里，不再是浮在面板面上的裸文字。
- 密码框换成 `LazerSettingsTextField`。

### D5 首屏可见性与滚动

- 音量：块1 移出滚动区，固定在顶部。滚动区只剩块2~4。
- 两个面板的高度上限统一走一条规则（见 D7），而不是音量写死 540、Wi-Fi 没有。
- Rescan 收进 Wi-Fi 块脚之后不再有「滚到底才够得到」的问题。
- 首屏目标：打开即完整看到「主音量 + 输出 + 应用前 2 行」，输入块在多数机器上
  落在折叠线以下。

### D6 行高与圆角

- 列表行统一 38（Wi-Fi 网络行 36 → 38，有线配置行 32 → 38）。
- 混音行 48 → 44（它的两行网格本来就是 6 + 14 + 间距 + 6，压 4px 不动信息层级）。
- 行卡片圆角全部 6；托盘行保持 4 不动 —— 托盘是 native menu 的行，语义不同。

### D7 高度上限抽成一个纯函数

新增 `modules/bar/PopupPanelMetrics.js`：

```javascript
maxPanelHeight(screenHeight)   // max(180, screenHeight * 0.7)，与托盘 maxMenuHeight 同规则
blockHeight(titleVisible, contentHeight)  // 8 + (title ? 22 : 0) + content + 8
```

托盘、音量、Wi-Fi 三处共用同一规则，替掉托盘里写死的 0.7 和音量的 540。

### D8 删掉重复底色

删除 `BarPopupActions.qml` 的 `trayContentBackground`：宿主已经铺了同尺寸同色的
`popupContentSurface`，而 `menuFace`（z:2，本来就是不透明的）也已经覆盖同一块。
保留 `menuFace` —— 它有职责：在二级菜单滑出之前把下面挡住。

### D9 防回归

`scripts/tests/test_audio_panel_binding_cycles.py` 目前扫三个文件（其中两个路径不存在，
实际只有 `BarAudioDeviceList.qml` 和 `BarAudioMixer.qml` 生效）。本轮：

- 新增 `PopupSectionBlock.qml`，但只受**两条环检测**约束，不进
  `test_panel_components_declare_no_positioners_at_all`——分类块内部本来就该有一个
  装行的 `Column`，它和那两个组件「每行手写」的约定不是一回事。
- 新增一条断言：任何弹层 body 都不得自己铺 `settingsSection` 面（宿主是唯一 owner），
  这条锁住 D8。

---

## 与 Wave 控制中心的关系

`docs/superpowers/specs/2026-10-04-wave-control-center-design.md` 的第一版控制中心
也要 Wi-Fi 和音量卡片，并明确只复用 `BarPopupActions` 已经在用的服务契约。

因此：

- `PopupSectionBlock` 按共用件设计，控制中心的卡片分组直接用它，不要在 Wave 侧再画一套。
- 服务契约零改动，两边不会分叉。
- 弹层本身继续存在（控制中心是另一条 Wave 路线，不取代 bar 弹层）。

---

## 验证

**纯逻辑**（`tests/qml/`，经 `scripts/qmltest.sh`）

- `maxPanelHeight`：正常屏、超小屏、`screenHeight <= 0` 的兜底。
- `blockHeight`：有标题 / 无标题 / 空内容。
- 「输入块在列表为空时不可见」这类显隐判定。

**QML 行为**

- `tst_volume_panel.qml`（headless-safe，真实 PipeWire）扩断言：块数量与顺序、
  块1 不在滚动区内、滚动区高度 ≤ 上限、混音可见行数为 2、面板总高在常见机器上
  ≤ 上限。它已经在断言 `implicitWidth === 360`、`volumeMasterCardItem`、上限与
  `interactive` 契约，扩在同一个文件里。
- `tst_network_popup.qml` 扩断言：块数量、有线口合并成一块、Rescan 在 Wi-Fi 块脚内、
  面板高度 ≤ 上限。注意它**在仓库的禁跑表里**（会挂真实 bar 并弹出面板），
  只能经 `scripts/run-tests.sh -g` 跑。
- 禁跑表本身不变。

**默认门禁**

- `scripts/check-shell.sh` 必须干净。分类块多两个面 = 多几次 geometry 提交，
  要看有没有新的 region commit 抖动。

**源级守卫**

- 扩 `test_audio_panel_binding_cycles.py`（见 D9）。

## 风险

| 风险 | 缓解 |
| --- | --- |
| 加了底板内边距，面板反而更高 | D6 的减内容清单是本轮的前置条件，不是可选项 |
| 手写块头布局再次引入 polish loop | D9 把新组件纳入环检测 |
| 层壳 surface 高度即面板高度，多提交几次 | `check-shell.sh` 看 region commit |
| 改动面横跨 6 个 QML 文件 + 3 个测试 | 建议分三次提交：组件 → 音量 → Wi-Fi + 清理 |

## 交付顺序

1. `PopupPanelMetrics.js` + `PopupSectionBlock.qml` + 纯逻辑测试 + 守卫扩展
2. 音量：套块 + 块1 固定 + 行高统一 + 混音 2 行
3. Wi-Fi：套块 + 有线合并 + Rescan 收脚 + 密码框换控件 + 删重复底色