# 技术设计：设置面板 Row 焦点命中修复

## Boundary

本任务只修复设置面板的 Row hover/focus 视觉和输入控件的焦点 ownership，不恢复 tooltip，不改变 Row 布局、PanelWindow mask、设置服务或持久化。

主要修改边界：

- `LazerSettingsChoice.qml`: header 点击时先获取 Choice focus，再打开菜单。
- `LazerSettingsTextField.qml`: 明确 TextInput 是鼠标编辑焦点 owner，移除可能与其竞争的外层点击路径，或将外层点击限制为不覆盖编辑器的区域。
- `LazerSettingsRow.qml`: 保持 Row-level HoverHandler 仅观察 hover；保留 `rowHighlighted` 与 control activeFocus 的组合，不把 Row 空白点击转发给控件。
- `tests/qml/tst_lazer_settings_controls.qml`: 增加/修正 TextField、Choice 的鼠标 focus ring 和空白区域不聚焦断言。

## Interaction Contract

```text
pointer enters Row blank/label
  -> rowHover.hovered = true
  -> row card hover border visible
  -> no control focus change

pointer clicks TextField editor area
  -> TextInput receives pointer ownership
  -> editor.activeFocus = true
  -> field focus ring visible

pointer clicks Choice header
  -> Choice receives active focus
  -> Choice opens dropdown menu
  -> header focus ring visible
```

The Row observer remains `blocking: false`. It must never become an input owner. The reset button remains an independent button region.

## Focus Ownership

### Choice

`TapHandler.onTapped` should call `root.forceActiveFocus()` before `root.openMenu()`. This fixes the direct missing focus transition while preserving the existing keyboard path. `openMenu()` remains idempotent and continues routing the menu through `SettingsOverlayBridge`.

### TextField

The existing editor already owns the actual text interaction. The fix should verify whether the wrapper `TapHandler` is competing with `TextInput`; if so, remove the wrapper handler and rely on `TextInput`'s native pointer focus. If a wrapper handler is needed for blank padding inside the field surface, it must only focus the editor within the TextField bounds and must not be introduced on Row or `contentHost`.

The implementation must preserve `commit()` on focus loss and the external text synchronization contract.

### Row

Do not add a Row `TapHandler` or `forceActiveFocus()` call. Row hover remains observational. `rowHighlighted` may continue to show the card border while a control owns active focus; the visible focus ring remains owned by the control itself.

## Regression Seam

The correct seam is `tst_lazer_settings_controls.qml`, where reusable controls and Rows are mounted together and pointer helpers can distinguish:

- Row blank click
- TextField control click
- Choice header click
- keyboard activation

The existing QML test runner currently fails before assertions with `qrc:/qs-blackhole: No such file or directory`; the tests will still be updated as the intended regression contract and static/runtime checks will be run where possible.

## Compatibility and Rollback

- No public service/API compatibility changes.
- No tooltip compatibility layer is reintroduced.
- If TextField pointer behavior regresses after removing its wrapper handler, restore a narrowly-scoped handler only inside the field component and add a test proving it does not cover Row.
- If Choice menu focus changes keyboard dismissal behavior, preserve the new focus acquisition but adjust menu focus return in `onMenuClosed()` rather than reverting Row ownership.
