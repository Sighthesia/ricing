# 启动开销：实测结论与修复方案

日期：2026-10-03
范围：bar 挂载路径上的构造开销（上一轮已修好壁纸与 lock 的竞争）

## 实测方法

三个离屏探针，全部走 `qs -p` + `QT_QPA_PLATFORM=offscreen`，不映射窗口：

- `tst_bar_widget_load_cost.qml` —— 真实 widget 文件 + 真实持久化布局，分冷/热两轮测
  「bar 挂载 → 内容填满」，并逐 widget 归因。
- `tst_invisible_subtree_cost.qml` —— 逐个构造 bar 启动路径上**从不显示**的子树，
  冷（编译+构造）与热（仅构造）各一次。
- 服务预热对照：先把 15 个 singleton 全部实例化，再跑分批填充。

## 实测数据

### bar 自己显示的 widget（10 个）

| | 冷 | 热 |
|---|---|---|
| bar 挂载 → 内容填满 | 196–576 ms | ~14 ms |
| 分批间隔 | 60–122 ms / 21–33 ms | — |
| 逐 widget 冷归因 | active-window 106、launcher 68、clock 56、media 37、tray 13、workspaces 11、volume 8、brightness 6、notifications 6、settings 4 | |

### 从不显示但照样构造的子树（每屏）

| 子树 | 冷 | 热 |
|---|---|---|
| popup/BarPopupActions | 238 ms | 20 ms |
| settings/LazerSettingsPanel | 181 ms | **154 ms** |
| popup/BarPopupIdentity | 100 ms | 1 ms |
| bar/BarIcon | 16 ms | 0 ms |
| widgets/ClockPopupContent | 9 ms | 8 ms |
| popup/BarContextPopupActions | 7 ms | 1 ms |
| bar/MarqueeLabel | 4 ms | 0 ms |
| settings/LazerSettingsSidebar | 2 ms | 2 ms |
| settings/LazerSettingsRow | 1 ms | 1 ms |
| settings/LazerSettingsContent | 1 ms | 1 ms |
| **合计** | **559 ms** | **188 ms** |

### 排除项

- **服务实例化不是主因**：预热 15 个 singleton 只花 5 ms，分批填充仍是 280 ms。
- **QML 编译不是主因**：逐文件 `Qt.createComponent` 显示 widget 文件编译合计仅约 30 ms。
- **不是调色板提取**：`ColorService` 在独立进程跑 `nice -n 19`，且有缓存短路。

## 结论

1. 开销的主体是**首次实例化**（建类型、建对象、解析字体、创建 shader-backed
   effect、光栅化 SVG），不是编译，也不是服务冷启动。
2. bar 的启动路径上每屏构造了 **559 ms 的隐形内容**，比它真正显示的 widget
   （300 ms）还多。`visible: false` 在 QML 里**不阻止构造**，只有
   `Loader.active` 才是构造门。
3. 这就是「bar 加载有延迟且略显卡顿」的直接来源：DymicShell 让 shell 与壁纸并行
   构造，Afloat 则把这些不可见子树压在了 bar 首次显示的关键路径上。
4. `LazerSettingsPanel` 的**热态仍有 154 ms**，说明它是真实的每实例构造成本
   （35 行 × Image + MultiEffect），不是一次性类型工作 —— 每次启动都会付，
   所以延后它能**永久**省下这段时间，而不只是首启。

## 修复方案

给两棵隐形子树加真正的 `Loader.active` 门，首次使用时才构造：

- `LazerSettingsOverlay.qml` —— `LazerSettingsPanel` 首次打开前不构造。
- `BarPopupHost.qml` —— 弹窗内容树在拿到第一个 intent 前不构造。

两处都必须**保持对外 API 与信号不变**：调用方（`TopBar.qml`、测试宿主）仍按原样
访问 `panel` / `sidebarLayer` / `contentLayer` / `contentData`，未加载时读数必须
是安全的空值而不是 `undefined`。

## 验证

- 两个探针都留在仓库里，作为长期的成本回归观测点（`scripts/run-tests.sh` 会跑）。
- 每次改动后重跑两个探针，比较 `[subtree]` 与 `[cost]` 的数字。
- 现有启动专项（`tst_startup_reveal_logic`、`tst_wallpaper_slot_wiring`、
  `tst_startup_cold_paths`、`tst_lock_startup_order`、`tst_bar_content_startup`）
  必须保持全绿。