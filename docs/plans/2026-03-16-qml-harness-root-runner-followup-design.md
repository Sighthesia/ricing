# QML Harness Root Runner Follow-up Design

## Overview

This follow-up design standardizes the currently broken QML smoke entrypoints on
top of a repository-root harness runner.

The key goal is not to rewrite every harness at once. The goal is to make the
already failing structure harnesses load through the same module graph as the
real shell.

## Problem

Direct commands like:

```bash
qs -p tests/qml/SettingsStructureSmoke.qml
qs -p tests/qml/NotificationStructureSmoke.qml
```

run the harness file itself as the config root.

That breaks `qs.*` module resolution in this environment, and it also makes some
relative-import harnesses rely on the mirrored `tests/qml/modules` tree instead
of the real source tree.

`SettingsStructureSmoke.qml` was the clearest failure:

- it entered through `tests/qml/modules/bar/settings`
- those settings files internally use `import ".."`
- that internal import chain expected the real `modules/bar` tree
- shared bar types like `ClickRipple` and `HoverRevealHighlight` stopped
  resolving

## Chosen Approach

### Root Runner

Add a repository-root `TestHarnessRunner.qml` that loads a named harness from
`tests/qml/` while the shell root stays at the repository root.

This restores production-like `qs.config`, `qs.services`, and `qs.modules.*`
resolution.

### Targeted Harness Import Cleanup

Only change harnesses that are already confirmed to be broken or unnecessarily
dependent on the mirrored tree.

- `NotificationStructureSmoke.qml` -> `qs.modules.notifications` and
  `qs.modules.bar`
- `LauncherStructureSmoke.qml` -> `qs.modules.launcher`
- `SettingsStructureSmoke.qml` -> `qs.modules.bar` plus direct import of the real
  `modules/bar/settings` tree

For settings specifically, importing the real source directory is important so
the settings subtree's internal `import ".."` resolves back to the real
`modules/bar` directory.

## Scope

### In Scope

- add `TestHarnessRunner.qml`
- add `tests/run-qml-harness.sh`
- move the verified structure harnesses to the new runner
- repair the settings harness import path
- update agent guidance and smoke scripts for the verified harnesses

### Out of Scope

- bulk migration of every media or SuperIsland harness
- changing production module import structure
- replacing all uses of `tests/qml/modules` immediately

## Verification Strategy

Run the repaired commands directly:

```bash
bash tests/run-qml-harness.sh SettingsStructureSmoke
bash tests/run-settings-smoke.sh
bash tests/run-ui-structure-smoke.sh
timeout 10 qs --path .
```

## Expected Outcome

After this change:

- the broken structure harnesses load through the root runner
- settings structure smoke no longer depends on the mirrored test module entry
- agent guidance points to commands that actually work in this environment
