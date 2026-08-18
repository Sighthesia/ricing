# Technical Design

## Boundary

调查并修复 `modules/lazerbar` 设置面板前端的 pointer hit-test ownership。优先修改共同布局/viewport/overlay 层，而不是为每个设置控件增加独立补丁。

## Evidence And Diagnosis Path

1. Use the existing `debugSnapshot()` path in `LazerSettingsOverlay`, `LazerSettingsPanel`, and `LazerSettingsContent` to compare row/control rectangles, visibility, opacity, z-order, and hover state while moving the pointer over affected and unaffected regions.
2. Compare the actual scene rectangles of the affected controls with their owning row and the `viewport` rectangle. The symptom's dependence on row order and control height is expected to distinguish clipping/coordinate errors from control-local handler errors.
3. Inspect pointer-owning layers in stacking order: mounted category pages, `viewport`, `scrollShadow`, `emptyState`, tooltip, dropdown catcher, and the layer-shell mask. Any transparent layer that covers the reported coordinates must either be non-interactive or be restricted to its intended visible state.
4. Reproduce with the existing control contract tests and add a focused panel/content fixture if the current tests do not instantiate the full viewport chain.

## Preferred Fix Shape

- Keep the existing `HoverHandler` and `TapHandler` contract on controls.
- Make the owner of the visible interaction rectangle explicit in the shared row/content layout so control geometry, visual geometry, and pointer geometry share the same coordinate domain.
- Ensure decorative layers use `enabled: false` or are removed from the scene when hidden; ensure the dropdown outside-click catcher exists only while the menu is open.
- Preserve the fixed outer settings surface and the existing clipped viewport. Do not solve the issue by enlarging the layer-shell window or by making the whole screen interactive.

## Compatibility

- QML singleton/service contracts remain unchanged.
- Existing `SettingsOverlayBridge` source identity and tooltip priority semantics remain unchanged.
- Existing category page scroll positions remain mounted and persistent across category changes.

## Verification And Rollback

- Run `qs -p tests/qml/tst_lazer_settings_controls.qml` and `qs -p tests/qml/tst_lazer_settings_panel.qml` after every QML edit.
- Run any additional focused test created for the full content/viewport chain.
- Treat any QML WARN/ERROR as a failed validation, especially binding loops, invalid anchors, handler conflicts, or focus warnings.
- Rollback is limited to the touched frontend QML/test files; no persisted data migration is involved.
