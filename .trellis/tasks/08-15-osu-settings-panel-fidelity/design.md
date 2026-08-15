# Settings Panel Fidelity Design

## Architecture

保留现有 `LazerSettingsOverlay` 作为唯一生命周期、焦点和关闭 owner。其固定宽度由 `LazerSettingsLogic.sidePanelWidth()` 限制为最大 `570px`，窗口与外层 Item 在动画期间不改变尺寸。

Overlay 内部拆成两个兄弟视觉层：

- `sidebarLayer`: 宽度在 `70px` 与 `170px` 间切换，拥有背景、折叠按钮、分类按钮、选中指示和返回/关闭入口。
- `contentLayer`: 常规宽度固定 `400px`，拥有 header、固定搜索区、页面 viewport、scroll shadow 与 footer。其最终 X 等于当前 Sidebar 宽度。

两层通过 Overlay 的 `progress` 派生各自 X 和 opacity。Content 从 `-570px` 进入，Sidebar 从 `-170px` 进入；两者终点分别为 `sidebarWidth` 和 `0`。这保持单一 compositor surface，同时让 scene graph 中的视觉 owner、几何和动画真正分离。

## Component Boundaries

- `LazerSettingsOverlay.qml`: phase 状态机、open/close 中断、200ms 内容激活延迟、最终焦点恢复。
- `LazerSettingsPanel.qml`: 设置域状态、Sidebar/Content 组合、折叠状态、分类选择、搜索查询、页面存活和键盘导航。
- `LazerSettingsSidebar.qml`（新增）: Sidebar 背景、折叠按钮、三项导航及 40ms stagger；不读取服务。
- `LazerSettingsContent.qml`（新增）: expandable header、搜索框、viewport、footer 和空结果层；通过属性接收三个持久页面或由 Panel 组合。
- `LazerSettingsNavItem.qml`: 增加图标、折叠标签表现、appear progress/opacity 契约，保留键盘激活。
- `LazerSettingsRow.qml`: 增加 `searchQuery`、`matchesSearch` 和 `searchVisible`；标题与描述是唯一搜索文本来源。
- 三个设置页面: 接收 `searchQuery`，向每一行传递查询并汇总 `visibleResultCount`；控件数据绑定和 save 回调保持原样。
- `LazerSettingsLogic.js`: 统一 `70/170/400/570` 几何、查询规范化和文本匹配纯函数。

## State And Data Flow

```text
Coordinator request
  -> LazerSettingsOverlay.openFrom(opener)
  -> phase=opening, progress retargets to 1
  -> Panel begins Sidebar stagger immediately
  -> 200ms timer marks contentReady
  -> search gets focus when interactive and ready

Search input
  -> LazerSettingsPanel.searchQuery
  -> current persistent page.searchQuery
  -> each LazerSettingsRow.matchesSearch
  -> visible/height participation + page.visibleResultCount
  -> Content empty-result state

Setting control
  -> existing settingsObject mutation
  -> existing saveCallback
  -> no search/sidebar state enters persistence
```

三个页面始终挂载。非当前页面禁用且不可聚焦；搜索只应用到当前页面的布局结果，但查询字符串传给所有页面，确保切换分类后无需第二套更新路径。

## Motion Contract

- Open: Sidebar 与 Content 均 `600ms / OutQuint`，从当前 progress retarget 到 1。
- Close: 从当前 progress retarget 到 0；退出曲线沿用现有 close 路径，但两层分别计算位置，不创建第二生命周期状态机。
- Content readiness: open 后 `200ms`；快速关闭会取消 token，旧回调不得重新显示内容。
- Sidebar items: index `i` 的显示延迟为 `i * 40ms`，淡入 `500ms / OutQuint`。关闭时取消待执行 delay 并统一淡出。
- Category switch: 保留现有 `160ms` 交叉淡入与 `8px` 方向提示，快速切换使用 token 拒绝旧 callback。
- Sidebar collapse: `300ms / OutQuint` 在 `70/170px` 间切换；Content 只移动 X，不改变宽度。
- Reduced motion: Sidebar/Content X 直接使用终点；item stagger 不做空间位移，只保留短淡入；200ms readiness 与焦点顺序仍保持。

## Search Contract

- 查询使用 `trim().toLowerCase()` 规范化。
- 空查询匹配所有行。
- 非空查询匹配 `labelText` 或 `descriptionText` 的子串，大小写不敏感。
- disabled row 仍可匹配并显示；`enabled` 和 `searchVisible` 是独立维度。
- 不匹配行从 Column 布局中移除（`visible=false`, `height=0`），但组件不销毁。
- 切换分类保留查询；关闭再打开清空查询，与原作 `ShowAtControl` 会重置搜索的行为一致。

## Focus And Input

- 打开后搜索框为首选焦点；若内容尚未 ready，则焦点暂留 Panel，并由有效 token 在 ready 后转移。
- Tab 顺序为搜索、当前页可见控件、Sidebar 当前导航、折叠按钮、关闭/返回入口，再循环。
- 上下键在 Sidebar 导航间移动；Enter/Space 激活；Escape 仍由 Overlay 请求关闭。
- 折叠 Sidebar 不移动 active focus owner；若焦点在导航项上，只改变标签可见性。
- 最终关闭才恢复 opener；跨 owner 切换不在中间恢复。

## Responsive Geometry

- 可用宽度 `>=570px`: `170 + 400` 展开，`70 + 400` 收起。
- 可用宽度 `<570px`: Sidebar 仍为 `70/170px`，Content 使用剩余宽度并最低安全夹紧；若无法容纳展开态，折叠按钮仍可用且内容优先保留。
- 设置行以 `400px` 为正常布局基准；控件宽度预算沿用 `availableWidth`，窄于阈值时切换纵向紧凑布局。
- 所有宽高输入对 NaN、Infinity 和负数归一化为非负安全值。

## Compatibility And Rollback

- 不修改 `SettingsService`、配置 schema、Coordinator target 或公开 owner 信号。
- 保留 `appearancePage`、`barPage`、`notificationPage`、导航和 close alias，减少现有测试与调用方破坏。
- 风险集中在 Overlay/Panel/Row 和三个页面；若视觉结构回归，可按层回退新增 Sidebar/Content，而无需回滚后端或配置数据。

## Verification Strategy

- 纯逻辑测试覆盖新几何、查询规范化和匹配。
- Panel 测试覆盖分层尺寸、折叠、真实筛选、空结果、页面存活、键盘、快速分类切换和 reduced motion。
- Overlay 测试覆盖独立 layer 位移、200ms readiness、快速关闭/重开、stagger 取消、Escape 与焦点恢复。
- Controls/pages 测试继续覆盖即时保存、禁用态和 `400px` 下布局。
- 真实 `qs -p .` 验证 QML 加载无 WARN/ERROR，并通过截图/人工观察检查 Sidebar 与 Content 分层和 stagger 节奏。
