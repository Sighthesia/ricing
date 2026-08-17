# 执行计划

1. 读取并核对当前任务、前端规范、Overlay/Panel/Content/Flickable/Row/controls 的输入边界。
2. 建立 runner-discoverable 的最小 harness；若 runner 仍不可用，建立 `qmlscene`/`qs` 输出探针或人工坐标脚本。
3. 记录修复前红色结果，覆盖用户报告的完整矩形和跨分类路径。
4. 按命中层、坐标映射、层级遮挡、焦点和 Tooltip 生命周期顺序验证假设，一次只改一个变量。
5. 实施被证据支持的最小产品修复，并将最小复现固化为可运行回归或人工脚本。
6. 派发 `trellis-implement` 与 `trellis-check`，运行 lint、Python、`qs -p .` 和 diff 检查。
7. 仅记录已验证的规范更新，提交 Conventional Commit，归档任务并确认工作区干净。

## Validation

- `qmllint` 覆盖所有修改的 QML 和 harness。
- 诊断命令必须有明确的失败/通过信号，不能以静默退出为通过。
- `python3 -m pytest -q`
- `git diff --check`
- `timeout 15s qs -p .`
- 直接 `qs -p tests/qml/...` 的导入失败必须单独报告。
