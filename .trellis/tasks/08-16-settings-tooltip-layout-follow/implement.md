# Settings Tooltip Layout And Follow Implementation Plan

## 1. Pure Geometry Contracts

- [ ] 在 `LazerSettingsLogic.js` 增加 tooltip 宽度 clamp、矩形相交和 placement 纯函数。
- [ ] 扩展 logic tests，覆盖短/长文本约束、左右边缘、上下翻转、空间不足和非法输入。

验证：`tst_lazer_settings_logic.qml`。

## 2. Fix Text Measurement

- [ ] 重构 `LazerSettingsContent.qml` tooltip Text/Item/Rectangle 尺寸所有权。
- [ ] Text 提供 natural width，受约束 width 后提供 wrapped height；Tooltip 再加 padding。
- [ ] 暴露测试只读属性：text item、active source、placement side、实际 tooltip geometry。
- [ ] 添加短文本完整显示和长文本换行不裁切测试。

验证：Panel component tests。

## 3. Add Reactive Source Following

- [ ] 保存 active tooltip source/text/priority。
- [ ] 动态监听 source geometry/visible、Content geometry、viewport 和 page contentY。
- [ ] 将滚动行为从直接关闭改为重定位；source 完全离开 viewport 时关闭。
- [ ] 保留 owner ancestor 过滤和 dropdown lifecycle。

验证：source move、scroll follow、offscreen close、multi-owner isolation tests。

## 4. Anchor Slider Tooltip To Nub

- [ ] `LazerSettingsSlider` 暴露 `nubItem`。
- [ ] Slider tooltip 请求改用 Nub source，hide 使用相同 source identity。
- [ ] 验证拖动/值动画时 Tooltip X 跟随 Nub，Row tooltip priority 仍被 Slider 覆盖。

验证：controls + panel tests。

## 5. Motion And Lifecycle

- [ ] Tooltip opacity 使用现有 in/out token，geometry 更新不做滞后位置动画。
- [ ] content close、category/search change、source destruction 时清理 active state。
- [ ] reduced motion 下无位置误差、无残留。

验证：panel/overlay tests，Overlay 顺序重复两轮。

## 6. Full Verification

- [ ] 顺序运行六个 Settings QML suites。
- [ ] 运行 Python tests、`git diff --check`、`qs -p .`。
- [ ] 独立检查测量域、滚动跟随和多屏 owner，不接受只测 token。

## Risky Files

- `LazerSettingsContent.qml`: tooltip measurement、position、source lifecycle 的唯一 owner。
- `SettingsOverlayBridge.qml`: priority/source identity；不应重新引入跨屏广播响应。
- `LazerSettingsSlider.qml`: show/hide 必须使用同一个 Nub source identity。
- `tst_lazer_settings_panel.qml`: composed geometry test，必须等待 polish 后读取 wrapped height。

## Before Start Gate

- [x] 根因已通过源码确认。
- [x] 用户选择滚动时持续跟随可见 source，完全离开后关闭。
- [x] PRD、design、implementation plan 已完成。
- [ ] 用户审核最终规划摘要并在后续消息批准实现。
