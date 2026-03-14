# Launcher Core Refactor Wave 4 Design

## Overview

Wave 4 focuses on internal standardization of `modules/launcher/LauncherCore.qml`.
The goal is not to change launcher behavior, IPC, provider contracts, or visual
structure. The goal is to split one overloaded QML module into a small set of
clearer parts so future changes can stay local and safer.

This wave stays deliberately low-risk:

- keep `LauncherPanel` as the public shell-facing entry
- keep `LauncherService` and provider APIs unchanged
- keep search behavior and keyboard interactions unchanged
- keep verification anchored in structure smoke plus full-shell load checks

---

## Why This Refactor

`modules/launcher/LauncherCore.qml` currently mixes several responsibilities in
one file:

- search input and mode badge rendering
- keyboard interaction handling
- result list rendering and delegate interaction
- provider selection and query routing
- deferred result swapping and selection state
- structural stagger animation wiring

That combination makes the file harder to reason about, increases the chance of
accidental regressions, and slows down future work on launcher UX.

The refactor treats the current file like a machine room that still works, but
whose wiring is exposed. We are not changing the machinery; we are moving the
wiring into labeled panels.

---

## Chosen Approach

We use a medium-scope refactor.

### Kept Stable

- `modules/launcher/LauncherPanel.qml` remains the same integration point
- `modules/launcher/LauncherCore.qml` remains the coordinator component
- `services/LauncherService.qml` remains the source of open/close state
- `modules/launcher/providers/ApplicationsProvider.qml` remains unchanged
- `modules/launcher/providers/ClipboardProvider.qml` remains unchanged

### New Internal Subcomponents

Two new presentation-focused components will be introduced:

1. `modules/launcher/LauncherSearchHeader.qml`
2. `modules/launcher/LauncherResultsList.qml`

These components handle UI concerns only. Coordination and provider routing stay
in `LauncherCore.qml`.

---

## Responsibility Split

### `LauncherCore.qml`

Keeps orchestration responsibilities:

- panel open/close lifecycle
- structural enter/exit animation registration
- provider selection via text prefix
- result refresh and deferred result swapping
- selected-index ownership
- activation dispatch into the chosen result item

This file becomes the launcher's control room instead of also rendering every
piece of UI directly.

### `LauncherSearchHeader.qml`

Owns header presentation and input handling:

- mode badge text
- text field rendering
- key handlers for up/down/enter/escape
- text change signal forwarding

It should expose a small signal-based API so the parent can react without giving
the child business logic responsibilities.

### `LauncherResultsList.qml`

Owns result presentation:

- `ListView` and delegate structure
- selected-row highlighting
- hover-to-select behavior
- click-to-activate behavior

It receives display data and selected index from the parent and emits events
back upward when the user changes selection or activates a row.

---

## Data Flow

The data flow remains parent-coordinated.

1. `LauncherService` tells the launcher whether the panel is open.
2. `LauncherCore.qml` reads the current input text.
3. `LauncherCore.qml` selects the active provider.
4. The provider returns launcher result objects.
5. `LauncherCore.qml` maps those into display-only model rows plus full result
   objects for activation.
6. `LauncherSearchHeader.qml` emits user intent signals.
7. `LauncherResultsList.qml` emits hover/click selection signals.
8. `LauncherCore.qml` updates `_selectedIndex` and performs activation.

This keeps business coordination in one place and prevents presentation
components from reaching into providers or services directly.

---

## Risk Control

To keep the wave low-risk, the refactor explicitly avoids:

- changing IPC names or launcher open/close semantics
- changing provider interfaces
- changing clipboard integration
- changing `DesktopEntries` loading behavior
- introducing new stateful services
- adding environment-sensitive integration tests

The refactor only changes internal composition and local UI ownership.

---

## Verification Strategy

Verification stays focused on stable external behavior.

### Reused Guardrail

Extend `tests/qml/LauncherStructureSmoke.qml` instead of creating a new complex
integration harness. The smoke should continue proving that:

- `LauncherPanel` loads successfully
- `LauncherService.toggle()` still opens the launcher
- `LauncherService.openClipboard()` still sets the expected prefill text
- the panel remains focusable and structurally intact
- the refactored `LauncherCore` still loads its internal children cleanly

### Shell-Level Verification

Run the full-shell load check after refactoring:

```bash
timeout 10 qs --path .
```

This ensures the composition change does not break broader QML loading.

---

## Expected Outcome

After Wave 4:

- launcher code is easier to read and change
- presentation responsibilities are separated from coordination logic
- external behavior remains stable
- future launcher work can target smaller files with narrower purposes

This is a maintainability wave, not a feature wave.
