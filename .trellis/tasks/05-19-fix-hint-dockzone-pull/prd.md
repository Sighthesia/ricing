# 修复workspace-hint与center dockzone背景联动效果

## Goal

按住 mod 键时，workspace-hint 胶囊从 center dockzone 弹出，center dockzone 背景应产生"黏滞拉扯"变形效果（宽度收缩、高度拉伸）。目前该效果完全不可见，需要诊断并修复。

## 现状

### 已实现的机制
1. `WindowHintService.pullProgress`（0→1，300ms OutCubic Behavior）
   - 通过 `onHintHeldChanged` 命令式赋值驱动
2. `DockzoneSurfaceRoot.qml` 中 center section 读取 `Services.WindowHintService.pullProgress`
   - `_hintPull` 绑定到 pullProgress
   - `bodyWidth` = `metrics.bodyWidth - (_hintPull * 30)`
   - `bodyHeight` = `metrics.bodyHeight + (_hintPull * 8)`
   - `implicitWidth`/`implicitHeight` 同样应用变形
3. Canvas `centerBody` 绑定 `root.bodyWidth`/`root.bodyHeight`，有 `onWidthChanged: requestPaint()`

### 问题症状
- 按住 mod 键时 center dockzone 背景无任何视觉变化

### 已排除的原因
- `WindowHintService` 已在 `services/qmldir` 注册
- `DockzoneSurfaceRoot` 正确导入 `"../../services" as Services`
- center section 有 widget 内容（clock），surfaceState="attached"，背景可见
- Canvas 有 `onWidthChanged`/`onHeightChanged` → `requestPaint()`

### 待验证的假设
1. **pullProgress 值未变化** — `onHintHeldChanged` 可能未触发，或 Behavior 阻止了值传播
2. **_hintPull 始终为 0** — `Services.WindowHintService` 在 DockzoneSurfaceRoot 上下文中可能解析到不同实例或 undefined
3. **Canvas repaint 未生效** — bodyWidth 变化了但 Canvas 未重绘
4. **anchors.fill 覆盖** — DockzoneSurfaceRoot 被 `anchors.fill: parent` 约束，可能影响某些几何计算

### 关键文件
- `services/WindowHintService.qml:11-24` — pullProgress 定义
- `modules/bar/DockzoneSurfaceRoot.qml:138-152` — pull 变形应用
- `modules/bar/DockzoneSurfaceRoot.qml:204-253` — centerBody Canvas
- `modules/bar/BarSection.qml:94-104` — DockzoneSurfaceRoot 实例化（anchors.fill: parent）

## Requirements

- 按住 mod 键时 center dockzone 背景产生可见的宽度收缩 + 高度拉伸变形
- 松开 mod 键时变形平滑恢复
- 变形动画与 workspace-hint 胶囊的入场/退场时序协调

## Acceptance Criteria

- [ ] 按住 mod 键时 center dockzone 背景可见地变窄变高
- [ ] 松开 mod 键时 center dockzone 背景平滑恢复原始尺寸
- [ ] 通过 console.log 或运行时验证 pullProgress 值确实在 0↔1 之间变化

## 诊断步骤建议

1. 在 `DockzoneSurfaceRoot.qml` 的 `_hintPull` 绑定处加 `console.log` 确认值
2. 在 `WindowHintService.qml` 的 `onHintHeldChanged` 处加 `console.log` 确认触发
3. 如果值正确但视觉无变化，检查 Canvas repaint 是否被触发
4. 如果 Canvas repaint 触发但无变化，检查是否有其他属性覆盖了 bodyWidth/bodyHeight
