# Harness Closeout Verification Design

## Overview

This design closes out the current root-runner and `widgetsettings` migration
without widening scope.

The goal is to prove the migrated harness flow works in the real repository-root
environment, fix only the residual issues surfaced by that proof, and leave any
broader cleanup for a later iteration.

## Problem

The working tree already contains the main migration pieces:

- repository-root `TestHarnessRunner.qml`
- `tests/run-qml-harness.sh`
- `modules/bar/widgetsettings/` rename
- updated smoke scripts and selected harness imports

What is still missing is a disciplined closeout pass. Until we run the narrow
verification set, we do not know whether:

- the old `widget-settings` warning is fully gone
- the updated grouped smoke scripts still pass end-to-end
- any remaining failures come from this migration or from unrelated warnings

## Chosen Approach

Use a minimal verification-first closeout.

1. Run only the commands that directly prove the new harness path and renamed
   widget settings module.
2. If a command fails, make the smallest possible repair in the root-runner,
   `widgetsettings`, smoke-script, or directly related docs area.
3. Re-run the same proof commands until they pass or expose a true architectural
   blocker.

## Why This Approach

- keeps the current iteration small and reviewable
- separates migration validation from historical documentation cleanup
- reduces the chance of mixing genuine regressions with unrelated refactors
- gives a clean handoff point for any later broader migration wave

## Scope

### In Scope

- verifying `MediaControlSettingsSmoke` through the root runner
- verifying `tests/run-media-control-smoke.sh`
- verifying `tests/run-settings-smoke.sh`
- verifying `timeout 10 qs --path .`
- fixing only migration-adjacent issues uncovered by those commands
- updating the relevant design and plan docs if the closeout findings change the
  documented outcome

### Out of Scope

- sweeping replacement of all historical `widget-settings` wording in old docs
- migrating unrelated SuperIsland or launcher work beyond break/fix needs
- broader harness redesign after the current proof passes

## Verification Strategy

The proof commands are intentionally narrow:

```bash
bash tests/run-qml-harness.sh MediaControlSettingsSmoke
bash tests/run-media-control-smoke.sh
bash tests/run-settings-smoke.sh
timeout 10 qs --path .
```

If any step fails, the follow-up change should be constrained to the files that
participate in the root-runner or `widgetsettings` migration.

## Expected Outcome

After this closeout pass:

- the root-runner-based widget settings smoke passes
- grouped media and settings smoke scripts pass with the new entrypoint
- root shell load no longer reports the `modules/bar/widget-settings` invalid
  module-name warning
- the repository has a clear stopping point before any larger migration wave

## Verification Status

The closeout proof was run with the exact commands in this document:

```bash
bash tests/run-qml-harness.sh MediaControlSettingsSmoke
bash tests/run-media-control-smoke.sh
bash tests/run-settings-smoke.sh
timeout 10 qs --path .
```

All commands passed. Remaining console output was limited to pre-existing
environment warnings such as empty `QSettings` keys and notification service
ownership, not the old `widget-settings` module-name warning.
