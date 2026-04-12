---
name: qml-token-cleanup
description: Use when consolidating visual tokens, extracting repeated QML geometry into `Theme*` singletons, or cleaning hardcoded spacing, radius, widths, and panel dimensions across related UI families.
---

# QML Token Cleanup

Keep repeated visual rules owned by the right token singleton instead of scattering bare numbers across feature files.

## Use This For

- A feature family repeats `8`, `12`, `296`, `42x24`, `radius: 12`, or similar layout values across multiple files.
- A component family is borrowing unrelated tokens such as settings padding inside launcher or SuperIsland cards.
- A panel, popup, card, or settings control needs a stable visual contract that should survive future tuning.
- You need to decide whether a value should stay local, move into `Theme.qml`, or become a feature-level singleton.

## Token Ownership

### Global foundation: `config/Theme.qml`
- Keep shell-wide primitives here: `uiScale`, fonts, corner radius, animation families, bar base sizing.
- Do not keep growing `Theme.qml` with feature-local widths, panel heights, or control-specific geometry.

### Settings family: `config/ThemeSettings.qml`
- Owns settings rows, labels, fields, switches, segmented controls, picker dropdowns, sidebar layout, and preset-card geometry.
- Use for `modules/bar/settings/*` and `modules/bar/widgetsettings/*` before adding new local literals.

### Shared cards and floating shells: `config/ThemeCards.qml`
- Owns popup/panel/card padding, compact card widths, card radii, notification/history geometry, and SuperIsland card surfaces.
- Use for `modules/notifications/*`, floating panel shells, and SuperIsland cards/pages that should read as one surface family.

### Launcher family: `config/ThemeLauncher.qml`
- Owns launcher panel size, search-header layout, mode badge geometry, and result-row geometry.
- Use for `modules/launcher/*` and launcher-like content embedded inside SuperIsland.

## Extraction Rules

- If the same value appears in `3+` files with the same visual meaning, extract it.
- If the same value appears once and clearly expresses business meaning, keep it local.
- If a token name starts serving two unrelated surfaces, split ownership instead of widening the singleton.
- Prefer feature-level token files over stuffing everything into `Theme.qml`.
- Reuse existing `ThemeSettings`, `ThemeCards`, and `ThemeLauncher` before inventing a new singleton.

## Preferred Migration Order

1. Add the token to the correct singleton.
2. Migrate one component family at a time.
3. Validate with `timeout 5 qs --path .`.
4. Scan for leftover bare values in the touched area.

## High-Value Repetition Patterns

### Settings controls
- Row width/height, label width, input radius, field padding, switch geometry, segmented control geometry.
- Representative files:
- `modules/bar/settings/TextFieldSection.qml`
- `modules/bar/settings/ToggleSection.qml`
- `modules/bar/settings/SegmentedSection.qml`
- `modules/bar/settings/SliderSection.qml`

### Floating shells and cards
- Panel/card padding, compact card width, compact radius, popup edge margins, notification/history spacing.
- Representative files:
- `modules/notifications/NotificationPopupWindow.qml`
- `modules/notifications/NotificationCard.qml`
- `modules/bar/NotificationHistoryPanel.qml`
- `modules/bar/superisland/ExpandedControlCenterResourceCard.qml`

### Launcher geometry
- Overlay panel size, search-header spacing, result-row height, icon size, text spacing.
- Representative files:
- `modules/launcher/LauncherPanel.qml`
- `modules/launcher/LauncherSearchHeader.qml`
- `modules/launcher/LauncherResultsList.qml`

## Keep Local On Purpose

- Theme preset hex values inside `ThemePresetPicker` are content data, not visual debt.
- One-off business constraints such as a specific breakpoint, explicit media size, or bounded calendar dimensions can stay local if they do not repeat.

## Review Checklist

- Does the value belong to an existing visual family?
- Is the component consuming tokens from the right singleton?
- Did the change reduce bare geometry values in the touched files?
- Did validation still pass with `timeout 5 qs --path .`?
- Did the extraction avoid creating a generic token with unclear semantics?
