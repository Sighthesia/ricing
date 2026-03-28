# Task: tray-shell-cascading-context-menu-fix

## Overview

Fix the system tray cascading context menu so right-clicking a tray icon shows the
actual menu items instead of an empty shell that only displays the icon title.

## Problem

- Right-clicking some tray icons opens a menu shell with only the title visible.
- The current implementation delegates menu display to Quickshell native platform
  menu rendering through `SystemTrayItem.display(...)`.
- Upstream DBusMenu handling treats the structural root node as a visible menu,
  which breaks some cascading tray menus.

## Requirements

- Replace the tray icon menu opening path with a local QML-rendered menu flow.
- Render the menu from `StatusNotifierItem.menu` via `QsMenuOpener.children`.
- Skip rendering the DBusMenu root node title as a visible first row.
- Support nested submenu expansion for cascading menus.
- Support separators, icons, enabled state, and checkbox/radio check state.
- Preserve existing tray icon behaviors for primary click, middle click, and wheel.
- Keep the existing bar context menu behavior unchanged.

## Acceptance Criteria

- Right-click on a tray icon with a menu shows real menu items.
- `onlyMenu` tray icons open the same menu on primary click.
- Nested submenu items can be opened and triggered.
- Clicking outside the tray menu closes it.
- Pressing `Escape` closes the tray menu.
- `timeout 5 qs --path .` completes without new QML load errors.
