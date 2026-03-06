# Unified Stagger Animation Across Panels — Design

**Date**: 2026-03-07
**Status**: Approved
**Scope**: SettingsPanel, WidgetPicker, BarContextMenu, Launcher, WidgetSettingsPanel

## 1. Goals

1. Provide a single, consistent stagger experience across settings panel, widget library, context menu, launcher, and widget settings panel.
2. Ensure every independent visible content unit participates in stagger enter/exit.
3. Ensure viewport-entered items (scroll/filter) also animate from lower Y to upper Y.
4. Eliminate scattered timing constants by relying on existing animation tokens.

## 2. Unified Architecture

### 2.1 Stagger Orchestrator

Introduce a shared orchestrator component (`StaggerOrchestrator`) that centralizes stagger sequencing.

Responsibilities:
- Register content nodes with ordering metadata.
- Trigger enter/exit for a named group.
- Compute delay from shared settings tokens.

Proposed API:
- `register(nodeId, group, order, level, kind)`
- `enter(group)`
- `exit(group)`

Delay rule:
- `delay = base(level) + order * step(level)`
- For long lists/grids: `order = index % cycle` to keep latency bounded.

### 2.2 Lifecycle Integration

Panel-level triggers stay unified:
- open: `panelOpening -> orchestrator.enter(pageGroup)`
- close: `panelClosing -> orchestrator.exit(pageGroup)`

List/Grid viewport integration:
- delegate creation or viewport-entry triggers `enter(itemGroup)`.

### 2.3 Token Source

Animation values come from:
- `SettingsService.data.animation.*`
- `Theme.anim.*`

Any unavoidable literal must be marked:
- `// FIXME: [description]`

## 3. Per-Page Rules

### 3.1 Settings Panel (`AboutPage` included)

Target file: `modules/bar/settings/AboutPage.qml`

Independent stagger nodes:
- header block
- reset button
- reset hint
- import/export row
- import/export hint

Add page hooks:
- `runEnterAnimation()`
- `runExitAnimation()`

Parent settings content calls hooks together with existing pages.

### 3.2 Widget Library (`WidgetPickerWindow`)

Target file: `modules/bar/WidgetPickerWindow.qml`

Current structural stagger (title/search/grid container) remains.

Add per-card stagger in `GridView` delegate:
- each card is an independent stagger node
- order by visual position (`row * columns + column`)
- viewport-entered cards animate from lower Y to upper Y

Filter refresh behavior:
- removed cards perform short exit
- new cards perform enter

### 3.3 Right-Click Menu (`BarContextMenu`)

Target file: `modules/bar/BarContextMenu.qml`

Keep existing full-item stagger coverage.
Migrate trigger wiring to orchestrator for consistency.
Preserve synchronized exit (`exitDelay = 0`) for snap-close feel.

### 3.4 Launcher (`LauncherCore`)

Target file: `modules/launcher/LauncherCore.qml`

Keep result-item stagger and viewport enter behavior.

Extend coverage:
- include search row and divider as stagger nodes
- add query refresh two-stage transition:
  1. old results short exit
  2. model swap
  3. new results enter

Use bounded delay cycle for long lists.

### 3.5 Widget Settings Panel

Target file: `modules/bar/WidgetSettingsPanel.qml`

Unify lifecycle semantics with `AnimatedPanelBase` pattern (or direct reuse) to avoid diverging state machines.

Ensure all independent blocks are in orchestrated stagger:
- header
- appearance group
- functional group
- fixed bottom delete button

## 4. Failure Safety

1. Reset animation state before each enter cycle to avoid stale opacity/offset on rapid open-close-open.
2. Keep behavior stable under extreme `speedFactor` values.
3. Prevent animation storms in high-frequency updates (launcher typing) via batched transitions.

## 5. Acceptance Criteria

1. Every independent content unit in scope participates in stagger enter.
2. Viewport-entered items animate upward in list/grid views.
3. Launcher and widget library support refresh transition (old exit + new enter).
4. No runtime warnings/errors introduced.
5. No noticeable flicker or destructive jank during rapid interactions.

## 6. Rollout Plan (B + C)

1. Phase 1: Introduce orchestrator and connect existing panel lifecycle triggers.
2. Phase 2: Fill missing page-level coverage (`AboutPage`, widget-card delegates, launcher structural nodes).
3. Phase 3: Add list/grid adapter behavior for viewport-enter and refresh transitions.
4. Phase 4: Remove duplicated animation logic and normalize tokens.
