# Settings Sidebar Action Buttons Design

## Goal

Align the settings sidebar's back and collapse actions with the established
osu!lazer sharp visual language while preserving full-width keyboard and pointer
activation areas.

## Visual Structure

- Keep each action's outer `Item` full width so the entire sidebar row remains
  clickable and keyboard accessible.
- Add a separate, narrow visual surface inside the full-width action item.
- The visual surface is approximately `40px` wide and follows the same left
  alignment as the settings category icons while expanded.
- The visual surface uses a rectangular sharp form; do not add a large rounded
  sidebar-wide background.
- Action icons use the same `20px` visual size as category icons.
- During collapse, icon and visual surface move toward the contracted sidebar's
  center using the shared `expansionProgress` value.

## Interaction States

- Hover feedback is controlled by the action's `HoverHandler.hovered` state.
- Keyboard focus remains available through `activeFocusOnTab` and
  `forceActiveFocus()`.
- `activeFocus` must not create a persistent visual background or white focus
  frame on the collapse or back action.
- Press feedback may continue using `MotionTokens.pressScale`.
- Back and collapse actions use the same hover, press, focus, and reduced-motion
  rules.

## Transition Contract

- The action visual surface and icon follow the sidebar's `expansionProgress`
  from the first frame of collapse/expand.
- Do not add a second width animation to the action item when the sidebar owner
  already animates its width.
- Reduced-motion mode switches the position directly without an independent
  action animation.
- The full-width hit area remains stable while only the visual surface and icon
  change position.

## Verification

- Expanded state: both icons align with category icons and the visual surfaces do
  not fill the entire sidebar.
- Contracted state: both icons are centered in the contracted sidebar.
- Clicking collapse does not leave a persistent background highlight or white
  focus border.
- Hover still changes the action visual surface and icon color.
- Keyboard activation still works for both actions.
- Run `qmllint`, `pytest -q`, and `qs -p .` after the QML implementation.
