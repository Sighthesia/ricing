# WorkspaceWidget 动画质感提升 — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 通过三处精准修改提升 WorkspaceWidget 动画质感：内容切换 Y 轴位移、Hover 高亮增强、宽度 easing 改进。

**Architecture:** 仅修改 `modules/bar/widgets/WorkspaceWidget.qml`，不触碰服务层、配置层或其他组件。所有改动为纯声明式 QML，遵循现有 Behavior + Token 模式。

**Tech Stack:** QML / Quickshell，无新依赖。

**Design Doc:** `docs/plans/2026-03-06-workspace-widget-animation-design.md`

---

### Task 1: 主 pill 宽度 Easing 改为 OutCubic

**Files:**
- Modify: `modules/bar/widgets/WorkspaceWidget.qml:257-263`

**Step 1: 定位目标代码**

文件第 257 行为主 pill `implicitWidth` 的 `Behavior`：

```qml
Behavior on implicitWidth {
    enabled: root._initialized
    NumberAnimation {
        duration: Theme.anim.moveDuration
        easing.type: Theme.anim.moveType   // ← InOutCubic，改为 OutCubic
    }
}
```

**Step 2: 应用修改**

将 `easing.type: Theme.anim.moveType` 替换为 `easing.type: Easing.OutCubic`。

改后：
```qml
Behavior on implicitWidth {
    enabled: root._initialized
    NumberAnimation {
        duration: Theme.anim.moveDuration
        easing.type: Easing.OutCubic
    }
}
```

**Step 3: 验证**

启动 Quickshell，在 WorkspaceWidget 在 Focus↔Overview 之间切换（鼠标移入移出、切换工作区），观察宽度变化是否感觉"立即响应、缓慢收尾"而非"两头缓慢"。

---

### Task 2: Hover 透明度 0.08 → 0.12

**Files:**
- Modify: `modules/bar/widgets/WorkspaceWidget.qml:272`

**Step 1: 定位目标代码**

文件第 272 行为主 pill hover 覆盖层：

```qml
opacity: _hoverArea.containsMouse ? 0.08 : 0
```

**Step 2: 应用修改**

改为：
```qml
opacity: _hoverArea.containsMouse ? 0.12 : 0
```

**Step 3: 验证**

鼠标悬停于 WorkspaceWidget，观察 hover 高亮是否可见但克制。

---

### Task 3: `_overviewRow` 添加 Y 轴位移

**Files:**
- Modify: `modules/bar/widgets/WorkspaceWidget.qml:282-291`

**Step 1: 定位目标代码**

文件第 282 行为 `_overviewRow`（Overview 内容行）的 y 绑定：

```qml
Row {
    id: _overviewRow
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: undefined
    y: (root._pillH - implicitHeight) / 2   // centred within the main pill zone
    spacing: root._pillGap
    opacity: root._showOverview ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }
```

**Step 2: 修改 y 绑定并添加 Behavior on y**

将 `y: ...` 单行改为模式驱动公式，并在 `Behavior on opacity` 之前插入 `Behavior on y`：

```qml
Row {
    id: _overviewRow
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: undefined
    // Active: centered; exiting to focus mode: rise up by 6px
    y: (root._pillH - implicitHeight) / 2 - (root._showOverview ? 0 : 6)
    spacing: root._pillGap
    opacity: root._showOverview ? 1 : 0

    Behavior on y {
        enabled: root._initialized
        NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }
```

**Step 3: 验证**

切换至 Focus 模式时，Overview 行应向上轻微滑动并淡出。

---

### Task 4: `_focusRow` 添加 Y 轴位移

**Files:**
- Modify: `modules/bar/widgets/WorkspaceWidget.qml:435-447`

**Step 1: 定位目标代码**

文件第 435 行为 `_focusRow`（Focus 内容行）的 y 绑定：

```qml
Row {
    id: _focusRow
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: undefined
    y: (root._pillH - implicitHeight) / 2   // centred within the main pill zone
    spacing: root._iconTitleGap
    opacity: root._showOverview ? 0 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }
```

**Step 2: 修改 y 绑定并添加 Behavior on y**

```qml
Row {
    id: _focusRow
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: undefined
    // Active: centered; exiting to overview mode: sink down by 6px
    y: (root._pillH - implicitHeight) / 2 + (root._showOverview ? 6 : 0)
    spacing: root._iconTitleGap
    opacity: root._showOverview ? 0 : 1

    Behavior on y {
        enabled: root._initialized
        NumberAnimation { duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Theme.anim.moveDuration
            easing.type: Theme.anim.moveType
        }
    }
```

**Step 3: 验证**

切换至 Overview 模式时，Focus 行（图标+标题）应向下轻微滑动并淡出；切回 Focus 模式时，Overview 行上移淡出，Focus 行从下方进入并居中淡入。

---

### Task 5: 整体回归验证

**Step 1: 冷启动测试**

重启 Quickshell，确认 WorkspaceWidget 初始渲染时 **无**动画闪烁（`_initialized` 防护有效）。

---

### Task 6: Hover 触发 Flash 效果

**Files:**
- Modify: `modules/bar/widgets/WorkspaceWidget.qml:~{hoverArea}` (search for `onEntered` handler)

**Step 1: 定位目标代码**

找到 `_hoverArea` 的 `onEntered` 处理器：

```qml
onEntered: {
    if (!root._hoverActive || root._justReverted) return
    _revertTimer.stop()
    // If already overridden (e.g. re-entry after moving out briefly), just
    // hold the current state rather than flipping back immediately.
    if (root._modeOverride !== "") return
    // Flip to opposite of current visual state.
    root._modeOverride = root._showOverview ? "focus" : "overview"
}
```

**Step 2: 应用修改**

在 `if` 检查后、修改 `_modeOverride` 之前调用 `_triggerFlash()` so the same
flash strip animation plays on hover.

```qml
onEntered: {
    if (!root._hoverActive || root._justReverted) return
    _revertTimer.stop()
    if (root._modeOverride !== "") return
    _triggerFlash()
    root._modeOverride = root._showOverview ? "focus" : "overview"
}
```

**Step 3: 验证**

在有聚焦窗口或至少一个工作区存在的情况下把鼠标移入 pill，观察是否
展开 flash strip 并播放与 workspace 切换相似的动画。

### Task 7: 再次回归测试

重复 Task 5 的所有 Verify 步骤，确保 hover-flash 改动没有破坏其它行为。

**Step 2: Focus↔Overview 切换测试**

- 移入鼠标触发 hover 切换，确认 Y 位移方向正确
- 切换工作区触发 flash，确认 flash strip 行为不受影响
- 快速连续切换工作区，验证无动画堆叠异常

**Step 3: 宽度变化测试**

- 打开/关闭应用，观察 Focus 模式下标题长度变化时宽度动画响应
- Focus↔Overview 切换时观察宽度变形是否更"灵敏"

**Step 4: Hover 测试**

悬停确认高亮可见，离开确认平滑淡出。
