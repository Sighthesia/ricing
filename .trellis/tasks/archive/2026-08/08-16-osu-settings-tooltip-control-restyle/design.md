# Design: Stable tooltips and purple settings controls

## Approach Decision

Three ownership strategies were considered:

1. Stable owner lock (selected): keep a valid active source against equal-priority requests; permit immediate higher-priority preemption. This directly removes request races without adding perceptible latency.
2. Hover debounce: delay every source switch. This masks rapid transitions but makes legitimate tooltips feel slow and does not define ownership.
3. Per-control tooltip surfaces: eliminate shared ownership. This duplicates measurement/viewport logic and reintroduces clipping inside Flickables.

The stable owner lock preserves the existing shared, unclipped tooltip surface and the previous geometry work with the smallest behavioral change.

## Component Boundaries

### `SettingsOverlayBridge.qml`

- Remains a transport and request registry, not a visual owner.
- Stores deterministic request order instead of treating the newest same-priority request as inherently best.
- Repeated `showTooltip()` for one source updates that request in place without changing its order.
- Exposes enough request information for each `LazerSettingsContent` instance to arbitrate only sources it owns.

### `LazerSettingsContent.qml`

- Keeps `activeTooltipSource` while it is valid for equal-priority arrivals.
- Immediately accepts a higher-priority owned request.
- On active-source dismissal/invalidation, chooses the highest-priority remaining owned request; ties use stable request order.
- Updating text for the current source does not reset `visible`, opacity, or geometry ownership.
- Existing source mapping, viewport intersection, placement, and lifecycle connections remain unchanged.

### `LazerSettingsRow.qml`

- Remains the single label/revert/search/layout owner.
- Reads a small presentation contract from the injected control:
  - standard controls keep label-above-control flow;
  - Toggle requests `inline` layout;
  - Slider requests `split` layout and exposes its formatted `displayText`.
- This avoids page-specific duplicate labels and applies the requested layout to every category consistently.

### `LazerSettingsToggle.qml`

- Keeps the existing `checked`, `toggled`, enabled, focus, and accessibility API.
- Paints only a `44x20` capsule. The checked state changes the capsule fill; focus/hover feedback stays restrained and token-driven.
- It no longer delegates to the shared hollow `LazerSettingsNub`.

### `LazerSettingsSlider.qml`

- Keeps value normalization, signals, keyboard, pointer, drag, animation, and reset logic.
- Replaces the `5px` track and `50x15` Nub with a `24px` trough, proportional purple fill, and `4x20` Thumb.
- Exports the Thumb through `nubItem` for compatibility with the tooltip source identity contract.
- The visual Slider fills the right column supplied by `LazerSettingsRow`; its text is rendered by the row's left column.

### Settings chrome

- `LazerTheme.qml` gains settings-specific purple/background/nav tokens. Global `osuPink` remains for unrelated surfaces.
- `LazerSettingsNavItem.qml` removes the inactive indicator state and consumes the inactive-nav token.
- `LazerSettingsContent.qml` removes top-right controls and right-aligns search icon; the clear action replaces it while text exists.
- `LazerSettingsPanel.qml` removes aliases and focus traversal assumptions tied to deleted header controls while retaining Esc/Back/collapse paths.

## Data and Interaction Flow

1. A row or Slider publishes a tooltip request with source identity and priority.
2. The bridge updates its registry without reordering an existing source.
3. Each Content owner filters requests by ancestor ownership.
4. If no source is active, the best owned request opens.
5. A higher priority replaces the active source; equal/lower priority waits while the active source remains valid.
6. Dismissal or invalidation selects the highest-priority, earliest stable remaining request.
7. Geometry follows the selected source through the existing viewport-local mapping.

## Compatibility

- No settings schema or service API changes.
- Existing page declarations continue injecting controls into `LazerSettingsRow`.
- Public control value signals remain unchanged.
- `nubItem` remains available, but points to the new Slider Thumb.
- Header close/collapse aliases are intentionally removed; tests and focus traversal move to the retained Sidebar Back/collapse and search/category controls.

## Risks and Mitigations

- Generic row layout regression: add composed tests for standard, inline Toggle, and split Slider modes at normal and compact widths.
- Focus-held tooltip can legitimately remain active while another equal-priority row is hovered: stable ownership is intentional; pointer-leave/focus-loss then hands off deterministically.
- Removing header close changes tab order: assert retained focus paths and Esc/Back close behavior.
- A `4px` Thumb has a small visual width: retain the full Slider trough as the pointer/drag target and use the Thumb only as visual and tooltip anchor.
- Theme replacement can leak outside Settings: use settings-specific tokens and test that global `osuPink` remains unchanged.

## Validation Strategy

- Logic/bridge tests: stable tie ordering, in-place source update, priority preemption, fallback, clear.
- Control tests: exact Toggle/Slider geometry, colors, Thumb identity, keyboard/pointer/reset behavior.
- Panel tests: row modes, no inactive indicator, header control removal, right search icon/placeholder, tooltip competition and fallback.
- Overlay tests: focus restoration, Esc/Back close, per-screen ownership, no tooltip residue.
- Runtime: all relevant QML suites, Python tests, `qmllint`, `git diff --check`, and `timeout 15s qs -p .` with WARN/ERROR review.

## Rollback Boundary

- Tooltip arbitration and visual restyle are separable file groups. If visual layout causes an unresolved regression, the stable arbitration can remain independently; no persisted data migration is involved.
