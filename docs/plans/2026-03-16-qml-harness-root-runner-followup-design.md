# QML Harness Root Runner Follow-up Design

## Overview

top of a repository-root harness runner.

The key goal is not to rewrite every harness at once. The goal is to make the
already failing structure harnesses load through the same module graph as the
real shell.

## Problem

Direct commands like:

```bash
```

run the harness file itself as the config root.

That breaks `qs.*` module resolution in this environment, and it also makes some
relative-import harnesses rely on the mirrored `tests/qml/modules` tree instead
of the real source tree.


- it entered through `tests/qml/modules/bar/settings`
- those settings files internally use `import ".."`
- that internal import chain expected the real `modules/bar` tree
- shared bar types like `ClickRipple` and `HoverRevealHighlight` stopped
  resolving

## Chosen Approach

### Root Runner

`tests/qml/` while the shell root stays at the repository root.

This restores production-like `qs.config`, `qs.services`, and `qs.modules.*`
resolution.

### Targeted Harness Import Cleanup

Only change harnesses that are already confirmed to be broken or unnecessarily
dependent on the mirrored tree.

  `qs.modules.bar`
  `modules/bar/settings` tree

For settings specifically, importing the real source directory is important so
the settings subtree's internal `import ".."` resolves back to the real
`modules/bar` directory.

## Scope

### In Scope

- add `tests/run-qml-harness.sh`
- move the verified structure harnesses to the new runner
- repair the settings harness import path

### Out of Scope

- bulk migration of every media or SuperIsland harness
- changing production module import structure
- replacing all uses of `tests/qml/modules` immediately

## Verification Strategy

Run the repaired commands directly:

```bash
timeout 10 qs --path .
```

## Expected Outcome

After this change:

- the broken structure harnesses load through the root runner
- agent guidance points to commands that actually work in this environment
