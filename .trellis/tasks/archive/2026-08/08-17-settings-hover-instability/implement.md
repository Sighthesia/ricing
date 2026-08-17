# 执行计划

1. 读取并核对 Row、Choice、TextField、Slider、Content、Overlay 的实际层级与尺寸契约，记录所有可能的输入 owner。
2. 建立能在当前版本复现用户部分命中区域的运行时探针，输出 mapped geometry、hover/focus 状态和 Tooltip source；确认红色失败信号后再修改产品代码。
3. 按排名逐一验证事件命中、z-order、Flickable 坐标映射、上层菜单和 Bridge 生命周期假设，每次只改变一个变量。
4. 实施最小修复：统一 Row/card/control 命中与高亮，修复 Choice 焦点边框层级；仅在有证据时调整 Content/Bridge。
5. 将最小复现转换为真实挂载面板回归，覆盖五个外观行、三个分类、控件内部/边缘、滚动、分类切换及关闭重开。
6. 派发 `trellis-implement` 和 `trellis-check` 审查；运行 `qmllint`、`git diff --check`、Python 测试、`qs -p .`，并诚实记录 QML runner 缺口。
7. 根据诊断结论更新前端质量规范，提交 Conventional Commit，完成任务归档。

## Validation

- `qmllint` 覆盖所有修改的 QML 与回归测试。
- 运行时探针或正确配置的 QML 集成测试必须能对用户症状断言失败/通过。
- `python3 -m pytest -q`
- `git diff --check`
- `timeout 15s qs -p .`
- 直接 `qs -p tests/qml/...` 失败或 `qmltestrunner` 静默时，不计入成功证据。

## Rollback Point

仅回退本任务修改的命中层、焦点层级、诊断测试和规范文件；不回退此前已提交的 Tooltip activity source/优先级契约。
