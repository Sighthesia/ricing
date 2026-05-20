# Center Dockzone Island 展开

## Goal

让 bar 的 center dockzone 在用户点击时从紧凑 widget 行弹性展开为 Dynamic Island 风格的面板，作为**启动器（App Launcher）和剪贴板历史**的载体，替代当前独立的全屏 LauncherWindow。

参考实现：`/home/Sighthesia/0_Files/Producing/Software/Quickshell/quickshell/Modules/DynamicIsland/`

## Confirmed Facts (from codebase)

- center dockzone 已有 `attached` / `floating` / `hidden` 状态机 + 动画驱动（`DockzoneSurfaceRoot.qml` + `DockzoneSurfaceModel.js`）
- `LauncherService` 已有 visible/query/mode 状态 + IPC toggle
- `ClipboardService` 已有 cliphist 集成（list/copy/paste/delete/wipe）
- 现有 `LauncherWindow` 是独立全屏 overlay（WlrLayer.Overlay + 暗背景 + 居中 600px 内容）
- `LauncherContent` 已有搜索框 + 模式切换（apps / clipboard / shortcuts）
- Motion.qml 提供统一弹簧/缓动参数
- 参考项目用 SpringAnimation + 布尔优先级链驱动尺寸变化，内容通过 opacity 切换

## Requirements

1. **触发**：左键点击 center dockzone 展开/收起 island。同时保留 IPC handler 供快捷键调用。
2. **展开动画**：center dockzone body 从当前尺寸弹性展开到 expanded 尺寸（参考 SpringAnimation 手感）。
3. **内容**：expanded 状态下显示搜索框 + 结果区域（复用现有 LauncherContent 的 apps/clipboard/shortcuts 模式逻辑）。
4. **收起**：点击 island 外部区域、按 Escape、或再次点击 island 收起。
5. **与现有 LauncherWindow 的关系**：MVP 阶段两者共存（island 版本作为主入口，全屏版本保留但不再是默认触发目标）。后续可移除全屏版本。

## Acceptance Criteria

- [ ] 点击 center dockzone 时 island 弹性展开到 expanded 尺寸
- [ ] expanded 状态显示搜索框，输入文字可过滤应用列表
- [ ] 输入 `>clip ` 前缀切换到剪贴板模式，显示 cliphist 历史
- [ ] 点击应用图标启动应用并收起 island
- [ ] 点击剪贴板条目复制并收起 island
- [ ] Escape 键或点击 island 外部收起
- [ ] IPC `qs ipc call island.toggle` 可触发展开/收起
- [ ] 收起动画与展开动画对称（弹性回弹）
- [ ] 展开时 bar 的 exclusiveZone 不变（island 覆盖在其他内容之上）

## Out of Scope (MVP)

- 控制中心快捷开关（WiFi、蓝牙、勿扰等）— 后续增量
- Tab 导航（Media、Calendar、Weather）— 后续增量
- 移除现有 LauncherWindow — 后续清理
- 快捷键列表模式的 island 适配 — 后续

## Design Decisions

- expanded 尺寸：固定宽度 480px，高度根据内容自适应（最大 ~420px）。动画目标明确，视觉稳定。
