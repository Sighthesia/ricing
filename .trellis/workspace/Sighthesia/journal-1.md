# Journal - Sighthesia (Part 1)

> AI development session journal
> Started: 2026-05-09

---



## Session 1: Add minimal Quickshell top bar shell

**Date**: 2026-05-10
**Task**: Add minimal Quickshell top bar shell
**Branch**: `afloat`

### Summary

Created a minimal runnable Quickshell shell.qml with a static top bar for each screen, verified loading and QML lint, and archived the task.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `48c89a6` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 2: Port screen rounded corners

**Date**: 2026-05-10
**Task**: Port screen rounded corners
**Branch**: `afloat`

### Summary

Completed the QML background comment cleanup and added the reusable comment-before-declarations skill, then archived the task.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `04db179` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 3: Add dynamic island center dock zone

**Date**: 2026-05-10
**Task**: Add dynamic island center dock zone
**Branch**: `afloat`

### Summary

Added a reusable attached-island shape, implemented the center top dock zone with inner quarter-circle ears, updated Glass Liquid design guidance, and recorded Canvas path porting rules.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `0af81b5` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 4: Port bar layout system MVP

**Date**: 2026-05-10
**Task**: Port bar layout system MVP
**Branch**: `afloat`

### Summary

Ported the minimum Quickshell bar layout kernel into afloat, moved the shell root to a reusable bar module, and documented the resulting module/service structure in frontend specs.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `2cc2788` | (see git log) |
| `25e1233` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 5: Configurable bar layout data layer

**Date**: 2026-05-10
**Task**: Configurable bar layout data layer
**Branch**: `afloat`

### Summary

Upgraded the Quickshell bar layout from a hard-coded MVP model into a configurable persisted data layer with stable widget identities, startup restore, and frontend state-management conventions for shared shell services.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `be93c68` | (see git log) |
| `1fe6456` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 6: Minimal bar widget picker

**Date**: 2026-05-10
**Task**: Minimal bar widget picker
**Branch**: `afloat`

### Summary

Added a minimal picker flow for the bar system with a temporary fixed entry point, a thin panel UI, and service-backed layout updates that stay compatible with the persisted bar data model.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `431d1df` | (see git log) |
| `c65bfed` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 7: Refine bar dockzone ears and overlay windows

**Date**: 2026-05-14
**Task**: Refine bar dockzone ears and overlay windows
**Branch**: `afloat`

### Summary

Adjusted bar dockzone geometry, moved bottom ears into dedicated overlay windows, and wired the widget picker into the bar layout flow.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `689ed33` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 8: Update repository AGENTS.md

**Date**: 2026-05-14
**Task**: Update repository AGENTS.md
**Branch**: `afloat`

### Summary

Updated the root AGENTS.md with compact, verified guidance for the Quickshell app structure and the local Trellis/OpenCode workflow layer.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `4f29362` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 9: Bar Widget Layout System

**Date**: 2026-05-15
**Task**: Bar Widget Layout System
**Branch**: `afloat`

### Summary

Implemented full bar widget layout system: settingsMode toggle, drag-and-drop reorder within/across sections, widget removal, DragOverlay insertion indicator, enhanced WidgetPickerWindow with search, right-click context menu (overlay PanelWindow, per-section Add Widget), Clock widget, and extensible widget registry.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `65a853a` | (see git log) |
| `578be16` | (see git log) |
| `76a3e6f` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 10: Fix empty dockzone widget picker

**Date**: 2026-05-17
**Task**: Fix empty dockzone widget picker
**Branch**: `main`

### Summary

Restored per-section widget picker entry and empty dockzone right-click hit target so cleared sections can reopen the picker and add widgets back.

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `0b3658d` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete


## Session 11: Mod键工作区/窗口提示OSD弹窗

**Date**: 2026-05-18
**Task**: Mod键工作区/窗口提示OSD弹窗
**Branch**: `main`

### Summary

实现 mod 键按住时的工作区/窗口提示 OSD 弹窗。移植 window_hint_trigger.py 检测 Super 键；增强 NiriService 添加 workspaces 模型；新建 WindowHintTriggerService 和 WindowHintService；实现双胶囊 OSD UI，从 center dockzone 中心以零宽度展开，stagger 时序入场，反向收缩退场。修复多轮动画问题：起始位置对齐、退场内容保留、clip 行为、hintVisible 绑定。

### Main Changes

(Add details)

### Git Commits

| Hash | Message |
|------|---------|
| `8f25648` | (see git log) |
| `2903743` | (see git log) |
| `fee5614` | (see git log) |
| `55ea926` | (see git log) |
| `c005413` | (see git log) |
| `40c5ed8` | (see git log) |
| `cab8179` | (see git log) |
| `12ab23a` | (see git log) |
| `15b3468` | (see git log) |
| `7652f6f` | (see git log) |
| `edf00d4` | (see git log) |
| `6ba5483` | (see git log) |

### Testing

- [OK] (Add test results)

### Status

[OK] **Completed**

### Next Steps

- None - task complete
