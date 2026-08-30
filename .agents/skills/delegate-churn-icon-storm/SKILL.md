# Skill: delegate-churn-icon-storm

## 适用场景

修复 Afloat 中"长期运行后图标消失/不再渲染"或"高频信号驱动的可图标化列表"类 bug。
涉及：Workspaces/Tray 等以 JS 数组为 model 的 Repeater 图标列、`windowsUpdated`
等高频事件源、`image://icon` 异步加载。

## 根因模型（已实证）

Quickshell 0.3.1 的 `image://icon` 异步加载走 `QQuickPixmapReader` 线程。
把 model 换成全新 JS 数组会**销毁并重建整列 delegate**，每个 delegate 重新发起
一轮异步图片请求。事件越频繁（niri 聚焦切换是最高频），请求风暴越密集，长期
运行撞上跨线程竞态（日志特征：`QObject: Cannot create children for a parent
that is in a different thread ... QQuickPixmapReader`）后 delegate/绑定树损坏，
图标连同纯 Rectangle 的 tick/底条一起永久消失，数据层却依然正确。

## 修复契约（以 Workspaces.qml 为准）

1. **签名去重**：map 仅在"窗口集合/顺序/身份（winId|colIdx|rowIdx|appId）"
   实际变化时才替换（`mapSignature`）。内容相同的事件零重建。
2. **高频无关状态剥离**：聚焦态存独立 `focusedWinId` 字符串，tick/opacity 绑定
   它；绝不放进 model 行对象（行对象快照会在跳过重建时变陈旧）。
3. **可观测性**：暴露 `mapSwaps` 计数器；用探针（如 `tst_ws_probe.qml`）断言
   "聚焦切换时 swaps 不变、focusedWinId 变化、inMap==mapped"。

## 禁止

- 用 `modelData.isFocused` 这类行内快照做焦点显示（重建跳过时过期）。
- 在每次全量事件里替换整个 JS 数组 model。
- 把"图标消失"误判为图片资源问题：先检查**不依赖图片的纯 Rectangle**（tick、
  accent strip）是否也消失——它们消失说明是 delegate 树问题，不是图片问题。

## 排查顺序

1. `niri msg -j windows` 对照探针输出的 inMap/mapped —— 数据层是否同步。
2. 截图像素分析：找 tertiary 底条/focused tick（动态主题色从
   `~/.cache/quickshell/<shell-id>/colors.json` 的 tertiary 取值，勿用固定绿）。
3. 读实例 qslog 找 QQuickPixmapReader 线程告警。
