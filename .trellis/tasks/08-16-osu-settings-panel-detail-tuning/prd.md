# Refine osu settings panel details

## Goal

Make the osu-style settings panel read as one deliberate surface: search and
the current category title have a clear hierarchy, choice controls carry their
own compact labels, toggles remain visible when off, and navigation selection
uses only the requested accent indicator.

## Background

- The panel already uses a fixed 570px surface with separate Sidebar and
  Content owners. This task changes only the inner presentation.
- Content currently places its title above search, while Appearance,
  Notifications, and Bar pages render another title inside the scroll view.
- Choice controls currently expose only the selected value and use the generic
  40px control token. Row already injects controls and owns search/tooltip
  behavior, so the label contract can be extended without duplicating page
  markup.
- The prior tooltip ownership, viewport positioning, persistence, focus,
  dropdown, and per-screen ownership contracts remain authoritative.

## Requirements

### R1. Content search and category hierarchy

- Put the search field at the top of the right Content area.
- Use a borderless `#201E27` surface with radius `6`.
- Keep the empty-state placeholder exactly `输入以搜索` on the left and the
  search icon on the right. Preserve the existing clear action when text is
  present without overlapping the icon.
- Render the current category title exactly once below search, in white bold
  `18px` text with appropriate padding.
- Remove duplicate title delegates from Appearance, Notifications, and Bar.
- Do not remove the Sidebar collapse control, Sidebar Back action, or Escape
  close behavior. Remove only obsolete Content top chrome if present.

### R2. Embedded choice control

- `LazerSettingsChoice` must render at height `52px`, color `#25222E`, and
  radius `6`.
- The left side is a vertical label/value column: label `#8A8795`, `11px`;
  current value white, bold, `14px`.
- The down arrow is vertically centered on the right and colored `#8A8795`.
- The control receives its property label from the existing Row label through
  a small presentation contract; pages must not duplicate labels manually.
- Preserve choice model selection, keyboard interaction, dropdown bridge
  identity, focus styling, disabled behavior, and accessibility.

### R3. Toggle off-state

- An unchecked `LazerSettingsToggle` uses visible background `#322E3F`.
- Checked state remains `#765BFF`; preserve capsule geometry, transitions,
  keyboard activation, focus, disabled behavior, and accessibility.

### R4. Navigation selection

- Remove the selected navigation item's outer dark-purple capsule/background.
- Show only a left indicator of `4x24`, radius `2`, color `#765BFF` when
  selected.
- Selected icon and text are `#FFFFFF`; unselected icon and text are
  `#8A8795`. Unselected items have no indicator.
- Preserve hover, focus, collapse, and stagger behavior.

## Out Of Scope

- Settings models, defaults, persistence, save timing, or reset semantics.
- Tooltip arbitration, measurement, viewport ownership, or source geometry.
- Fixed panel/sidebar geometry and layer-shell behavior.
- Unrelated shell colors, global `osuPink`, or controls not named above.
- Removing Sidebar collapse/Back controls.

## Acceptance Criteria

- [ ] Content search is the first right-panel control, has no white border,
      uses `#201E27`/radius `6`, and keeps placeholder/icon/clear behavior.
- [ ] The current category title appears once below search as white bold `18px`
      text; Appearance, Notifications, and Bar no longer render duplicate
      page titles.
- [ ] Choice controls are `52px` high, `#25222E`, radius `6`, and show the
      requested label/value column and right-side arrow styling.
- [ ] Choice labels come from Row contract injection; no settings page adds a
      duplicate label solely for the control.
- [ ] Unchecked toggles visibly use `#322E3F`; checked toggles remain purple.
- [ ] Selected navigation has no outer capsule and only a `4x24`, radius `2`
      purple indicator; selected text/icon are white and inactive are `#8A8795`.
- [ ] Sidebar collapse/Back, Escape, focus, dropdown, persistence, tooltip,
      fixed-surface, and per-screen ownership behavior remain intact.
- [ ] Relevant QML tests, Python tests, `qmllint`, `git diff --check`, and
      `timeout 15s qs -p .` pass; only a confirmed pre-existing D-Bus ownership
      warning may remain.

## Technical Notes

- Add settings-only tokens such as `settingsSearchSurface`, `settingsToggleOff`,
  `settingsChoiceHeight`, and `settingsChoiceRadius`; do not alter global
  `osuPink`.
- Prefer a `fieldLabel` plus `rowPresentation`/label-ownership contract over
  page-specific duplicated labels. Row remains the owner of search and tooltip
  requests.
- All visible color, radius, opacity, position, and geometry changes require
  coherent QML transitions unless technically hidden or already covered by an
  existing transition.
