---
name: lazer-surface-debugging
description: "Use when a Quickshell/QML surface looks healthy but behaves wrong: layer-shell surface 已 mapped 但不绘制、屏幕上什么都不画；祖先 visible 绑到子孙 visible 后整棵子树读回 false；控件第一次能用、第二次打开收不到键盘输入；hover 不触发、高亮缺失或 popup 在指针不动时闪烁；全屏透明层吃掉下层事件；可见 owner 迁移后 hover 动画消失或右键编辑失效；内容被裁切但理论最大尺寸够大、左右越宽裁得越多；弹窗溢出主列后溢出区无响应；设置页切页后控件只在窄条响应。先定位真实事件/渲染 owner，再只在被证明的那一层改。"
---

# Lazer 表面排障

本域回答一类问题：**表面看起来正常，行为却不对。** 状态标志健康、几何非零、compositor 说已上屏，但用户看到的是不绘制、不响应 hover、收不到键盘、被裁切。

核心结论：这类 bug 几乎从不待在你正在看的那个元素里，而待在该元素的 **owner 关系**里——谁真正持有渲染、事件、内容、编辑、几何这五份职责。所以排障的第一步永远是定位 owner，而不是修改元素本身。

## 先看这里

按这个顺序做两件事，能砍掉一半分支，不要先去读动画数值或调 `z`：

**第一步：确认这层 surface 到底在不在。** 用 namespace 找到它，不要靠猜。

```sh
niri msg -j layers      # 找 WlrLayershell.namespace（如 afloat-bar、afloat-popup）
```

- 列表里没有这行 namespace：问题在挂载/实例化（`Variants` delegate、import 黑洞、命名空间缺失），不在渲染路径——出本域，去看 `quickshell-platform-traps`。
- 有这行、layer 也对、但什么都不画：继续第二步。**此时任何改 `layer`/`z`/exclusive zone/边距的尝试都是浪费时间，compositor 已经证明它上屏了。**

**第二步：三行同步写读测 `visible`。** 在运行时快照里对目标做，不要靠读代码推断：

```qml
console.log("before:", target.visible)
target.visible = true
console.log("immediately after write:", target.visible)   // false ⇒ 可见性环
```

写入不生效（同步读回 `false`、`onVisibleChanged` 也不触发）⇒ 祖先链里有人把 `visible` 绑到了这个子孙，`Item.visible` 读的是 **effective** 值（`localVisible && parentVisible && …`），没有值能写出来，改绑定以外的一切都是徒劳。直接读 `references/effective-visibility.md`。

写入生效 ⇒ 可见性不是问题，剩下的只可能是几何/裁切（`references/measurement.md`）、owner 迁移（`references/owner-split.md`）或事件路由（`references/pointer-starvation.md`、`references/focus-ownership.md`、`references/overflow-hit-testing.md`）。

诊断函数里打印的 `item.visible` 报的是 effective 值——它会**证实错误的故事**。只信上面这三行的同步结果。

## 按症状路由

| 症状 / 任务 | 读这个 |
|---|---|
| `niri msg -j layers` 里 surface 已 mapped，但屏幕上什么都不画、子树高度塌到 0；或某个祖先的 `visible` 绑到（间接依赖）子孙的 `visible`，写 `visible = true` 同步读回 `false`、`onVisibleChanged` 不触发 | `references/effective-visibility.md` |
| 可见 surface 迁到新宿主后 hover 动画消失、右键编辑入口失效、编辑模式只剩占位内容、宽度不再跟随内容 | `references/owner-split.md` |
| hover 高亮不触发、hover 驱动的 popup 在指针不动时反复开关闪烁、全屏透明层吃掉下层事件；设置页切页后控件只在一条窄条里响应、日志里出现另一个分类的名字 | `references/pointer-starvation.md` |
| 输入框 / 搜索框第一次能用，第二次打开（或切页后）收不到键盘输入，光标在但打字没反应 | `references/focus-ownership.md` |
| 内容被裁切但理论最大尺寸明明够大；左右两侧越宽裁得越多；动画结束后尺寸仍停在过渡值 | `references/measurement.md` |
| 弹窗/子菜单溢出主列后，溢出区没有 hover 和点击，而 compositor 的 input region 看着是够宽的 | `references/overflow-hit-testing.md` |

一行里并列多个现象，是因为它们指向同一个 owner 缺陷、该读同一个文件。先按「先看这里」排除可见性，再进对应文件；症状同时命中两行时，先用「先看这里」的第二步把可见性摘掉，剩下的那一行通常就唯一了。

## 通用法则

六个来源反复出现的其实是同一套判断顺序。照这个顺序走，不要跳步：

1. **先定位真实 owner，再看元素。** 渲染 owner（谁真正画用户看到的那层）、事件 owner（该坐标上最上层接受事件的元素）、内容 owner（谁渲染真实控件而不是占位）、编辑 owner（右键菜单/拖拽把手归谁）、几何 owner（谁从当前内容算宽高）。六份文件里的 `Generic Checklist` / `Universal Checklist` 都是这五个问题的变体。在哪一层停止触发，那一层就是 owner——加 presence probe 从外到内逐层打日志，不要从 handler 代码猜。
2. **再排除 mapped / state 假象。** `contentEnabled=true`、`submenuInteractable=true`、`opacity: 1`、快照里的 `visible: true`、`open=true` 全部只描述「状态」，不描述「事件是否送达」「像素是否画出」。真实的证据只有三个：compositor 的 mapped 行、三行同步写读测、以及探针日志里第一个不再触发的层。
3. **只在被证明的那一层改。** 一次只动一个 owner。同时改 `clip`、内边距、动画时长和 catcher 宽度的结果，是下次没人知道哪一处起了作用——overflow 的「Common Failed Fixes」和 measurement 的「paint guard 反而让镜像区间更糟」都是这条的代价。
4. **边界用一个像素级的 A/B 关闭来证明，不要猜。** 怀疑谁就单独关掉谁，只看现象是否翻转：`hoverEnabled: false` / `pointer-events: none` 证明上层是否偷事件；把**恰好一个** `clip: true` 改成 `false` 证明裁切 owner；关掉全屏 overlay 的 input mask 证明是否覆盖了自己的触发器。不翻转就不是那一层，立刻改回，别叠加补救。
5. **只在第二次打开、切页后、或快速扫过时才复现的 bug，是陈旧 owner 或竞态，不是稳态路径。** 去数活着的实例、数被复用的 `heldHeight` 之类的 sticky 值、数状态机里「标志已翻但旧体还挂着」的窗口，不要动 timing 常数。
6. **修完要能重复失败再重复通过。** 一次干净的日志读数是噪声，见 `regression-proof` skill 的验证纪律。

各来源的「Warning Signs」高度重合，可以直接当收窄工具用：区域可见但不可编辑；能开菜单但不显示真实内容；宽度从占位切成动态后仍莫名固定；右键只对背景生效；hover 在一个 owner 上生效而渲染在另一个 owner 上。
