# 执行计划：设置面板组件交互区域重构

## Ordered Checklist

1. 更新 `SettingsOverlayBridge.qml`，移除 tooltip signals、request registry、tooltip 查询和清理函数，保留下拉菜单 bridge API。
2. 更新 `LazerSettingsRow.qml`，让 row-level hover 成为唯一 hover 状态来源；删除 tooltip refresh、tooltip lifecycle Connections 和控件 hover 合并逻辑。
3. 更新 `LazerSettingsTextField.qml`、`LazerSettingsChoice.qml`、`LazerSettingsSlider.qml`、`LazerSettingsToggle.qml`，删除独立 hover API 及其视觉/tooltip 依赖，保留实际操作 handler。
4. 更新 `LazerSettingsContent.qml`，删除 tooltip 状态、surface、定位、fallback、Connections、debug snapshot 和 alias；保留下拉菜单层。
5. 搜索全仓库残留的设置 tooltip 调用、`tooltipActive`、控件 `hovered` 依赖和旧 alias，逐一确认是删除还是非设置面板功能。
6. 更新 `tests/qml/tst_lazer_settings_controls.qml`、`tst_lazer_settings_panel.qml`、`tst_lazer_settings_overlay.qml`：删除旧 tooltip 行为断言，增加无 tooltip 请求、无 tooltip surface、Row-only hover 和控件操作区域断言；保留下拉菜单测试。
7. 运行相关 QML tests、`qmllint`、`qs -p .` 和 Python tests；处理所有新增 WARN/ERROR。
8. 检查 diff、运行 Trellis check，提交单一 conventional commit。

## Validation Commands

```bash
qmllint modules/lazerbar/LazerSettingsRow.qml \
  modules/lazerbar/LazerSettingsTextField.qml \
  modules/lazerbar/LazerSettingsChoice.qml \
  modules/lazerbar/LazerSettingsSlider.qml \
  modules/lazerbar/LazerSettingsToggle.qml \
  modules/lazerbar/SettingsOverlayBridge.qml \
  modules/lazerbar/LazerSettingsContent.qml

qs -p tests/qml/tst_lazer_settings_controls.qml
qs -p tests/qml/tst_lazer_settings_panel.qml
qs -p tests/qml/tst_lazer_settings_pages.qml
qs -p tests/qml/tst_lazer_settings_overlay.qml

python3 -m pytest -q
timeout 15s qs -p .
git diff --check
```

## Risk Points

- 删除 `tooltipActive` 可能影响 `LazerSettingsContent` 的 debug snapshot 或其他设置组件隐式依赖；实现前必须全仓搜索。
- `SettingsOverlayBridge` 是 singleton，测试中的 `clearTooltips()` 和 SignalSpy 需要同步删除或改为只测试 dropdown。
- `LazerSettingsContent` 的 tooltip 删除不能影响 dropdown layer 的 z-order、outside-click catcher 或 focus 返回。
- Row 的 `HoverHandler` 必须保持非阻塞，否则可能重新引入控件点击/拖拽失效。
- TextField 的 `TapHandler` 不得扩大到 Row；只能保留在 TextField 自身项上。

## Review Gate

- 代码实现前需要确认本规划摘要已获用户批准。
- 实现完成后优先检查行为回归和命中区域，再检查视觉细节。
- 若 QML 测试环境仍出现 `qrc:/qs-blackhole` 加载错误，记录为环境阻塞，不以静态检查替代相关行为验证。

## Execution Result

- `qmllint` passed for all changed settings components and their affected QML tests.
- `timeout 15s qs -p .` loaded the production configuration successfully; the existing notification-server registration warning remained.
- `python3 -m pytest -q` passed (`4 passed`).
- Settings QML tests could not load because the existing test environment resolves local components through missing `qrc:/qs-blackhole`; none reached assertions.
