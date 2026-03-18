# Harness Closeout Verification Design

## Overview

This design closes out the current root-runner and `widgetsettings` migration
without widening scope.

The goal is to prove the migrated harness flow works in the real repository-root
environment, fix only the residual issues surfaced by that proof, and leave any
broader cleanup for a later iteration.

## Problem

The working tree already contains the main migration pieces:

- `tests/run-qml-harness.sh`
- `modules/bar/widgetsettings/` rename

What is still missing is a disciplined closeout pass. Until we run the narrow
verification set, we do not know whether:

- the old `widget-settings` warning is fully gone
- any remaining failures come from this migration or from unrelated warnings

## Chosen Approach

Use a minimal verification-first closeout.

1. Run only the commands that directly prove the new harness path and renamed
   widget settings module.
2. If a command fails, make the smallest possible repair in the root-runner,
3. Re-run the same proof commands until they pass or expose a true architectural
   blocker.

## Why This Approach

- keeps the current iteration small and reviewable
- separates migration validation from historical documentation cleanup
- reduces the chance of mixing genuine regressions with unrelated refactors
- gives a clean handoff point for any later broader migration wave

## Scope

### In Scope

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
timeout 10 qs --path .
```

If any step fails, the follow-up change should be constrained to the files that
participate in the root-runner or `widgetsettings` migration.

## Expected Outcome

After this closeout pass:

- root shell load no longer reports the `modules/bar/widget-settings` invalid
  module-name warning
- the repository has a clear stopping point before any larger migration wave

## Verification Status

The closeout proof was run with the exact commands in this document:

```bash
timeout 10 qs --path .
```

All commands passed. Remaining console output was limited to pre-existing
environment warnings such as empty `QSettings` keys and notification service
ownership, not the old `widget-settings` module-name warning.
