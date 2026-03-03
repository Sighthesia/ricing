# Bar Layout Animation Design

> **Status:** Draft

## 目标
当在设置模式下拖拽 Bar 组件时，提供平滑的空间挤占和恢复动画效果。

## 设计方案

### 1. 宽度渐变 (Width Animation)
- **实现位置**: [modules/bar/BarWidgetWrapper.qml](modules/bar/BarWidgetWrapper.qml)
- **逻辑**: 
    - 当前拖拽逻辑会将被拖拽组件的 `implicitWidth` 设为 0。
    - 增加一个 `Behavior on implicitWidth`，使用 `Theme.anim.moveDuration` 进行平减/平扩。
    - 效果：当组件被提起时，它原本占据的位置会缓慢收缩，周围组件平滑靠拢；当放下（或移动到新位置的 Ghost 占位符）时，空间平滑撑开。

### 2. 位置移动平滑 (Row Item Moving)
- **实现位置**: [modules/bar/BarSection.qml](modules/bar/BarSection.qml) 中的 `Row`。
- **挑战**: 在 `Row` 内部，子组件即便有 `Behavior on x`，也会被 `Row` 的自动布局算法重置。
- **推荐做法**: 
    - 使用 `Transition` 对 `Row` 的子组件位移进行增强：
      ```qml
      move: Transition {
          NumberAnimation { properties: "x,y"; duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
      }
      add: Transition {
          NumberAnimation { properties: "x,y"; duration: Theme.anim.moveDuration; easing.type: Theme.anim.moveType }
      }
      ```
    - 这能确保当某个组件宽度改变或增删时，其他组件的位移是带有平滑动画的。

### 3. Ghost 占位符动画 (可选)
- 目前 `BarSection` 使用 `Rectangle` 作为插入指示线。
- **改进**: 指示线在不同索引间移动时，增加位置动画 `Behavior on x`。

## 优缺点分析
- **优点**: 极低的代码改动量，完美适配现有 `Row` + `Repeater` 架构。
- **缺点**: 大规模重排时可能会有一点视觉上的微小抖动（受 QML Row 特效影响），但对于 Bar 这种少量组件场景表现优异。

---

是否批准此设计方案？
