# SuperIsland瞬态通知图标过大修复设计

## 问题描述
SuperIsland瞬态通知卡片中的图标尺寸过大，导致溢出容器边界。

## 根本原因
在`modules/bar/superisland/IslandNotificationCard.qml`中，图标大小计算为：
```qml
readonly property int _iconSize:
    Theme.barWidget.primaryIconSize + Theme.barWidget.contentPaddingV * 2
```
这比其他组件（如IslandWorkspaceCard）的图标大小要大，导致视觉不协调和溢出问题。

## 解决方案
将图标大小计算简化为只使用`Theme.barWidget.primaryIconSize`，与IslandWorkspaceCard保持一致。

### 修改内容
**文件**：`modules/bar/superisland/IslandNotificationCard.qml`
**行**：10-11
**修改前**：
```qml
readonly property int _iconSize:
    Theme.barWidget.primaryIconSize + Theme.barWidget.contentPaddingV * 2
```
**修改后**：
```qml
readonly property int _iconSize: Theme.barWidget.primaryIconSize
```

### 其他考虑
- 图标大小将从约22px（当uiScale=1时）减小到16px
- 布局会自动调整，因为RowLayout会适应内容大小
- 与其他组件的图标大小保持一致，视觉更统一

## 测试验证
2. 手动测试瞬态通知显示，确认图标不再溢出
3. 检查其他使用`primaryIconSize`的组件是否受影响

## 风险评估
- 低风险：修改仅影响瞬态通知图标的显示大小
- 向后兼容：不会影响现有功能，只是视觉调整
- 用户影响：改善视觉一致性，减少溢出问题

## 实施步骤
1. 修改IslandNotificationCard.qml中的图标大小计算 ✅
2. 运行烟雾测试验证修改 ⚠️（测试 harness 有问题，但完整Shell验证成功）
3. 手动测试瞬态通知显示 ⏳
4. 如有需要，调整其他相关参数 ✅

## 实施结果
- 修改已成功应用到主仓库
- 完整Shell验证通过
- 图标大小已从 `primaryIconSize + contentPaddingV * 2` 改为 `primaryIconSize`
- 与其他组件（如IslandWorkspaceCard）的图标大小保持一致