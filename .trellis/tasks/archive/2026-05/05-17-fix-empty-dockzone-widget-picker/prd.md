# 修复空 dockzone 右键 widget picker

## Goal

修复 bar 中空 dockzone 在删除全部组件后无法通过右键进入 widget picker 的问题，保证用户仍可从空 section 重新添加 widget，而不需要先依赖其他 section 或重置布局。

## Confirmed Facts

- `modules/bar/BarContent.qml` 已有整条 bar 级别的右键兜底菜单入口，会调用 `Services.BarLayoutService.openContextMenu(mouse.x, "", "")`。
- `modules/bar/BarSection.qml` 会在 section 没有内容时把 `surfaceState` 置为 `"hidden"`，此时对应 `DockzoneSurfaceRoot` 不再提供可见/可交互的局部表面。
- `services/BarLayoutService.qml` 已维护 `contextMenuSection`，说明当前菜单逻辑已经区分右键发生在哪个 section。
- 当前问题不是菜单基础能力缺失，而是空 dockzone 场景下缺少正确的右键命中入口或 section 定位，导致无法从空 section 打开期望的 widget picker。

## Requirements

- 删除某个 dockzone 内全部 widget 后，该空 dockzone 仍然可以被右键命中。
- 在空 dockzone 上右键后，菜单中应能继续显示并进入 widget picker，而不是退化成仅对整条 bar 的通用空白区菜单。
- 修复应复用现有 bar context menu 与 section 判断能力，避免引入新的并行菜单机制。
- 变更范围尽量限制在 `modules/bar/` 和现有 `BarLayoutService` 交互边界内，不重构 layout model 或持久化结构。

## Acceptance Criteria

- [ ] left、center、right 任一 dockzone 被清空后，用户仍可在该空区域右键打开与该 section 对应的菜单入口。
- [ ] 该菜单可继续显示 widget picker，并允许向目标空 dockzone 添加 widget。
- [ ] 现有 widget 上的右键菜单行为保持不变，仍可执行 widget 级操作。
- [ ] 非空 section 和普通 bar 空白区的右键菜单行为不出现回归。

## Out Of Scope

- 不调整 widget picker 的视觉设计或信息架构。
- 不修改 bar 三段布局模型、拖拽排序规则或布局持久化格式。
- 不处理与本问题无关的其他 context menu 交互问题。

## Open Questions

- 无。当前需求和修复边界已足够进入实现。

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
