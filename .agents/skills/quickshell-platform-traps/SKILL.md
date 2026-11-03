---
name: quickshell-platform-traps
description: "Use when a service shells out and the data is wrong or flips between runs, when a command actually ran the previous argv, when a stderr handler overwrites the result just received, when a component's surface never reaches the compositor (desktop shows niri's own background, only one qs: modelData warning), or when the lock screen is static, freezes pink, or its Repeater layers never paint."
---

# Quickshell / Qt 平台陷阱

本域收三个互不相关的框架层陷阱：`Quickshell.Io` 的 Process / StdioCollector 时序、`Variants` 的 delegate 劫持、`WlSessionLockSurface` 的渲染与生命周期约束。它们的共同点不在代码，而在失败方式 —— 三个陷阱**全部静默失败**：进程正常退出 0、没有任何 warning、surface 在对象树里存在却从不上屏、动画对象每个属性都符合预期却不绘制。所以判断顺序永远是先取证"它到底发生了没有"，再回头读代码。

## 先看这里

第一症状不是"代码看起来不对"，而是"数据或画面不对，却没有任何错误"。**第一反应是读日志、证明 surface 是否真的存在，而不是翻源码。** 两个命令先跑：

```sh
# 实例的完整日志（qs log 是环形缓冲，会滚掉）
tail -n 200 /run/user/1000/quickshell/by-id/<id>/log.qslog

# 合成器里实际有哪些 surface（缺 namespace = 从未 map，不是被遮挡）
niri msg -j layers | python3 -c "
import json,sys
for s in json.load(sys.stdin): print(f\"{s['layer']:11} {s['namespace']}\")"
```

日志里的文件前缀决定去哪找：`qs:@/qs/shell.qml: Setting initial properties failed: … modelData` 指的是 `shell.qml`，不是它提到的那个组件文件。像素也要确认 —— `grim` 采样后与 niri 的 `layout.background-color` 精确相等，说明合成器自己的背景露了出来，你的 surface 一个像素都没贡献。

## 按症状路由

| 症状 / 任务 | 读这个 |
|---|---|
| 服务 shell out 之后数据不对，或同样的操作两次运行结果不同 | `references/process-stdio.md` |
| stderr 的处理把刚拿到的正确结果又覆盖掉了（间歇性，取决于哪个流先关） | `references/process-stdio.md` |
| 命令看起来参数完全对，实际跑的却是上一次的 argv | `references/process-stdio.md` |
| 多阶段流水线中某一段没执行，整条链无声停住 | `references/process-stdio.md` |
| 某个组件的 surface 在合成器里完全没有（`niri msg -j layers` 里没有它的 namespace） | `references/variants-delegate.md` |
| 桌面显示的是合成器自己的背景色，自己的底板矩形也没画出来 | `references/variants-delegate.md` |
| 日志里只有一条 `qs:` 类别的 `modelData` 警告，其余一切正常 | `references/variants-delegate.md` |
| 锁屏静止无动画，或粉屏冻结 | `references/session-lock.md` |
| 锁屏里 `Repeater` 动态生成的层不上屏（对象存在、属性正确） | `references/session-lock.md` |

surface 已证明存在，但 hover / 点击 / 焦点 / 尺寸不对 —— 那不属于本域，转 `lazer-surface-debugging`。

## 通用法则

1. **静默失败优先取证。** 三个陷阱的证据来源是同一组：`/run/user/1000/quickshell/by-id/<id>/log.qslog`（完整日志）、`niri msg -j layers`（surface 是否 map）、`grim` 采样对比 niri 的 `layout.background-color` 与自己的底板色（是否真的画了像素）。先确认现象存在，再确认是哪一层的现象。
2. **静态检查通过不能证明 surface 存在。** 只读组件文件的检查可以在一整个 surface 已经死掉时保持绿色；`instances.length` 为 1 也不代表那个实例是正确类型。要证明，就必须拿出合成器侧或像素侧的证据。
3. **"注释声称的框架行为"不可信。** 那句"Variants 会丢掉所有非 Scope 的子项"正是让 bug 看起来安全的注释，而它与上游事实相反。凡是要依赖框架语义，就对照上游源码（`Q_CLASSINFO("DefaultProperty", …)` 这类声明）或写一个 offscreen 探针验证，不要相信注释。
4. **时序类修复，一次干净运行不算数。** 重启 shell 后至少读十次日志再相信结论，并用一个独立的交叉校验 Process 复读同一数据源做对比 —— 这正是暴露 stderr 覆盖问题的方式。判断证据够不够，按 `regression-proof` 的标准来。
