# Final Polish Report — TwoLayerPopup narrow polish

日期: 2026-08-28
范围: 窄范围收尾，仅触及 TwoLayerPopup 抽象相关 feature/docs/test；未触及 services、锁文件、未跟踪 debug 文件。

## 任务对齐
本次按用户指令执行三项窄范围变更：
1. 简化 `sidebarRevealProgress` 为直接绑定 `root.revealProgress`
2. 新增聚焦 QtTest 覆盖 `sidebarData` / `contentData` 注入
3. 统一设计 spec 与 implementation plan 中公开常量的合法 Qt6 枚举路径为 `TwoLayerPopup.Orientation.Horizontal/Vertical` 与 `TwoLayerPopup.Direction.Up/Down`，不新增非法大写属性别名

## 改动清单
- `modules/lazerbar/TwoLayerPopup.qml:26`：`readonly property real sidebarRevealProgress: MotionTokens.reducedMotion ? root.revealProgress : root.revealProgress` → `readonly property real sidebarRevealProgress: root.revealProgress`。去除冗余三目，行为等价（原两分支同值）。
- `tests/qml/tst_two_layer_popup.qml`：
  - 新增 `injectedPopup: Lazer.TwoLayerPopup`，通过 `sidebarData: Rectangle { objectName: "injectedSidebar" }` 与 `contentData: Rectangle { objectName: "injectedContent" }` 声明式注入。
  - 新增 `test_sidebarDataAndContentDataInjection()`：遍历 `injectedPopup.sidebarLayer.children` / `contentLayer.children` 按 `objectName` 定位，校验 `parent` 归属与 `sidebarData.length>0` / `contentData.length>0`。保留原有 5 项 direction/reduced-motion/stagger 用例，未削弱。
- `docs/superpowers/plans/2026-08-27-two-layer-popup-abstraction-plan.md`：
  - Global Constraints：`orientation`/`direction` 改为 `TwoLayerPopup.Orientation.Horizontal/Vertical` / `TwoLayerPopup.Direction.Up/Down` 完整路径，新增禁止非法大写别名约束。
  - Task1 Step1 示例：`Lazer.TwoLayerPopup.Vertical` → `Lazer.TwoLayerPopup.Orientation.Vertical`，`Down/Up` → `Direction.Down/Up`。
  - Task1 Step3 示例：`readonly property int Horizontal/Vertical/Up/Down` → `enum Orientation { Horizontal, Vertical }` / `enum Direction { Up, Down }`，`TwoLayerPopup.Horizontal` → `TwoLayerPopup.Orientation.Horizontal`，`sidebarRevealProgress` 示例同步为 `root.revealProgress`。
  - Task2 Step2：`TwoLayerPopup.Horizontal` → `TwoLayerPopup.Orientation.Horizontal`。
- `docs/superpowers/specs/2026-08-27-two-layer-popup-abstraction-design.md`：
  - 组件与未来消费者段落统一为枚举完整路径，新增枚举暴露说明与非法别名禁令。

> 命名合规说明：Qt6 QML 禁止大写属性名，历史 plan 中 `TwoLayerPopup.Horizontal` 直访为非法；现统一为 `TwoLayerPopup.Orientation.Horizontal` 与 `TwoLayerPopup.Direction.Up/Down`。

## 验证命令（按要求逐项执行）

### qmltestrunner — focused popup
```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_two_layer_popup.qml -o -,txt
```
```
********* Start testing of qmltestrunner *********
Config: Using QtTest library 6.11.2, Qt 6.11.2 (x86_64-little_endian-lp64 shared (dynamic) release build; by GCC 16.2.1 20260810), arch unknown
PASS   : qmltestrunner::TwoLayerPopup::initTestCase()
PASS   : qmltestrunner::TwoLayerPopup::test_contentRevealWaitsForDelay()
PASS   : qmltestrunner::TwoLayerPopup::test_downDirectionStacksSidebarBeforeContent()
PASS   : qmltestrunner::TwoLayerPopup::test_reducedMotionBeginRevealRestoresBothLayers()
PASS   : qmltestrunner::TwoLayerPopup::test_reducedMotionEndRevealCollapsesBothLayers()
PASS   : qmltestrunner::TwoLayerPopup::test_sidebarDataAndContentDataInjection()
PASS   : qmltestrunner::TwoLayerPopup::test_upDirectionStacksContentBeforeSidebar()
PASS   : qmltestrunner::TwoLayerPopup::cleanupTestCase()
Totals: 8 passed, 0 failed, 0 skipped, 0 blacklisted, 11ms
********* Finished testing of qmltestrunner *********
```
exit:0

### qmllint
```bash
/usr/lib/qt6/bin/qmllint modules/lazerbar/TwoLayerPopup.qml modules/lazerbar/LazerSettingsPanel.qml
# exit:0 无 WARN/ERROR

/usr/lib/qt6/bin/qmllint tests/qml/tst_two_layer_popup.qml
# exit:0 无 WARN/ERROR
```

### git diff --check
```bash
git diff --check
# exit:0 无尾随空白/冲突标记
```

## 提交
仅提交本次窄范围变更的 feature/docs/test 文件，未纳入 `services/*`、未跟踪 debug 文件。

```bash
git add modules/lazerbar/TwoLayerPopup.qml tests/qml/tst_two_layer_popup.qml docs/superpowers/plans/2026-08-27-two-layer-popup-abstraction-plan.md docs/superpowers/specs/2026-08-27-two-layer-popup-abstraction-design.md .superpowers/sdd/2026-08-27-two-layer-popup-abstraction-plan/final-polish-report.md
git commit -m "polish(lazer): simplify popup reveal and clarify enum contracts"
```

## Scope 校验
- `git status --short` 中 `services/ColorService.qml`、`services/SettingsService.qml`、`services/qmldir` 仍为 M，未加入本次提交。
- 未跟踪文件 `142bpm.mp3, aubio.err, live_beats.txt, tst_*.qml` 未加入。
- `git diff --stat HEAD`（本次提交前）显示仅上述 4+1 文件为预期变更，其余为环境遗留未提交差异。

## Concerns
- `sidebarRevealProgress` 现直接绑定 `root.revealProgress`，与 `contentRevealProgress` 的 reducedMotion 分段逻辑分离；若未来 `sidebar` 需引入独立 delay，需恢复分段并补充时序测试。
- `sidebarData`/`contentData` 注入测试依赖 `objectName` 定位，覆盖 declarative 注入路径；未覆盖通过 JS `Qt.createQmlObject` + `sidebarData.push()` 的命令式注入，若后续支持该路径可补充。
- `docs/superpowers` 与 `.superpowers/sdd` 的 plan 副本已同步本次枚举路径；历史 review diff 仍保留旧非法示例，仅归档参考不影响实现。
- `tst_lazer_settings_panel` 在 `qmltestrunner` 下仍因 `Quickshell` 插件缺失而 FAIL（Task2 已记录的环境限制），与本次 polish 无关；已通过 `qmllint` 覆盖 panel 语法。
