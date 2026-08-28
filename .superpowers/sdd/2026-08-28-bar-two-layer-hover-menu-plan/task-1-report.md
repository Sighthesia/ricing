# Task 1 Report — Define hover intent and geometry logic

## 改动
- 新增 `modules/bar/BarHoverLogic.js`：纯 JS 库（`.pragma library`），无 QML 单例引用，实现四项合约：
  - `popupDirection(barPosition)`：规范化 `trim().toLowerCase()`，仅 `"bottom"` 返回 `"up"`，其余返回 `"down"`。
  - `clampAnchor(anchorX, popupWidth, screenWidth, margin)`：数值 `Number()` 化，非有限或负值回落为 `0`；返回 `anchorX` 在 `[margin, screenWidth - popupWidth - margin]` 间的夹紧值，若 `max < min` 则塌为 `min`（零宽安全）。
  - `shouldClose(widgetHovered, popupHovered, closePending)`：仅当两 hover 宿主均为 falsy 且 `closePending` 为 truthy 时返回 `true`。
  - `hoverPayload(widgetId, instanceKey, title, iconSource, summary, actionKind)`：返回含六个规范化字符串字段的普通对象（`null/undefined` → `""`，其余 `String()`），无 QML 引用。
- 新增 `tests/qml/tst_bar_hover_logic.qml`：聚焦 QtTest，导入 `BarHoverLogic.js`，覆盖简报要求的 4 组契约 plus 边界用例（大小写/空白归一、异常数值零宽安全、pending 为 falsy 时不关闭、hoverPayload 归一与 actionKind 透传）。
- 未修改 `modules/bar/qmldir`：项目该文件仅注册 QML 组件，未注册 JS 模块，符合简报“only if the project registers JS modules there”。

## 命令
```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_bar_hover_logic.qml -o -,txt
```

## 失败阶段测试结果（BarHoverLogic.js 不存在时）
```
********* Start testing of qmltestrunner *********
Config: Using QtTest library 6.11.2, Qt 6.11.2 (x86_64-little_endian-lp64 shared (dynamic) release build; by GCC 16.2.1 20260810), arch unknown
QWARN  : qmltestrunner::tst_bar_hover_logic::compile()
  /home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat/tests/qml/tst_bar_hover_logic.qml produced 2 error(s):
    /home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat/tests/qml/tst_bar_hover_logic.qml:3,1: Script file:///home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat/modules/bar/BarHoverLogic.js unavailable
    /home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat/modules/bar/BarHoverLogic.js: No such file or directory
  Working directory: /home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat
FAIL!  : qmltestrunner::tst_bar_hover_logic::compile() Script file:///home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat/modules/bar/BarHoverLogic.js unavailable
   Loc: [/home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat/tests/qml/tst_bar_hover_logic.qml(3)]
Totals: 0 passed, 1 failed, 0 skipped, 0 blacklisted, 1ms
********* Finished testing of qmltestrunner *********
```

## 通过阶段测试结果（实现后）
```
********* Start testing of qmltestrunner *********
Config: Using QtTest library 6.11.2, Qt 6.11.2 (x86_64-little_endian-lp64 shared (dynamic) release build; by GCC 16.2.1 20260810), arch unknown
PASS   : qmltestrunner::BarHoverLogic::initTestCase()
PASS   : qmltestrunner::BarHoverLogic::test_anchorClampsToZeroWidthSafeOnInvalidNumbers()
PASS   : qmltestrunner::BarHoverLogic::test_anchorOverflowClampsToMax()
PASS   : qmltestrunner::BarHoverLogic::test_anchorStaysInsideScreen()
PASS   : qmltestrunner::BarHoverLogic::test_bottomBarOpensUp()
PASS   : qmltestrunner::BarHoverLogic::test_closeRequiresPending()
PASS   : qmltestrunner::BarHoverLogic::test_closeWaitsForBothHoverOwners()
PASS   : qmltestrunner::BarHoverLogic::test_hoverPayloadNormalizesFields()
PASS   : qmltestrunner::BarHoverLogic::test_hoverPayloadPreservesActionKinds()
PASS   : qmltestrunner::BarHoverLogic::test_hoverPayloadReturnsPlainObject()
PASS   : qmltestrunner::BarHoverLogic::test_popupDirectionNormalized()
PASS   : qmltestrunner::BarHoverLogic::test_topBarDefaultForUnknownPosition()
PASS   : qmltestrunner::BarHoverLogic::test_topBarOpensDown()
PASS   : qmltestrunner::BarHoverLogic::cleanupTestCase()
Totals: 14 passed, 0 failed, 0 skipped, 0 blacklisted, 16ms
********* Finished testing of qmltestrunner *********
```
- 无 `FAIL!` / `WARN` / `ERROR`。

## Lint
- `BarHoverLogic.js` 为纯库，无 QML 组件可 lint；`qmllint` 不适用于 JS 库。测试文件 `tst_bar_hover_logic.qml` 在 `qmltestrunner` 编译期已通过语法校验。

## diff check
```
git diff --check
# 无尾随空白/冲突标记（仅聚焦文件）
```

## Concerns
- `clampAnchor` 对非法数值的处理：`popupWidth/screenWidth/margin` 非有限或负值回落为 `0`，`anchorX` 非有限回落为 `0`，此时 `max = s - w - m` 若小于 `min` 则取 `min`。该策略保证零宽安全且与简报“invalid numbers resolve to zero-width safe values”一致，但若调用方期望 `NaN` 传播错误，需在更上层校验。
- `popupDirection` 归一化包含 `trim` 与 `toLowerCase`，因此 `" Bottom "` 与 `"BOTTOM"` 均映射为 `"up"`；若未来 barPosition 枚举扩展（如 `left/right`），当前实现仍回落为 `"down"`，符合简报“otherwise down”但需与 Task 2 的 host 方向契约保持一致。
- `hoverPayload` 仅做 `String()` 归一，未做 `trim` 或空值过滤，保留调用方原始空白；若上游需要去空白摘要，应在 adapter 层处理。
- `shouldClose` 使用 `!widgetHovered && !popupHovered && !!closePending` 的真值语义，兼容布尔与非布尔传入，但若 Task 2 以非布尔哨兵（如 `0/1`）传入，行为仍符合“both hover owners are false and close is pending”。
