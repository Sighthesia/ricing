# 执行计划

1. 运行任务上下文校验，读取前端规范和现有 settings 输入契约。
2. 建立真正可输出的运行时 harness；记录代表性 Row 的 screen/local/mapped geometry、命中层和状态链，先复现再修改。
3. 单变量验证 mask、Content 叠层、Flickable 映射、Row/control z 层和 Tooltip 生命周期。
4. 依据证据选择局部修复或组件框架重构；不得同时改变多个输入所有权。
5. 将最小复现转为三类页面的回归覆盖，保留 Slider/Choice/TextField/Toggle 既有交互契约。
6. 派发 `trellis-implement` 与 `trellis-check`，审查组件职责、层级、跨层状态流和测试缺口。
7. 运行 `qmllint`、`python3 -m pytest -q`、`git diff --check`、`timeout 15s qs -p .`；明确报告 QML runner 是否仍不可用。
8. 只把已验证的可复用规则写入 frontend quality spec，使用 Conventional Commit 提交并归档任务。

## Rollback Points

- 诊断 harness：删除即可。
- 局部输入层修复：单独回退，不触碰页面持久化。
- 组件重构：按迁移批次回退，确保旧 Row contract 可恢复。
