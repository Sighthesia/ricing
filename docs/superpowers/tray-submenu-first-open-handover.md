# 托盘二级菜单首次展开无响应 — 排查交接

日期：2026-09-29 · 分支 `lazer` · 范围 `0cb78064..86a69a60`

## 症状

shell 启动后**第一次**展开托盘二级菜单时，悬浮无高亮、点击无效；**第二次及以后正常**。
故障时二级面板**仍然可见**，只是完全不响应。

## 已用数据排除（每条都有测量，不是推断）

| 层 | 结论 | 依据 |
| --- | --- | --- |
| 输入区 / 遮罩 | **排除** | 区域从第一帧就 512 宽（召唤时 756），列带仍 0 事件 |
| surface 映射抖动 | **排除** | `mapChurn` 全程为 1 |
| 被其他 surface 抢焦点 | **排除** | 表层 HoverHandler 全程跟随指针到 (1624,173)，从未 `hovered=false` |
| `enabled` 门控 | **排除** | `contentEnabled` 展开期间恒为 true |
| item 树几何 / 命中 / 映射 | **排除** | 42 条无头测试，含连续穿越的真实手势 |
| Qt legacy MouseArea 的 grab 交接 | **排除** | 同上，`test_continuousCrossingFromPrimaryOntoSubmenuRow` |
| 窄祖先阻断溢出子项 | **排除** | `test_narrowAncestorStillDeliversHoverToTheOverflowingColumn` |
| 通知 host 抢焦点 | **排除** | 故障时 `notifHeight=0`，且通知在左侧 x 560..920 |
| 首次 map 时区域为占位值 | **已修，非元凶** | 修后区域正确，症状不变 |

## 唯一剩下的现象

同一份代码、同一次会话内：

```
首次展开（失败）  evBand=0    hiS=0
再次展开（正常）  evBand=92   hiS=1
```

首次与之后的**唯一可测差异**是"首开"这个状态本身。列带尺寸位置全程正确
（252×356 @ x=244，覆盖 tray 244..496），指针走完其整个宽度（终点屏幕 x=1624）。

## 尚未排除的假设

**content exchange 的实例错配。** 诊断读的是 `popupActions.trayMenuContent`
（入场的那份内容）。若首次唤起时正在发生 content exchange，事件可能被送到了
**正在退场的那一份**，于是读数恒为 0，而屏幕上显示的是入场那份——这能同时解释
"面板可见"和"所有读数为 0"。

下一个检查：统计场景中 `popupContentSlot` 的实例数量，并**比对对象身份**确认
事件到达的内容是否就是诊断在读的那一份（不能只比数量）。

## 本轮真实产出（均经测试保护）

| 提交 | 内容 |
| --- | --- |
| `05c715d4` | 二级菜单第一行与触发行对齐——此前面板挂在触发行下方，"向右"这条肌肉记忆永远够不到任何一行 |
| `500b59e8` | 焊死一级与二级之间的 8px 接缝（视觉空隙会让人以为到边界了） |
| `864fd2f7` | 首次 surface map 前把容器归位到目标（首开时 target 还是占位值） |
| `4fa31387` | 修复原始指针探针——见下方"测量陷阱" |
| `c27989ed` | 逐事件 hover 追踪，替代 120ms 采样 |
| `e3fb7abe` | 输入区一次提交只重提交一次（原来四个属性各触发一次） |
| `0ec153a8` | 用真实连续手势驱动穿越的测试 |
| `7c68266f` | 可切换的 sized-surface 模式（实验用，默认关闭） |

## 需要你决策的两项

1. **`86a69a60` 预留二级列宽度**：使区域从打开起就是 512 宽。**未修复该 bug**，
   且有代价——托盘菜单打开期间，其右侧子菜单将来会出现的那条带会一直吃掉输入，
   在那上面点击不再穿透到桌面。若不留用建议回滚。
2. **`fcadb0ef` 关闭延后**（`_regionLeaveBudget`）：只是把死亡推迟 300ms，
   救不回指针。留作兜底还是回滚，由你决定。

`sized` 表面模式（`7c68266f`）会让菜单画到错误位置（`regionRect.x` 恒为 0），
实测更糟，**保持默认 `fullscreen` 即可，不要切换**。

## 测量陷阱（我踩过的，勿重蹈）

1. **`onPointChanged: function(point)` 收不到参数。** C++ 侧是零参数信号
   （`void pointChanged();` on `QQuickSinglePointHandler`），必须读 `point` 属性。
   写错会让 `point.position` 每次抛 TypeError、赋值从不执行，于是"指针不在"
   和"探针在崩"无法区分——**日志里当时躺着 519 条 TypeError 却没人看**。
2. **坐标系不可混用。** 托盘内容坐标 / 视口坐标 / 窗口坐标是三套空间。
   `Region.item` 用 `mapToScene` 提交，QML 里对应 `mapToItem(null, …)`。
   我曾拿局部坐标比全局坐标，得出过假结论。
3. **`mapToItem` 含 transform。** 面板的滑入是 `transform: Translate`，
   用它取探针点会拿到飞行途中的位置。探针要用布局坐标（`x`/`y`/`width`）。
4. **探针会扰动被测对象。** 把 `HoverHandler` 塞进 `MouseArea` 里会抢走行的
   点击权，导致"测量改变了被测行为"。
5. **QML 绑定里不能放对象字面量。** `cond ? { … } : x` 会把 `{` 当代码块解析。
6. **共享宿主的测试会互相污染。** 会改状态（打开弹窗）的断言必须放在序列最后。

## 环境限制

- offscreen 平台无 layer-shell 后端，`PanelWindow` 类 harness 只能走 `-g`（会闪真实窗口）
- 本机只有一块 eDP-1，niri 无 headless 模式，无 sway/weston/cage/labwc
- ⇒ **layer-shell 表层几何无法用无头测试触及**，这是本 bug 长期无解的根本原因
