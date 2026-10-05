# 分类底板：音量与 Wi-Fi 悬浮面板（2026-10-05）

需求原文见 `docs/superpowers/specs/2026-10-05-bar-popup-section-blocks-design.md`
的「原始需求」。本文件是实现计划。

## 事实基础

| 事实 | 位置 |
| --- | --- |
| 弹层内容面是宿主唯一铺的 `settingsSection` | `BarPopupHost.qml` `popupContentSurface`（约 1984 行） |
| 身份栏是 `settingsRail`，48 高，圆角 0 | `BarPopupIdentity.qml:26` |
| 托盘分类块面是 `settingsPanel`，块间距 4，行圆角 4 | `BarTrayMenuContent.qml:755` / `:786` |
| 托盘上限 `max(180, Screen.desktopAvailableHeight * 0.7)` | `BarTrayMenuContent.qml:232` |
| 音量上限写死 540 | `BarPopupActions.qml` `volumeContent.viewportCap`（约 1102 行） |
| Wi-Fi 面板**没有**上限 | `BarPopupActions.qml` `networkContent.height = wifiColumn.height` |
| 音量宽 360 / Wi-Fi 宽 260 / 媒体宽 420 | `BarPopupActions.qml:87` |
| 弹层内容列左右各内缩 8 | `BarPopupActions.qml:104` `contentInset` |
| `volumeColumn` 块间距 12 | `BarPopupActions.qml:1127` |
| 设置行标准高 `10 + 标签 + 5 + 控件 + 10`，`listGap` 8，圆角 6 | `LazerSettingsRow.qml:103/113/38` |
| 滑条控件高 30 / 开关控件高 20 | `LazerSettingsSlider.qml:44` / `LazerSettingsToggle.qml:29` |
| 设备列表行 38、间隔 4、最多 3 行、标题带 16 | `BarAudioDeviceList.qml:34-52` |
| 混音行 48、间隔 4、最多 4 行、标题带 16 | `BarAudioMixer.qml:37-43/21` |
| Wi-Fi 行 36、间隔 6、最多 5 行 | `BarPopupActions.qml:1900-1902` |
| 有线配置行 32 | `BarPopupActions.qml:2150` |
| `Screen` 只在 `BarTrayMenuContent.qml` 里被读到，且该文件 import 了 `QtQuick.Window` | `BarPopupActions.qml` 目前只 import `QtQuick` |
| 环检测守卫实际只覆盖 2 个文件（另外两个路径不存在） | `scripts/tests/test_audio_panel_binding_cycles.py:25-32` |
| `tst_volume_panel.qml` 是 headless-safe 的活体集成测试，已断言宽度/上限/滚轮契约 | `tst_volume_panel.qml:130+` |
| `tst_network_popup.qml` **在禁跑表里**（挂真实 bar + 弹层） | `AGENTS.md` 表格 |

---

## 第 1 步：共用件

### 1.1 `modules/bar/PopupPanelMetrics.js`（新，纯 JS）

```javascript
.pragma library

// 弹层面板的高度上限，与托盘 maxMenuHeight 同一条规则。
function maxPanelHeight(screenHeight) {
    var h = Number(screenHeight)
    if (!isFinite(h) || h <= 0) return 420
    return Math.max(180, h * 0.7)
}

// 分类块高度：上下 8 + (有标题 ? 16 + 6 : 0) + 内容。
function blockHeight(titled, contentHeight) {
    var c = Number(contentHeight)
    if (!isFinite(c) || c < 0) c = 0
    return 16 + (titled ? 22 : 0) + c
}
```

`tests/qml/tst_popup_panel_metrics.qml`（QtTest，`Item` 根，无 `Window`）：
正常屏 / 超小屏 / `screenHeight <= 0` / 有标题 / 无标题 / 空内容 / 负值。

### 1.2 `modules/bar/PopupSectionBlock.qml`（新）

契约见设计文档 D1。要点：

- `Item` 根，`radius: 0`，`color: LazerTheme.settingsPanel`。
- `default property alias content` 指向内部 `Column`（`spacing: 4`）。
- **块头手写布局**，不用 `Row`：沿用 `BarAudioDeviceList.qml:85-97` 里已经写下的
  理由（positioner 写子项 `y`，子项又 `anchors.verticalCenter` 父项 → polish loop；
  以及子项宽度对 positioner 宽度求值 → `row.width -> child.width -> row.width`）。
  `scope` 的宽度对**常量** `scopeReserve` 求值，不对后面的细线求值。
- 标题为 `""` 时整条标题带不占高度，`visible: false`。
- `readonly property alias contentHeight: contentColumn.implicitHeight`

### 1.3 注册

