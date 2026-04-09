---
name: qml-workspace-overview-model
description: Use when workspace tabs must show per-workspace windows or icons, especially when overview content keeps collapsing to the active workspace.
---

# Workspace Overview Data Flow

Keep workspace overview rendering driven by one shared summary model, not by per-component lookup helpers.

## When to Use
- A workspace tab shows only the active workspace's windows.
- A delegate has to look up its own workspace content through a secondary function or local cache.
- Overview UI updates correctly for the active workspace but stale/non-active workspaces never refresh.

## Symptoms
- Every workspace pill looks like it is reading the same window list.
- Refactors that move data into a helper function still leave overview visually wrong.
- Debugging shows the raw compositor model is correct, but the widget binding path is not.

## Root Cause
- The widget owns its own derived map instead of consuming a shared summary model.
- The overview delegate binds through `parent` or a lookup helper instead of using a stable model payload.
- Active-workspace state leaks into overview rendering because the data source is too narrow.

## Correct Pattern
- Build a single summary list in a service singleton.
- Include `workspaceId`, `workspaceIndex`, `isActive`, and the per-workspace `icons`/window list in each summary row.
- Bind the overview repeater directly to that summary model.
- Pass each delegate its own summary object; do not recompute workspace membership inside the UI tree.

## Verification
- Switch between workspaces and confirm every tab keeps its own icon set.
- Check that non-active workspaces still render their windows after focus changes.
- Run `timeout 5 qs --path .` after changes.

## References
- `services/NiriService.qml`
- `services/WindowHintService.qml`
- `modules/bar/widgets/WorkspaceWidget.qml`
- `modules/bar/widgets/WorkspaceOverviewPill.qml`
