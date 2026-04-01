---
name: qml-context-menu
description: Use when creating, refactoring, or visually aligning right-click menus, tray menus, or submenu popups in DymicShell. Covers the shared bar-style context menu shell, row primitives, sizing, and stagger behavior.
---

# QML Context Menu Patterns

Use the bar context menu as the visual source of truth for local QML-rendered menus.

## Source Of Truth
- Popup shell: `modules/bar/ContextMenuPopup.qml`
- Surface styling: `modules/bar/ContextMenuSurface.qml`
- Interactive row: `modules/bar/ContextMenuAction.qml`
- Divider: `modules/bar/ContextMenuDivider.qml`
- Bar reference implementation: `modules/bar/BarContextMenu.qml`
- Tray reference implementation: `modules/bar/tray/TrayContextMenu.qml`
- Tray DBus row renderer: `modules/bar/tray/TrayContextMenuItem.qml`

## Reuse Rules
- Prefer extending `ContextMenuPopup.qml` over creating a fresh `PopupWindow`.
- Prefer composing rows with `ContextMenuAction.qml` instead of inline hover, ripple, and `MouseArea` logic.
- Prefer `ContextMenuDivider.qml` for separators instead of ad-hoc `Rectangle` lines.
- Keep tray-specific menu data flow in tray files; only extract shared visual structure into `modules/bar/`.
- If two menus should look the same, sizes and animation timing must come from the same component or token, not duplicated literals.

## Visual Baseline
- Menu width: match `BarContextMenu.qml` unless the feature has a clear reason to diverge.
- Menu row height: use `Theme.barHeight - Theme.barPadding` for standard menu actions.
- Surface radius/border/background: inherit from `ContextMenuSurface.qml`.
- Row spacing and horizontal rhythm: use `Theme.widgetPadding`, `Theme.barWidget.iconSpacing`, `Theme.fontSizeBody`, and `Theme.barWidget.primaryIconSize`.
- Submenus should inherit the same shell and row metrics as the root menu.

## Stagger Pattern
- For bar-style menu entry animation, wrap delegates or blocks with `modules/bar/StaggerItem.qml`.
- Orchestrate enter/exit with `modules/bar/StaggerOrchestrator.qml`.
- Use level-1 stagger for ordinary menu items unless there is a strong visual hierarchy.
- Re-register stagger items whenever a menu model changes after opening.

## Alignment Rules
- Keep a stable leading column for optional affordances like checkboxes, radios, or icons.
- Do not remove the layout slot for unchecked items if checked items need text alignment with normal items.
- If a row supports icons or check states conditionally, reserve the column width and toggle only the inner visual element.
- Validate alignment across plain items, icon items, check items, radio items, and submenu items.

## Tray Menu Rules
- Render tray menus from `QsMenuOpener.children`.
- Skip the DBus root wrapper row; render actual entries only.
- Preserve tray-only behavior such as submenu expansion, `triggered()`, `onlyMenu`, and close-tree behavior.
- Do not route tray menus back through native platform menu rendering when the goal is visual consistency.

## Validation
- Run `timeout 5 qs --path .` after modifying any menu QML.
- Manually verify: bar menu, tray root menu, tray submenu, separators, disabled items, checkbox/radio items, and click-outside close behavior.

## Common Mistakes
- Copying the bar menu visuals into tray code instead of reusing the shared shell.
- Letting tray item `implicitHeight` grow from label metrics and drift away from bar row height.
- Hiding the entire checkbox column and accidentally shifting checked-item text.
- Reintroducing duplicated enter/exit animation ratios in multiple menu files.
