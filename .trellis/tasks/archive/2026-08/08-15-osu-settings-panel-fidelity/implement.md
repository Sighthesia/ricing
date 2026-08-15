# Settings Panel Fidelity Implementation Plan

## 1. Pure Contracts And Tests

- [ ] 更新 `LazerSettingsLogic.js`：Sidebar expanded/contracted、Content、总宽和窄屏夹紧函数，以及 query normalize/match 函数。
- [ ] 先更新 `tst_lazer_settings_logic.qml`，覆盖 `70/170/400/570`、非法尺寸、空查询和标题/描述匹配。
- [ ] 添加 MotionTokens（如需要）：content readiness、sidebar item stagger、sidebar item fade、collapse duration；避免在组件内散落 magic number。

验证：`qs -p tests/qml/tst_lazer_settings_logic.qml`。

## 2. Searchable Settings Pages

- [ ] 为 `LazerSettingsRow.qml` 增加搜索契约，保持 `enabled` 与过滤可见性独立。
- [ ] 为 Appearance、Bar、Notifications 页面增加 `searchQuery` 和 `visibleResultCount`，显式连接每个 row。
- [ ] 保持三个页面常驻、原有 alias、settingsObject/saveCallback 和 contentY 行为。
- [ ] 扩展 controls/pages 测试，覆盖标题/描述筛选、空查询恢复、disabled row 可搜索和 `400px` 布局。

验证：`qs -p tests/qml/tst_lazer_settings_controls.qml`、`qs -p tests/qml/tst_lazer_settings_pages.qml`。

## 3. Sidebar And Content Components

- [ ] 新增 `LazerSettingsSidebar.qml`：`70/170px` 手动折叠、三项导航、图标/标签、单一选中态、关闭入口和逐项 stagger。
- [ ] 新增 `LazerSettingsContent.qml`：expandable header、搜索框、固定搜索区、viewport、阴影、footer 和空结果。
- [ ] 调整 `LazerSettingsNavItem.qml` 与视觉 token，使用现有图标库/文本符号惯例，不引入后端依赖。
- [ ] 为主要 QML declaration 添加项目要求的简短前置注释。

验证：隔离加载新组件，并运行 Panel/Controls 测试。

## 4. Panel Composition

- [ ] 重构 `LazerSettingsPanel.qml`，组合独立 Sidebar/Content layer，保留现有设置页、alias、category contract 和 transition token。
- [ ] 实现每次打开默认 expanded、打开期间折叠保持、Content X 联动和查询生命周期。
- [ ] 定义完整 Tab、方向键、Enter/Space 与 close focus 顺序。
- [ ] 更新 `tst_lazer_settings_panel.qml`，覆盖尺寸、折叠、搜索、空结果、页面状态、快速切换和 reduced motion。

验证：`qs -p tests/qml/tst_lazer_settings_panel.qml`，重复运行以暴露 focus/event timing race。

## 5. Overlay Motion And Lifecycle

- [ ] 重构 `LazerSettingsOverlay.qml`，固定 owner 几何并分别驱动 Sidebar/Content 位移与 opacity。
- [ ] 增加可取消的 `200ms` content readiness token；打开中关闭、关闭中重开均从当前 progress retarget。
- [ ] 将焦点恢复和 Coordinator close completion 保持在最终 closed 分支。
- [ ] 更新 `tst_lazer_settings_overlay.qml`，覆盖独立位置、stagger、readiness、interruption、Escape、focus 和 reduced motion。

验证：`qs -p tests/qml/tst_lazer_settings_overlay.qml`，至少连续运行两次。

## 6. Visual Calibration And Full Regression

- [ ] 对照本地 osu!lazer 源码校准颜色、间距、字级、row 高度、header/search/footer 层级和 scroll shadow。
- [ ] 在桌面和窄屏尺寸检查无重叠、裁切、文字溢出和布局跳动。
- [ ] 检查展开、收起、快速关闭/重开和 reduced motion 的视觉终态。
- [ ] 运行所有相关 QML 测试并修复本次引入的 WARN/ERROR。
- [ ] 运行 Python backend tests、`git diff --check` 和真实 `qs -p .` 配置加载。

## Validation Commands

```bash
qs -p tests/qml/tst_lazer_settings_logic.qml
qs -p tests/qml/tst_lazer_settings_controls.qml
qs -p tests/qml/tst_lazer_settings_pages.qml
qs -p tests/qml/tst_lazer_settings_panel.qml
qs -p tests/qml/tst_lazer_settings_overlay.qml
pytest
git diff --check
qs -p .
```

## Risky Files And Rollback Points

- `LazerSettingsOverlay.qml`: owner lifecycle、焦点恢复和 Coordinator completion；先保留公开方法/信号。
- `LazerSettingsPanel.qml`: 页面常驻和 category transition；每阶段先保持 alias 与测试契约。
- `LazerSettingsRow.qml`: 所有设置页共用；搜索可见性不得覆盖 disabled opacity/interaction。
- 三个 settings page: 只加搜索 wiring，不重写保存逻辑。
- `MotionTokens.qml` / `LazerTheme.qml`: 保持纯 token singleton，不导入 Services。

## Before Start Gate

- [x] 架构方案由用户选择：单一 Settings owner 内拆分 Sidebar/Content。
- [x] Sidebar 策略由用户选择：手动 `70/170px` 折叠，不 hover expand。
- [x] 搜索范围由用户选择：真实过滤当前分类标题/描述。
- [x] PRD、design、implementation plan 完整。
- [ ] 用户审核最终规划摘要并在后续消息明确批准实施。
