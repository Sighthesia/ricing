# SuperIsland瞬态通知图标过大修复实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 修复SuperIsland瞬态通知图标过大的问题，使图标大小与其他组件保持一致。

**Architecture:** 修改IslandNotificationCard.qml中的图标大小计算，将`_iconSize`从`primaryIconSize + contentPaddingV * 2`改为只使用`primaryIconSize`，与IslandWorkspaceCard保持一致。

**Tech Stack:** Quickshell QML, Theme tokens, SuperIsland组件

---

### Task 1: 修改IslandNotificationCard.qml中的图标大小

**Files:**
- Modify: `modules/bar/superisland/IslandNotificationCard.qml:10-11`

**Step 1: 备份当前文件**

```bash
cp modules/bar/superisland/IslandNotificationCard.qml modules/bar/superisland/IslandNotificationCard.qml.backup
```

**Step 2: 修改图标大小计算**

将第10-11行从：
```qml
readonly property int _iconSize:
    Theme.barWidget.primaryIconSize + Theme.barWidget.contentPaddingV * 2
```
改为：
```qml
readonly property int _iconSize: Theme.barWidget.primaryIconSize
```

**Step 3: 验证修改**

检查修改后的文件内容：
```bash
grep -n "_iconSize" modules/bar/superisland/IslandNotificationCard.qml
```
预期输出：第10行显示`readonly property int _iconSize: Theme.barWidget.primaryIconSize`

**Step 4: 提交修改**

```bash
git add modules/bar/superisland/IslandNotificationCard.qml
git commit -m "fix: reduce SuperIsland transient notification icon size to match other components"
```

### Task 2: 运行SuperIsland服务烟雾测试

**Files:**

**Step 1: 运行烟雾测试**

```bash
```

**Step 2: 检查测试结果**

预期输出：测试通过，无错误信息

**Step 3: 如果测试失败，检查错误信息**

根据错误信息调整修改或修复相关代码

**Step 4: 提交测试结果（可选）**

如果测试通过，可以提交测试结果记录

```bash
git commit -m "test: verify SuperIsland transient notification icon fix"
```

### Task 3: 手动测试瞬态通知显示

**Files:**
- 手动测试SuperIsland瞬态通知的显示

**Step 1: 启动DymicShell**

```bash
qs --path .
```

**Step 2: 触发瞬态通知**

通过以下方式触发瞬态通知：
- 发送系统通知
- 切换媒体播放
- 切换窗口

**Step 3: 检查图标显示**

观察SuperIsland中的瞬态通知图标：
- 图标是否不再溢出容器边界
- 图标大小是否与其他组件一致
- 布局是否正常

**Step 4: 记录测试结果**

如果发现问题，记录具体现象并修复

### Task 4: 检查其他组件的图标大小一致性

**Files:**
- 检查IslandWorkspaceCard.qml
- 检查IslandMediaCard.qml

**Step 1: 检查IslandWorkspaceCard.qml中的图标大小**

```bash
grep -n "primaryIconSize" modules/bar/superisland/IslandWorkspaceCard.qml
```

**Step 2: 检查IslandMediaCard.qml中的图标大小**

```bash
grep -n "primaryIconSize" modules/bar/superisland/IslandMediaCard.qml
```

**Step 3: 确保图标大小一致性**

确认所有SuperIsland组件使用相同的图标大小基准

**Step 4: 提交检查结果（可选）**

如果发现不一致，可以提交修复

### Task 5: 运行完整测试套件

**Files:**
- 运行所有SuperIsland相关测试

**Step 1: 运行SuperIsland烟雾测试套件**

```bash
```

**Step 2: 检查测试结果**

预期：所有测试通过

**Step 3: 运行完整Shell验证**

```bash
timeout 10 qs --path .
```

**Step 4: 提交测试结果**

```bash
git add tests/
git commit -m "test: verify all SuperIsland tests pass after icon fix"
```

### Task 6: 文档更新

**Files:**
- 修改docs/plans/2026-03-16-superisland-transient-notification-icon-fix-design.md

**Step 1: 更新设计文档**

添加实施结果和测试验证信息

**Step 2: 提交文档更新**

```bash
git add docs/plans/2026-03-16-superisland-transient-notification-icon-fix-design.md
git commit -m "docs: update design document with implementation results"
```

### 执行选项

**Plan complete and saved to `docs/plans/2026-03-16-superisland-transient-notification-icon-fix-plan.md`. Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**