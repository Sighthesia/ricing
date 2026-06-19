# Just Demand Memory

## Decisions

## Facts

## Preferences

## Deferred Options

## Open Questions


- Task 2026-05-31-window-hint-task (window hint 一体延伸) completed with status 'done'.
  Verification summary: window hint 一体延伸完成：Slice1 抽 AttachedIslandSurface；Slice2a island 多态状态机+模式开关；Slice2b StageView 抽取+island 集成+launcher 降级。qs 全程无新增功能性告警。代码审查+qs 启动验证通过；交互手感待用户手测。

- Task 2026-06-15-make-center-spectrum-fill-dockzone-width-task (Make center spectrum fill dockzone width) completed with status 'done'.
  Verification summary: Applied minimal IslandBody.qml margin fix. timeout 5 qs -p . loaded config with no ERROR; remaining WARN lines are existing/environmental and not introduced by this center spectrum width change.


### From Task: 2026-06-18-redesign-island-overview-control-center-cards-task

## Durable Decisions

- The island overview now uses a control-center collage instead of a uniform module grid.
- The embedded launcher in overview follows a start-menu model: top-mounted search box, no default results, inline expansion only after query input.
- Settings search in compact launcher searches stable settings-entry labels/categories, not full-text settings content.
- Compact launcher search must keep a local query in overview mode so typing does not force a page switch to the full launcher.
- When a search result opens settings, pass a concrete setting label into settings search rather than only a broad category name, so the destination view always shows visible matches.

## Lessons From The Iteration

- Embedded search surfaces need two separate decisions: where the surface is mounted, and how it expands. Fixing only the expansion logic while leaving the mount at the wrong edge creates the illusion of a broken search direction.
- A compact search panel should own its own empty-state geometry. If the host card reserves full height while the query is empty, the UI reads as wasted space even when technically correct.
- Transparent list delegates inside a glass host can make the previous state visually bleed through. When search results should feel like a full state switch, give the results region its own backing surface.
- For top-edge shell surfaces, safe spacing must be derived from the shell's own top clearance (`expandedWidgetClearance`) rather than from an arbitrary small margin, or the new content will overlap the bar/dock region.
- Overview-height sizing should follow actual content height when possible. Reusing a global max expanded height for a shorter overview page causes persistent dead space and makes later animation tuning harder.

- Task 2026-06-18-redesign-island-overview-control-center-cards-task (Redesign island overview control center cards) completed with status 'done'.
  Verification summary: Island overview redesigned as control-center collage with top-mounted start-menu search and verified QML behavior

- Task 2026-06-19-finalize-island-control-center-redesign-commit-task (Finalize island control-center redesign commit) completed with status 'done'.
  Verification summary: Committed verified island control-center redesign and preserved durable experience notes

- Task 2026-06-19-remove-center-dockzone-resize-fade-task (Remove center dockzone resize fade) completed with status 'done'.
  Verification summary: Removed center dockzone resize fade-out; qs -p . loaded config. Existing warnings: qmlscanner module path and notification server registration.
