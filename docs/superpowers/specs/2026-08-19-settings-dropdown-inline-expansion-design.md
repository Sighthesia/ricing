---
title: Inline Settings Dropdown Expansion
date: 2026-08-19
status: approved-design
---

# Inline Settings Dropdown Expansion

## Goal

Replace the settings Choice dropdown overlay with an inline menu that belongs
to the current settings Row. Opening the menu must animate the Row taller and
push following settings downward. The focus ring must cover the complete
expanded Row instead of being covered by the dropdown.

## Confirmed Interaction

- The menu always opens downward.
- The Row grows through an animated height change.
- Following settings move down with the Row layout.
- The focus ring covers the complete expanded Row, including the title and all
  options.
- Selecting an option updates the value and immediately closes the menu.
- Clicking the title again, clicking outside the Row, or pressing `Escape`
  closes the menu without changing the current value.
- If the menu reaches the bottom of the settings viewport, the outer settings
  content scrolls to reveal it; the menu does not open upward.

## Architecture

### `LazerSettingsChoice`

Convert the Choice from a title plus external overlay into a title plus an
embedded option list.

- Keep `menuOpen` as the single expansion state.
- Keep the existing model, current value, `valueSelected`, keyboard entry,
  and accessibility contract where possible.
- Set the root `implicitHeight` to the title height when closed and to title
  height plus spacing plus option-list height when open.
- Place the option list directly below the title surface in a vertical layout.
- Make options visible and hit-testable only while `menuOpen` and the control is
  effectively enabled.
- Remove the runtime dependency on `SettingsOverlayBridge.showDropdown(root)`
  and `hideDropdown(root)` for this control.
- Keep options bounded by the existing dropdown maximum height. The outer
  settings content remains responsible for scrolling when the expanded Row
  extends beyond the viewport.

### `LazerSettingsRow`

Keep the Row as the sole owner of the card geometry and focus ring.

- Derive the Choice row height from the control's actual expanded height.
- Use that height in `cardContentHeight` and the Row's `implicitHeight`.
- Animate the Row height using existing `MotionTokens` rather than creating a
  separate timing system.
- Keep `cardSurface` and `cardHighlight` anchored to the complete Row so the
  focus ring grows with the menu and remains above the embedded visuals while
  remaining input-transparent.
- Preserve the existing reset zone and control width budgets.
- Do not expand the Row background's input ownership into the Choice option
  handling; the row hover observer remains non-blocking.

### `LazerSettingsContent`

Keep the current page layout structure. Ensure the content layout and
`Flickable.contentHeight` react to the Row's changing implicit/actual height so
following rows move during expansion and the bottom of the menu remains
scrollable.

## State and Event Flow

### Open

1. A pointer click on the title, or `Enter`, `Space`, or `Alt+Down` while the
   Choice has focus, requests `openMenu()`.
2. Choice sets `menuOpen = true` and exposes the embedded option list.
3. Choice reports the expanded height.
4. Row recalculates its content and implicit height.
5. The Row height and subsequent layout positions animate through the existing
   motion tokens.
6. The focus ring continues to fill the full Row throughout the transition.

### Select

1. A pointer click or keyboard activation selects a valid model value.
2. Choice emits `valueSelected(value)` through the existing save path.
3. Choice updates the displayed value and sets `menuOpen = false` immediately.
4. Row and the following layout contract through the same height animation.

### Close Without Selection

- Clicking the title again toggles the menu closed.
- Pressing `Escape` closes the menu and preserves the current value.
- Clicking outside the current Row closes the menu and preserves the current
  value.
- Closing must not leave focus on an invisible option.
- Switching category, closing the settings panel, or losing effective enabled
  state must force the menu closed.

## Input and Layering Rules

- The embedded option list is the only input owner for option coordinates while
  open.
- The Row's background hover observer remains passive/non-blocking.
- The focus ring remains visual-only and does not accept pointer input.
- No fullscreen or cross-Row dropdown input region remains.
- Inactive settings pages remain `visible: false` so they cannot participate in
  hit testing while their objects and scroll state remain mounted.

## Animation Rules

- Animate the Row/Choice height and let normal layout move following rows.
- Use the project's existing `MotionTokens` duration and easing.
- Use one closed height and one expanded height as the authoritative states.
- Support interruption and reversal without leaving a stale reserved height.
- With reduced motion enabled, apply the final height immediately while
  preserving the same layout and input result.

## Edge Cases

- Empty model: opening is a no-op and the Row stays at its closed height.
- Long model: cap the embedded list at the existing dropdown maximum height;
  use list scrolling only if already supported by the existing control contract.
- Menu opened near the content bottom: keep the downward layout and let the
  outer settings Flickable scroll to the expanded content.
- Disabled Choice or hidden page: close the menu and expose no option hit area.
- Rapid open/close: the current target height must win and the Row must settle
  at exactly the corresponding closed or expanded height.

## Verification

### QML Tests

Extend the existing settings panel/control tests to verify:

- Choice starts at closed height with no visible option list.
- Opening sets `menuOpen`, increases Choice/Row height, and places options
  below the title.
- The following Row moves down while the menu is open.
- The focus ring covers the complete expanded Row.
- Selecting updates the value, closes the menu, and restores the original Row
  height and following-row position.
- `Escape`, title toggle, and outside click close without changing the value.
- Inactive pages are not visible or hit-testable, while their scroll position is
  preserved.
- Reduced-motion expansion and collapse produce the correct final geometry.

### Static and Runtime Checks

- Run `qmllint` on changed QML files.
- Run `git diff --check`.
- Run `python3 -m pytest -q`.
- Run the relevant QML test file through the available Quickshell test path.
- Run a persistent-shell interaction check and inspect logs for new WARN/ERROR
  output.

## Acceptance Criteria

1. The dropdown no longer renders in a separate overlay above the Row.
2. Opening the dropdown visibly and smoothly increases the current Row height.
3. Every following setting is pushed downward by the expanded Row.
4. The focus ring surrounds the title and all visible options without being
   covered by the menu.
5. Selection, Escape, title toggle, outside click, category switching, and
   panel closing have the specified behavior.
6. Existing reset controls, Choice width, keyboard access, page switching,
   scroll persistence, and unrelated setting controls do not regress.
7. All available static, unit, QML, and runtime checks pass without new
   warnings or errors.
