---
name: qml-testing-strategy
description: Use when implementing, debugging, or validating QML features, bugfixes, behavior changes, geometry changes, or regressions in this repository.
---

# QML Testing Strategy

Choose the smallest repository test that can prove the behavior you changed, then escalate only when a smaller layer can no longer support the claim.

## When to Use

Load this skill for:

- new QML features
- QML bug fixes
- layout or geometry changes
- service-to-module state flow changes
- panel open/close or visibility behavior changes
- drag/drop, picker, or arrival handoff changes
- structure or smoke regressions in QML modules

Do not start with the broadest smoke just because it exists.
High-level smokes are acceptance checks, not the default development driver.

## Test Selection Ladder

Follow this order and stop at the first layer that proves the current claim:

1. closest focused harness for the service or behavior contract
2. module structure or wiring smoke
3. feature smoke for the affected subsystem
4. full-shell load check

Use broader layers when:

- the narrower harness does not cover the changed behavior
- multiple modules now interact through shared runtime state
- you are about to claim the feature works end-to-end

## Change Type Mapping

Use these repository commands as the default routing table.

| Change type | Start here | Escalate to |
| --- | --- | --- |
| bar geometry, slot ordering, drag/drop, picker anchor, arrival handoff | `timeout 12 qs -p tests/qml/BarLayoutGeometrySmoke.qml` | `bash tests/run-ui-structure-smoke.sh`, then `timeout 10 qs --path .` |
| settings structure, settings panel flow, settings-backed QML behavior | `timeout 12 qs -p tests/qml/SettingsStructureSmoke.qml` | `bash tests/run-settings-smoke.sh`, then `timeout 10 qs --path .` |
| notification structure or history panel behavior | `timeout 12 qs -p tests/qml/NotificationStructureSmoke.qml` | `bash tests/run-ui-structure-smoke.sh`, then `timeout 10 qs --path .` |
| launcher structure or launcher shell wiring | `timeout 12 qs -p tests/qml/LauncherStructureSmoke.qml` | `bash tests/run-ui-structure-smoke.sh`, then `timeout 10 qs --path .` |
| super island service or UI behavior | `timeout 12 qs -p tests/qml/SuperIslandServiceSmoke.qml` | `bash tests/run-super-island-smoke.sh`, then `timeout 10 qs --path .` |
| media control, media services, or media visuals | `timeout 12 qs -p tests/qml/MediaServiceSmoke.qml` or the nearest media harness | `bash tests/run-media-control-smoke.sh`, then `timeout 10 qs --path .` |
| cross-shell QML runtime confidence | `timeout 10 qs --path .` | `timeout 10 qs -p .` if needed |

If more than one row applies, run the narrowest relevant harness from each affected area before running a broader suite.

## Verification Before Claiming Success

During implementation:

- run the narrowest harness that proves the changed behavior
- add or extend the nearest existing smoke before inventing a broader one

Before saying the change is stable:

- run the nearest subsystem suite if module structure or shared behavior changed
- run `timeout 10 qs --path .` if runtime QML loading or cross-module behavior changed

Before claiming a regression is fixed:

- make sure the harness that exposed it now passes
- do not rely on a broader smoke alone if the narrow harness is available

## Common Mistakes

- starting with an end-to-end smoke when a focused harness exists
- using unstable local item coordinates when the service already exposes shared geometry contracts
- treating a passing broad smoke as proof that the right layer was tested
- skipping the nearest subsystem suite after changing shared QML structure
- claiming the shell still loads without running `qs --path .`
