# DymicShell Skills Index

按主题加载 skill，避免把所有上下文一次性塞给代理。

## Architecture

- `qml-architecture`: QML 分层、文件结构、命名与 imports 规范。
- `qml-state`: Settings、共享状态、持久化与错误处理。

## Visual System

- `qml-components`: Token、语义色、基础交互表面模式。
- `contour-anchor-before-radius`: 圆角桥接/肩部轮廓不对时，先查曲线起点和轮廓锚点，再调半径。
- `qml-context-menu`: 右键菜单、托盘菜单与子菜单布局。
- `qml-token-cleanup`: 视觉 token 收敛、`Theme*` 单例拆分与硬编码几何清理。
- `qml-visual-language`: 视觉语言、连续表面与分页/列表动效契约。
- `multi-surface-semantic-ownership`: 一个视觉功能跨多个 root/shell/detached surface 时的所有权拆分。

## Motion

- `qml-indicator-motion`: 活跃指示器、滑动高亮、胶囊跟随动效。
- `visual-vs-layout-motion-ownership`: 动效复用时，把可见位移和布局预留所有权拆开，避免卡顿和 resize churn。
- `qml-motion-debug`: 动效状态正确但视觉表现不对时的排查方法。
- `single-instance-handoff-motion`: 单实例跨宿主交接时，避免 teleport、重影、提前消失和退场串层。
- `split-host-exit-synchronization`: 两个可见区域属于不同几何 owner 时，如何对齐退场节奏而不破坏其他动效。
- `list-transition-handoffs`: 通用列表过滤/替换过渡接管，尤其是空白帧、重叠、残影与快速更新中断问题。
- `exported-layout-width-ownership`: 视觉宽度和父布局实际测量宽度不同步时，优先排查 root export 链而不是全局布局。

## Performance

- `qml-performance-debug`: 布局抖动、窗口 resize churn、卡顿排查。
- `weak-signal-bridge-normalization`: 浏览器/扩展桥接弱 payload、占位字段、延迟标识的归一化与恢复策略。

## Workflow

- `reference-attribution`: 迁移外部实现时的归因方式。

## Data Flow

- `shared-summary-model-delegates`: 重复 delegate 应直接消费共享 summary model，避免全部塌缩到 active item。
- `session-latched-display-state`: 稀疏更新、短暂空值、弱信号期间保持显示层稳定，不要过早回退。
