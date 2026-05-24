# Context

- User-approved goal: every blur-enabled background should keep blur coverage flush to the intended visible edge while border/outline remains clearly visible above the blur.
- Repeated simple-panel pattern found in these files:
  - `modules/settings/SettingsWindow.qml`
  - `modules/launcher/LauncherWindow.qml`
  - `modules/bar/BarContextMenu.qml`
  - `modules/bar/WidgetPickerWindow.qml`
  - `modules/osd/OsdWindow.qml`
  - `modules/notification/NotificationWindow.qml`
  - `modules/workspace-hint/WorkspaceHintCapsule.qml`
- In those files, the visible `Rectangle` owns both fill and border, while the blur source item is inset by `Services.SettingsService.blurRegionInset` (`2px`).
- Likely symptom chain: blur region stops short of the visible edge because the blur source is inset, leaving a non-blurred translucent ring near the border; that makes edge coverage look incomplete and reduces border legibility.
- Second implementation family uses custom blur geometry instead of a simple inset item:
  - `modules/bar/DockzoneSurfaceRoot.qml`
  - `modules/island/IslandBody.qml`
- Those two files already have unrelated uncommitted workspace changes and are also the impact scope of active task `2026-05-24-center-dockzone-ear-task`; handle them carefully and do not overwrite unrelated edits.
- Current worktree already shows modified `modules/bar/DockzoneSurfaceRoot.qml` and `modules/island/IslandBody.qml`; preserve existing changes.
- Keep visual tokens stable: do not intentionally change blur strength, opacity policy, corner radii, or overall visual language unless minimally required for the fix.
