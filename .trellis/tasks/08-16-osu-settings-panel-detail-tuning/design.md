# Design: Refine osu settings panel details

## Boundaries

Keep the existing fixed layer-shell surface and split ownership:

- `LazerSettingsPanel` continues to coordinate Sidebar and Content.
- `LazerSettingsSidebar` retains its collapse button, navigation, and bottom
  Back action.
- `LazerSettingsContent` owns the search surface, category title, page viewport,
  dropdown layer, and tooltip layer.
- Category pages remain persistent scrollable content but no longer own their
  category heading.

Only scene-graph children animate. No panel window or fixed surface geometry is
resized per frame.

## Content Layout

Reorder Content chrome to:

1. Search surface at the top, with `#201E27`, radius `6`, no white border,
   left input/placeholder, and right search or clear icon.
2. Category title below search, owned by Content, with white bold `18px` text
   and stable padding.
3. Clipped page viewport below the title, followed by the existing footer.

The existing page title delegates in `LazerSettingsAppearance.qml`,
`LazerSettingsNotifications.qml`, and `LazerSettingsBar.qml` are removed. This
prevents duplicate headings while keeping page rows, scroll state, search
matching, and persistence unchanged.

## Choice Contract

Extend `LazerSettingsChoice` with a `fieldLabel` property and a presentation
marker that tells `LazerSettingsRow` the control owns its label. Row binds its
existing `labelText` to `fieldLabel` and hides the external label only for this
choice presentation. Row continues to own the row description tooltip and
search matching.

The choice header remains the existing dropdown/menu owner and keeps its public
`headerItem`, `openMenu`, `closeMenu`, `menuOpen`, and selected-value behavior.
Its visual surface becomes a `52px` high `#25222E` rectangle with radius `6`.
The label/value column uses 11px muted label text and 14px bold white value
text. The existing arrow asset remains right-aligned and is colorized to
`#8A8795`. Focus/hover state is expressed through the existing transition
chain without changing menu ownership.

## Toggle And Navigation Tokens

Add settings-only theme tokens for search surface, toggle off-state, and choice
dimensions. `LazerSettingsToggle` uses the off token when unchecked and the
existing settings accent when checked. Global `osuPink` remains untouched.

Remove the selected nav background fill. The indicator owns the selected state:
it is `4x24`, radius `2`, and settings accent. Selected icon/text use white;
inactive icon/text use `#8A8795` and the indicator collapses to zero opacity and
height. Existing hover/focus and stagger transitions remain active.

## Compatibility And Rollback

- Preserve all existing choice, toggle, row, tooltip, dropdown, focus, and
  settings persistence APIs unless the new label contract is additive.
- Keep `nubItem` and bridge source identities unchanged for controls that expose
  them.
- If a visual test fails, revert only the affected token or presentation layer;
  do not bypass the fixed-surface or owner contracts.
- Rollback is limited to the task commit because settings data and persistence
  are not migrated.

## Verification Strategy

- Logic tests cover exact new theme tokens and unchanged geometry constants.
- Control tests cover Choice dimensions/label/value/arrow styling, Toggle off
  state, and Row label injection without duplicate labels.
- Page/panel tests cover one title below search, removal of page title delegates,
  navigation indicator geometry/colors, and preserved Sidebar/Back/Escape.
- Overlay and smoke tests remain green to detect lifecycle or ownership drift.
