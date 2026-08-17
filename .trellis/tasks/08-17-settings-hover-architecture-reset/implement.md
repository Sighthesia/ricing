# 执行计划

1. 运行任务校验，读取 frontend quality guidelines 与跨层思考指南，确认当前工作区只包含允许的变更。
2. 建立并运行可输出的诊断 harness，先对原始症状形成红结果；若自动 QML runner 仍不可用，记录可复现的人工坐标脚本和启动日志。
3. 按 mask、Content 叠层、Flickable 映射、Row/control z 和 Tooltip 生命周期逐项单变量验证，确定唯一或主导根因。
4. 根据 decision gate 选择证据指向的最小修复或组件框架重构；重构时先定义公开契约并只迁移一个代表性 Row。
5. 将已验证场景转为可维护回归覆盖，扩展到 Appearance、Bar、Notifications，覆盖边缘、控件内部、相邻、滚动、切换和重开。
6. 派发 `trellis-implement` 实施、`trellis-check` 审查；审查输入所有权、公开 API、Tooltip 几何和测试是否有循环论证。
7. 运行 `qmllint`、`python3 -m pytest -q`、`git diff --check`、`timeout 15s qs -p .`，单独记录 QML runner 的真实限制。
8. 只把已验证的可复用规则写入 frontend spec，使用 Conventional Commit 提交，完成 `task.py archive`。

## Rollback Points

- 诊断 harness：删除临时文件即可。
- 输入层局部修复：独立回退，不触碰持久化。
- 组件重构：按单个 Row 迁移批次回退，保证旧公开契约可恢复。
