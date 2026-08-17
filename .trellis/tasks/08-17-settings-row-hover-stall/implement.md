# 执行计划

## Steps

1. 在挂载的 `tst_lazer_settings_panel.qml` 中先增加活性来源失效后回退不得复活旧 Tooltip 的回归场景，并覆盖 Slider 的 Thumb 锚点与行描述回退。
2. 扩展 `SettingsOverlayBridge.showTooltip()` 请求记录，使其携带可选 `activitySource`；只有显式传入的来源参与活性过滤，保留三参数调用语义。
3. 在 `LazerSettingsRow` 和 `LazerSettingsSlider` 公开稳定的 `tooltipActive` 状态，并在请求 Tooltip 时分别传入 Row 或 Slider 根项。
4. 在 `LazerSettingsContent` 中集中校验请求是否仍为当前 Content 的有效活跃来源，再用于请求接管、几何重定位后的关闭以及 Bridge 回退选择。
5. 运行质量检查、审查差异，并在确认无新警告后更新前端 Tooltip 合约、提交与完成任务。

## Validation

- `qmllint` 覆盖变更的 QML 与测试文件。
- 以支持 QML 模块导入的测试入口运行新增面板回归；若本机 `qmltestrunner` 继续静默且 JUnit 未产生用例，明确记录为测试基础设施限制。
- `python3 -m pytest -q`
- `git diff --check`
- `timeout 15s qs -p .`，仅允许已知通知服务 D-Bus 占用警告。

## Review And Rollback

- 重点检查：跨屏来源隔离、同优先级稳定性、Slider `nubItem` 身份、失活来源不会被回退重新显示。
- 仅提交本任务涉及的 QML、测试、必要规范和任务工件；必要时以本任务的单个 conventional commit 回滚。
