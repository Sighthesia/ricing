# 设置悬浮根因诊断设计

## Boundary

先建立可观察的输入路径，再按证据决定修复边界。诊断范围从 `PanelWindow.mask`、`LazerSettingsOverlay`、`LazerSettingsContent.viewport`、页面 Flickable，到 Row/card/control 的实际 hit target。`SettingsOverlayBridge` 只在日志证明请求生命周期错误时才进入修改范围。

## Evidence Loop

1. 在不改变产品行为的临时 harness 中构造真实挂载的 `LazerSettingsPanel` 或最小等价 surface。
2. 对每个目标点输出 screen/local 坐标、`mapToItem` 矩形、visible/enabled/opacity/z、当前 handler 状态和 tooltip source。
3. 先测试卡片空白区，再测试嵌入控件，再测试相邻 Row；一次只切换一个输入层。
4. 若 QtTest runner 仍静默，则使用 `qmlscene`/`qs` harness 或人工输入脚本，必须保存带断言结果的输出；不伪造 runner 通过。

## Ranked Hypotheses

1. PanelWindow mask 或上层窗口的实际输入区域与可见 settings panel 不一致。
2. 页面/viewport 的滚动或动画坐标与鼠标屏幕坐标映射不同步。
3. 输入事件由嵌入控件、透明层、dropdown catcher 或兄弟 surface 消耗，Row 只在局部区域收到事件。
4. Row 的 visible/enabled/height、Flickable contentHeight 或 Column implicitHeight 在运行时不等于视觉几何。
5. Tooltip bridge 请求残留仍造成旧指示器滞留，但这不能解释所有局部命中症状，只能作为后续验证项。

## Fix Constraints

- 不新增全屏 MouseArea 或透明输入拦截层。
- 保持 Slider 的值提示 priority 2 与 `nubItem` 几何源。
- 保持 Choice dropdown、TextField editor 和键盘 focus contract。
- 修复必须有坐标级回归或明确人工复现步骤。

## Rollback

诊断 harness 不进入生产模块；每个产品变更独立提交或保持最小 diff，便于回退到当前基线。