`modules/bar/qmldir` 加 `PopupSectionBlock 1.0 PopupSectionBlock.qml`，格式照抄同文件现有行。

`PopupPanelMetrics.js` **不进 qmldir** —— 纯 JS 库，各文件用相对路径 import，
和 `BarTrayMenuLogic.js` / `BarHoverLogic.js` 一样。

### 1.4 守卫扩展

`scripts/tests/test_audio_panel_binding_cycles.py`：

- 新增 `POPUP_BLOCK_COMPONENTS = [modules/bar/PopupSectionBlock.qml]`，
  只跑 `test_no_width_measured_against_a_positioners_width` 与
  `test_positioners_do_not_hold_anchor_managed_y_children`。
- **不要**把它加进 `test_panel_components_declare_no_positioners_at_all`：
  那个断言的前提是「每行手写、左右两边各自排布」，分类块内部本来就装一个 `Column`。
- 顺手把 `AUDIO_PANEL_COMPONENTS` 里两个不存在的路径删掉
  （`BarAudioLevelRow.qml`、`modules/BarAudioMixer.qml`），它们被 `if path.exists()`
  静默过滤，留着只会让人以为覆盖了 4 个文件。
- 新增 `test_popup_bodies_do_not_paint_their_own_content_face`：扫 `modules/bar/*.qml`，
  任何 `color: LazerTheme.settingsSection` / `Lazer.LazerTheme.settingsSection` 都算违规
  —— 宿主是内容面的唯一 owner。这条锁住 D8。**注意 `BarTrayMenuContent.qml` 有两处
  例外**（`menuFace` 和二级面板），它们有明确职责（挡住在二级菜单滑出之前），
  所以扫描要按文件白名单豁免 `BarTrayMenuContent.qml`，只对 `BarPopupActions.qml`
  和 `BarContextPopupActions.qml` 生效。

**先跑红**：临时在 `BarPopupActions.qml` 里加一张 `settingsSection` 矩形，确认新断言变红，
再删掉。守卫没有红过就等于没写。

---

## 第 2 步：音量

### 2.1 套块

`BarPopupActions.qml` 的 `volumeColumn` 从「4 个兄弟」改成「4 个 `PopupSectionBlock`」：

- 块1（`title: ""`）= 现有 `BarPopupSlider`，不动它的内部结构。
- 块2 `title: "Output"`、`title` 源 `outputDeviceList.sectionTitle`
- 块3 `title: "Input"`
- 块4 `title: "Applications"`（取 `BarAudioMixer.headerTitle()` 的非 route 分支）
- `volumeColumn.spacing` 12 → 4

### 2.2 块1 移出滚动区

上限数值由调用方传入纯函数。上限要用屏幕高度，所以调用点要读
`Screen.desktopAvailableHeight` —— `Screen` 目前只在 `BarTrayMenuContent.qml` 里被读到，
且该文件 import 了 `QtQuick.Window`；`BarPopupActions.qml` 目前只 import `QtQuick`，
照托盘补上同一个 import，不要凭「Qt 5.8 起 QtQuick 就提供」去省这一步。

现在结构是 `volumeContent > volumeScroll(Flickable) > volumeColumn`（全部四块）。
改成：

```
volumeContent (Item, height = 固定块1 + 8 + scroll.height)
├ block1 固定，不参与滚动
└ volumeScroll (Flickable, 上限 = maxPanelHeight - 固定块1 - 8)
   └ volumeColumn (块2/3/4)
```

`BarPopupActions.qml:1102` 的 `viewportCap` 改为引用 `PopupPanelMetrics.maxPanelHeight(...)`
减去固定块高度；`readonly property real volumeViewportCap` 保持对外名字不变
（`tst_volume_panel.qml` 已经在用它）。

### 2.3 减内容

- `BarAudioMixer.maxVisibleRows` 4 → 2（默认属性，`BarPopupActions.qml` 不覆盖）。
- 空块不出现：`BarAudioDeviceList` 已经有 `sectionVisible`，但它现在只控制自身；
  改成块整体 `visible: devices.length > 0 || emptyText 场景不需要` —— 判定放
  `PopupPanelMetrics` 里做成纯函数 `showDeviceSection(count)`，测试覆盖 0 / 1。

### 2.4 行高统一

- Wi-Fi 网络行、有线配置行不在这一步（属第 3 步）。
- 混音行 48 → 44：`BarAudioMixer.qml:37`。
- 设备行保持 38。
- 行卡片圆角保持 6（本来一致）。

---

## 第 3 步：Wi-Fi

### 3.1 套块

`BarPopupActions.qml` 的 `wifiColumn` 改成 3 个 `PopupSectionBlock`：

