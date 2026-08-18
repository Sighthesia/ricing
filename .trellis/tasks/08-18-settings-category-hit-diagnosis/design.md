# 技术设计：设置分类前段命中诊断

## Diagnostic Seam

使用现有 `SettingsService` debug IPC 和 `LazerSettingsOverlay.debugSnapshot()` 作为初始 seam；扩展 snapshot 只用于记录分类和页面状态，不添加鼠标捕获层。

诊断数据分为三层：

```text
Panel
  -> currentPage / all page enabled + opacity + contentY
Content
  -> viewport rect + current page rect/contentHeight
Rows
  -> row rect/sceneRect + visible/enabled/hover/focus
Controls
  -> control rect/sceneRect + enabled/activeFocus + focus owner
```

## Comparison Matrix

每个分类生成一条稳定快照，按页面声明顺序取目标 Row。结果需要能够直接比较：

- Page state: `enabled`, `visible`, `opacity`, `z`, `contentY`, `contentHeight`
- Viewport: local rect, clip, visible/enabled
- Row: rect, sceneRect, visible/enabled/opacity/z, hover/focus
- Control: rect, sceneRect, visible/enabled/opacity/z, activeFocus

当前 debug snapshot 只递归前四个 Row；诊断入口应支持显式目标列表或完整 Row 列表，避免把“前五个”误判为“前四个”。

## Probe Order

1. 打开 overlay 并等待 `phase=open`。
2. 对 Appearance、Bar、Notifications 分别选择分类，等待页面 opacity 稳定为 1。
3. 采集 page/viewport/rows 状态。
4. 使用同一 scene 坐标策略对 Row 空白、control 中心分别执行 hover/click/focus 采样；若没有 Wayland pointer injection，记录为环境限制，不伪造行为结论。
5. 根据矩阵结果只改变一个变量进行假设验证：page enabled、Flickable interaction、层级或控件 focus owner。

## Implementation Boundary

本阶段原则上只修改诊断入口和测试；只有当某个假设有明确红/绿证据后，才修改对应生产组件。生产修复必须保持：Row observer 非阻塞、无 Row 点击转发、无 tooltip。

## Regression

优先在 `tests/qml/tst_lazer_settings_panel.qml` 增加完整分类 snapshot contract；若 QML runner 仍被 `qrc:/qs-blackhole` 阻断，保留测试代码作为后续环境可运行回归，并以 `qmllint`、配置加载和运行时 JSON 记录作为当前验证。
