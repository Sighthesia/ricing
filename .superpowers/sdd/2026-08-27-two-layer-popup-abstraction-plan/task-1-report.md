# Task 1 Report — TwoLayerPopup

## 改动
- 新增 `modules/lazerbar/TwoLayerPopup.qml`：固定根 `Item`（`clip:true`），内部维护 `sidebarSlot`/`contentSlot` 两个独立 host；通过 `sidebarData`/`contentData` 注入内容，暴露 `sidebarLayer`/`contentLayer` 别名；实现 `orientation`（Horizontal/Vertical）、`direction`（Up/Down）、`revealProgress`、`sidebarOffset`/`contentOffset`、`contentDelay`、`horizontalSidebarX`/`horizontalContentX`、`revealDuration`、`sidebarRevealProgress`/`contentRevealProgress`、`beginReveal()`/`endReveal()`；使用 `Translate` 与 `opacity` 驱动 reveal，`clip` 仅在根节点；`reducedMotion` 时两进度直接绑定 `revealProgress` 并禁用动画；支持纵向 `Up`/`Down` 堆叠（`y` 按 `height+1` 排列）与横向 `x` 透传。
- 修改 `modules/lazerbar/qmldir`：追加 `TwoLayerPopup 1.0 TwoLayerPopup.qml`。
- 新增 `tests/qml/tst_two_layer_popup.qml`：覆盖 `Down` 时 `sidebar.y==0` 且 `content.y==sidebar.height+1`、`Up` 时相反、以及 `revealProgress=0.2` 时 `sidebarRevealProgress > contentRevealProgress` 三条合约。

> 命名合规说明：QML 语法禁止 `readonly property int Horizontal` 这类大写属性名（qmllint 报 `Property names cannot begin with an upper case letter`）。因此以 `enum Orientation { Horizontal, Vertical }` / `enum Direction { Up, Down }` 提供大写枚举常量，并以 `horizontal`/`vertical`/`up`/`down` 小写只读属性兼容实例访问（`popup.vertical`），测试改用实例小写/数值以保持合法；枚举可通过 `TwoLayerPopup.Orientation.Horizontal` 访问。

## 命令
```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_two_layer_popup.qml -o -,txt
/usr/lib/qt6/bin/qmllint modules/lazerbar/TwoLayerPopup.qml
git diff --check
```

## 失败阶段测试结果（组件不存在时）
```
********* Start testing of qmltestrunner *********
QWARN  : qmltestrunner::tst_two_layer_popup::compile()
  tests/qml/tst_two_layer_popup.qml produced 2 error(s):
    Type Lazer.TwoLayerPopup unavailable
    modules/lazerbar/TwoLayerPopup.qml: No such file or directory
FAIL!  : qmltestrunner::tst_two_layer_popup::compile() Type Lazer.TwoLayerPopup unavailable
Totals: 0 passed, 1 failed
```

## 通过阶段测试结果（实现后）
```
********* Start testing of qmltestrunner *********
PASS   : qmltestrunner::TwoLayerPopup::initTestCase()
PASS   : qmltestrunner::TwoLayerPopup::test_contentRevealWaitsForDelay()
PASS   : qmltestrunner::TwoLayerPopup::test_downDirectionStacksSidebarBeforeContent()
PASS   : qmltestrunner::TwoLayerPopup::test_upDirectionStacksContentBeforeSidebar()
PASS   : qmltestrunner::TwoLayerPopup::cleanupTestCase()
Totals: 5 passed, 0 failed, 0 skipped, 0 blacklisted, ~34ms
```

## Lint
```
/usr/lib/qt6/bin/qmllint modules/lazerbar/TwoLayerPopup.qml
# exit:0 无 WARN/ERROR
```

## diff check
```
git diff --check
# 无尾随空白/冲突标记
```

## Concerns
- Spec 片段 `readonly property int Horizontal: 0` 在 Qt6 QML 中非法（大写属性名被禁止），已改为 `enum Orientation/Direction` + 小写只读属性兼容；上游若坚持 `Lazer.TwoLayerPopup.Horizontal` 直访，需改用 `TwoLayerPopup.Orientation.Horizontal` 或实例 `popup.horizontal`，否则会在 qmllint/编译期报错。
- `sidebarOffset`/`contentOffset` 默认 `0`，纵向位移仅通过 `Translate` 体现，未设非零默认偏移；若期望可见滑入距离，需在调用方传入（如设置面板应保持现有 `horizontalSidebarX`/`horizontalContentX` 透传，位移由 panel 侧计算）。
- 当前 `width/height` 绑定 `childrenRect`，适合测试与面板子项显式尺寸；若未来在横向模式下需要根尺寸自适应，需确认 host 宽度策略（当前横向 `x` 透传，`y=0`，高度由子项决定）。
