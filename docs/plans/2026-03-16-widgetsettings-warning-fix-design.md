# WidgetSettings Warning Fix Design

## Overview

This design removes the recurring Quickshell scanner warning caused by the
`modules/bar/widget-settings` directory name and repairs the root-runner entry
for widget-settings smoke coverage.

## Problem

Every root-level shell load currently prints:

```text
Module path contains invalid characters for a module name: "/modules/bar/widget-settings"
```

That warning is not just cosmetic. The same hyphenated directory also makes the
root-runner form of `MediaControlSettingsSmoke.qml` fail because the harness
still enters through `tests/qml/modules/bar/widget-settings`, then resolves
`../settings` relative to the mirrored test tree instead of the real source
tree.

## Root Cause

The directory name `widget-settings` is outside Quickshell's module-name rules.

As long as that directory exists under the root-loaded config tree:

- the scanner warns on every `qs --path .`
- any harness that enters through the mirrored test path inherits an unstable
  relative-import chain

## Chosen Approach

Rename the directory to `modules/bar/widgetsettings` and update the small set of
real import sites.

### Why This Approach

- fixes the scanner warning at the source
- keeps runtime imports simple
- makes the root-runner path consistent with the real source tree
- avoids toolchain-specific hacks

### Files Affected

- `modules/bar/WidgetSettingsPanel.qml`
- `tests/qml/MediaControlSettingsSmoke.qml`
- all files physically moved from `modules/bar/widgetsettings/` to
  `modules/bar/widgetsettings/`
- docs and plans that reference the old directory path

## Scope

### In Scope

- rename the directory
- update imports and harness entrypoints that reference it
- verify the warning disappears from root shell load
- verify widget-settings smoke still passes

### Out of Scope

- redesigning widget settings UI
- changing settings semantics
- sweeping migration of unrelated media or SuperIsland harnesses

## Verification Strategy

The key proof commands are:

```bash
bash tests/run-qml-harness.sh MediaControlSettingsSmoke
bash tests/run-media-control-smoke.sh
bash tests/run-settings-smoke.sh
timeout 10 qs --path .
```

The final shell-load check should no longer emit the `widget-settings` invalid
module-name warning.

## Expected Outcome

After this change:

- the invalid module-name warning disappears
- widget-settings smoke works through the root runner
- imports point at a toolchain-friendly directory name

## Verification Status

Verified in the repository root with:

```bash
bash tests/run-qml-harness.sh MediaControlSettingsSmoke
bash tests/run-media-control-smoke.sh
bash tests/run-settings-smoke.sh
timeout 10 qs --path .
```

All four commands passed in the current migration workspace, and the root shell
load no longer reported the invalid module-name warning for
`modules/bar/widget-settings`.
