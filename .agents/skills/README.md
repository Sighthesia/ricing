# DymicShell Skills Index

按主题加载 skill，避免把所有上下文一次性塞给代理。

## Architecture

- `qml-architecture`: QML 分层、文件结构、命名与 imports 规范。
- `qml-state`: Settings、共享状态、持久化与错误处理。

## Visual System

- `qml-components`: Token、语义色、基础交互表面模式。
- `attached-expansion-geometry`: SuperIsland / media attached bridge 几何，尤其是鼓包、缺口、肩部过宽这类连接问题。
- `qml-context-menu`: 右键菜单、托盘菜单与子菜单布局。
- `qml-token-cleanup`: 视觉 token 收敛、`Theme*` 单例拆分与硬编码几何清理。
- `qml-visual-language`: 视觉语言、连续表面与分页/列表动效契约。

## Motion

- `qml-indicator-motion`: 活跃指示器、滑动高亮、胶囊跟随动效。
- `attached-expansion-motion`: 复用 SuperIsland attached panel 开合/throw-catch 时的所有权拆分与防卡顿模式。
- `qml-motion-debug`: 动效状态正确但视觉表现不对时的排查方法。
- `superisland-window-hint-exit-timing`: SuperIsland window hint 退场时序排查，尤其是 title/workspace 背景退场不同步、退出目标宽度取错、改坏 throw/catch 对位时。
- `list-transition-handoffs`: 通用列表过滤/替换过渡接管，尤其是空白帧、重叠、残影与快速更新中断问题。
- `bar-widget-width-ownership`: bar widget 的视觉宽度、spring 宽度与独占宽度不同步时，优先排查 widget root 到 `BarWidgetWrapper` 的导出链，而不是直接改全局 bar 布局。

## Performance

- `qml-performance-debug`: 布局抖动、窗口 resize churn、卡顿排查。
- `netease-web-lyrics-stability`: NetEase 网页歌词桥稳定性排查，尤其是弱 payload 抢断歌词会话、闪回歌名/浏览器名、歌词不连续推进。

## Workflow

- `reference-attribution`: 迁移外部实现时的归因方式。
