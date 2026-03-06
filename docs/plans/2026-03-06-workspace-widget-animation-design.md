# WorkspaceWidget 动画质感提升 — Design Document

**Date:** 2026-03-06  
**Status:** Approved

## Overview

WorkspaceWidget（Dynamic Island 风格胶囊）当前在 Focus↔Overview 模式切换时仅做透明度淡入淡出，缺乏空间层次感。本次改动通过三个小幅修改提升交互体验：

1. 内容切换加入 Y 轴位移
2. Hover 高亮轻微增强
3. 宽度变形 easing 换用 OutCubic

## 改动范围

仅修改 `modules/bar/widgets/WorkspaceWidget.qml`，不涉及任何服务、配置或其他组件。

---

## Section 1 — 内容切换 Y 轴位移

### 语义设计

Overview 和 Focus 形成**垂直层级关系**：Overview 在上层，Focus 在下层。

| 切换方向         | 退出行为                          | 进入行为                      |
| ---------------- | --------------------------------- | ----------------------------- |
| Focus → Overview | `_focusRow` 下沉 +6px 同时淡出    | `_overviewRow` 从居中位置淡入 |
| Overview → Focus | `_overviewRow` 上浮 -6px 同时淡出 | `_focusRow` 从居中位置淡入    |

### 实现

修改两个 Row 的 `y` 绑定，加入模式驱动偏移量，并各自添加 `Behavior on y`。

**`_overviewRow`（当前 Overview 内容层）：**
```qml
// Before:
y: (root._pillH - implicitHeight) / 2

// After:
y: (root._pillH - implicitHeight) / 2 - (root._showOverview ? 0 : 6)
Behavior on y {
    enabled: root._initialized
    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
}
```

`_overviewRow` 激活时居中，退出时上移 6px（向上淡出）。

**`_focusRow`（当前 Focus 内容层）：**
```qml
// Before:
y: (root._pillH - implicitHeight) / 2

// After:
y: (root._pillH - implicitHeight) / 2 + (root._showOverview ? 6 : 0)
Behavior on y {
    enabled: root._initialized
    NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
}
```

`_focusRow` 激活时居中，退出时下移 6px（向下淡出）。

### 约束

- 偏移量 6px 适配 `_pillH` 约为 28–34px 的常见范围，约占 pill 高度的 20%。
- `Behavior on y` 与现有 `Behavior on opacity` 共用 `moveDuration`/`moveType`，保证位移与淡出严格同步。
- `_initialized` 防护确保首屏不会从偏移位置动画到中心。
- `_flashStrip` 不受影响（它有独立的 `y` 绑定和 `Behavior`）。

---

## Section 2 — Hover 高亮增强

主 pill 的 hover 覆盖层透明度从 `0.08` 提升至 `0.12`。

```qml
// Before:
opacity: _hoverArea.containsMouse ? 0.08 : 0

// After:
opacity: _hoverArea.containsMouse ? 0.12 : 0
```

仍低于工作区小 pill 的 `0.15`，保持视觉层次。动画参数不变。

此外，为了让 hover 效果与工作区切换保持一致，我们现在在
`_hoverArea.onEntered` 中调用 `_triggerFlash()`，因此悬浮也会产生
下方 flash strip 扩展，让用户感知到状态切换而不仅仅是颜色变化。

---

## Section 3 — 宽度动画 Easing 改进

主 pill `implicitWidth` 的 `Behavior` 将 easing 从 `Theme.anim.moveType`（`InOutCubic`，对称加速）改为 `Easing.OutCubic`（立即响应，逐渐减速）。

```qml
// Before:
NumberAnimation {
    duration: Theme.anim.moveDuration
    easing.type: Theme.anim.moveType
}

// After:
NumberAnimation {
    duration: Theme.anim.moveDuration
    easing.type: Easing.OutCubic
}
```

**理由：** `InOutCubic` 起步缓慢（与用户交互意图节奏不符），`OutCubic` 立即响应并逐渐收尾，感觉更"灵敏"。`OutCubic` 无过冲，不会使 pill 短暂变得比内容更窄（避免文字被裁剪）。

**不引入全局 Token：** 此更改仅适用于胶囊宽度，不代表通用 move transition 语义，不推广至 `Theme.anim`。