- 块1「当前连接」= 现有 `linkDetails` 卡内容，**删掉接口名那一行**（`linkDetailsCaption`），
  身份栏已经说了。整块 `visible: root.linkDetailsVisible` 已经是这个语义，保持。
- 块2「有线」= `wiredGroupRepeater`，但端口头降级成块内小标题：多于一个口时用
  `BarPopupAction.qml` 里现成的「端口头 16 高 + 状态词」形态，多于一个口时每个口一条。
- 块3「Wi-Fi」= 开关行 + 错误文案 + 忘记按钮 + 密码框 + 网络列表 + Rescan。
  Rescan 从「面板面上的透明按钮」变成块脚：块内一条 `LazerTheme.divider` 的 1px 线，
  线下面 32 高的 Rescan。

### 3.2 高度上限

`networkContent.height` 从 `wifiColumn.height` 改成
`固定部分 + Math.min(滚动内容, maxPanelHeight - 固定部分)`，上限同样来自
`PopupPanelMetrics`。列表本身仍是最多 5 行。

### 3.3 行高统一

- Wi-Fi 网络行 36 → 38、间隔 6 → 4（`BarPopupActions.qml:1900-1901`）。
- 有线配置行 32 → 38（`BarPopupActions.qml:2150`），第二行文字跟着上移。
- 连带：`tst_network_popup.qml:114` 断言的是 `list.height <= 5 * 36 + 4 * 6`，
  必须同步改成 `5 * 38 + 4 * 4`。

### 3.4 密码框

`wifiPasswordPanel` 里的裸 `TextInput` → `LazerSettingsTextField`
（`modules/lazerbar/LazerSettingsTextField.qml`，`FocusScope`，`implicitHeight: 38`）。
它**没有**取消通道，只有 `textCommitted(string)`、`clearRequested()` 和
`focusEditor()`，所以：

- Connect = `onTextCommitted` → `root.submitWifiPassword()`
- Cancel = 单独的 Cancel 按钮 → `root.cancelWifiPassword()`，与文本框解耦
- 面板打开时 `focusEditor()`；`echoMode` 走该组件自己的密码显示能力（先读它的现有
  契约确认是否已有开关，没有就保留裸 `TextInput` 的密码遮挡由它接管，不要自己加第二个
  输入通道）

74 高的面板高度改由内容实测决定，不再写死。

### 3.5 删重复底色

删除 `BarPopupActions.qml` 的 `trayContentBackground`（约 2560-2568）。
**保留** `BarTrayMenuContent.qml` 的 `menuFace` 和二级面板 —— 它们有不透明遮挡职责。

---

## 第 4 步：验证

按仓库规矩，QML 改完的默认门禁是日志：

```bash
scripts/check-shell.sh                 # 门禁；必须干净
python3 -m pytest scripts/tests/       # 含新增的守卫断言
scripts/qmltest.sh tests/qml/tst_popup_panel_metrics.qml
```

扩 `tst_volume_panel.qml`（headless-safe，直接跑）：

- 块数量 = 4，顺序 = 主音量 / 输出 / 输入 / 应用
- 块1 不在 `volumeScrollItem` 的子树里
- `volumeScrollItem.height <= volumeViewportCap`
- 混音可见行数 = 2
- 输入设备为 0 时块3 的可见性判定（若当前机器有输入设备，这条用纯逻辑测试覆盖）
- 常见机器上 `panel.height <= volumeViewportCap`

扩 `tst_network_popup.qml` —— **它在禁跑表里**，只能
`scripts/run-tests.sh -g`（会先打印警告），且必须手动确认当时屏幕上没有正在输入的东西：

- 块数量 = 3
- 多于一个有线口时端口头才出现
- Rescan 在 Wi-Fi 块的 y 范围内（不是面板面的直接子项）
- 面板高度 ≤ `PopupPanelMetrics.maxPanelHeight(Screen.desktopAvailableHeight)`
- 行高断言改成 38/4

回归证明要求：每一条「修好了」的说法都要有一条先红后绿的证据。环检测断言按 1.4 的
做法先手动触发一次失败；行高断言先改成旧值确认变红。

---

## 提交切分

1. `feat(bar): a shared section block for popup category groups`
   （`PopupPanelMetrics.js` + `PopupSectionBlock.qml` + qmldir + 纯逻辑测试 + 守卫扩展）
2. `refactor(volume): group the panel into section blocks, pin the master level`
3. `refactor(network): group the panel into section blocks, bound its height`

三处改动互相独立，可以逐个 review。第 1 步单独提是有意的：它不改变任何可见结果，
所以「共用件本身没问题」这件事可以被单独验证。