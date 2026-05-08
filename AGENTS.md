# DymicShell Agent Guide

**DymicShell** is a Quickshell-based Wayland shell.

## Commands

- Run the shell with `qs`.
- Full-shell validation: `timeout 5 qs --path .`
- No repo-local `npm`, `pnpm`, `yarn`, `make`, `just`, `pytest`, `qmllint`, or `qmlformat` command is verified here; do not invent one.

## Structure

- `shell.qml` is the boot entrypoint; keep it to top-level window wiring.
- `modules/` renders UI; `services/` owns shared state, persistence, compositor/process integration, and layout logic.
- `modules/bar/BarContent.qml` is the bar composition root.
- `services/BarLayoutService.qml` is the bar-layout facade; most layout logic lives in `services/barlayout/*.js`.
- `config/Theme.qml`, `config/Colors.qml`, and `config/settings-default.json` are derived/shared inputs; prefer them over hardcoded sizes, colors, and defaults.
- `matugen/config.toml` and `services/WallpaperService.qml` own wallpaper-driven theming.
- `scripts/tampermonkey/netease-web-lyrics.user.js` is the persistent NetEase lyrics path; `scripts/firefox-extensions/netease-web-lyrics/README.md` documents the temporary Firefox fallback.

## Workflow

- Keep runtime writes under `.cache/DymicShell/`.
- When adding or renaming a setting, update both `config/settings-default.json` and `services/SettingsService.qml`.
- `config/Colors.qml` watches `~/.local/state/quickshell/user/generated/colors.json`.
- Prefer the repo-owned matugen config over the user’s global matugen setup.

## QML

- Add a short English comment immediately before each QML element declaration.

## Skills

Load skills on demand; see `.agents/skills/README.md` for grouping.

| Skill                                                                                | When to use                                               |
| ------------------------------------------------------------------------------------ | --------------------------------------------------------- |
| [qml-architecture](.agents/skills/qml-architecture/SKILL.md)                         | QML file layout, imports, and module boundaries           |
| [qml-state](.agents/skills/qml-state/SKILL.md)                                       | Settings, persistence, shared state, and service behavior |
| [qml-components](.agents/skills/qml-components/SKILL.md)                             | Tokens, semantic colors, and base surface patterns        |
| [qml-context-menu](.agents/skills/qml-context-menu/SKILL.md)                         | Bar, tray, and submenu menus                              |
| [qml-token-cleanup](.agents/skills/qml-token-cleanup/SKILL.md)                       | Replacing hardcoded geometry with shared tokens           |
| [qml-visual-language](.agents/skills/qml-visual-language/SKILL.md)                   | Visual identity and cross-component consistency           |
| [qml-indicator-motion](.agents/skills/qml-indicator-motion/SKILL.md)                 | Active indicators and sliding highlights                  |
| [visual-vs-layout-motion-ownership](.agents/skills/visual-vs-layout-motion-ownership/SKILL.md) | Separating visible motion from exported layout geometry   |
| [qml-motion-debug](.agents/skills/qml-motion-debug/SKILL.md)                         | Motion looks wrong even though state changes              |
| [exported-layout-width-ownership](.agents/skills/exported-layout-width-ownership/SKILL.md) | Visible width vs reserved layout width synchronization    |
| [multi-surface-semantic-ownership](.agents/skills/multi-surface-semantic-ownership/SKILL.md) | Root, shell, and content ownership across attached surfaces |
| [runtime-cleanup-chain-interruptions](.agents/skills/runtime-cleanup-chain-interruptions/SKILL.md) | Cleanup callbacks or imports break, so local state resets but stale outer reservation/state survives |
| [baseline-cache-before-transition](.agents/skills/baseline-cache-before-transition/SKILL.md) | Cache a stable pre-transition baseline before live fallback values invalidate on mode entry |
| [single-instance-handoff-motion](.agents/skills/single-instance-handoff-motion/SKILL.md) | Teleport/duplicate-safe cross-host handoff motion         |
| [split-host-exit-synchronization](.agents/skills/split-host-exit-synchronization/SKILL.md) | Synchronizing exit timing across separate geometry owners |
| [list-transition-handoffs](.agents/skills/list-transition-handoffs/SKILL.md)         | Animated list replacement and filter handoffs             |
| [qml-performance-debug](.agents/skills/qml-performance-debug/SKILL.md)               | Jank, frame drops, and layout thrash                      |
| [session-latched-display-state](.agents/skills/session-latched-display-state/SKILL.md) | Stable display state under sparse or weak updates         |
| [weak-signal-bridge-normalization](.agents/skills/weak-signal-bridge-normalization/SKILL.md) | Normalizing incomplete bridge payloads before app state   |
| [reference-attribution](.agents/skills/reference-attribution/SKILL.md)               | Adapting patterns from another repo                       |
| [contour-anchor-before-radius](.agents/skills/contour-anchor-before-radius/SKILL.md) | Fixing bridge silhouette by anchor before radius tuning   |
| [shared-summary-model-delegates](.agents/skills/shared-summary-model-delegates/SKILL.md) | Per-item overview delegates backed by one summary model   |

<!-- TRELLIS:START -->
# Trellis Instructions

These instructions are for AI assistants working in this project.

This project is managed by Trellis. The working knowledge you need lives under `.trellis/`:

- `.trellis/workflow.md` — development phases, when to create tasks, skill routing
- `.trellis/spec/` — package- and layer-scoped coding guidelines (read before writing code in a given layer)
- `.trellis/workspace/` — per-developer journals and session traces
- `.trellis/tasks/` — active and archived tasks (PRDs, research, jsonl context)

If a Trellis command is available on your platform (e.g. `/trellis:finish-work`, `/trellis:continue`), prefer it over manual steps. Not every platform exposes every command.

If you're using Codex or another agent-capable tool, additional project-scoped helpers may live in:
- `.agents/skills/` — reusable Trellis skills
- `.codex/agents/` — optional custom subagents

## Subagents

- ALWAYS wait for every spawned subagent to reach a terminal status before yielding, acting on partial results, or spawning followups.
  - On Codex, this means calling the `wait` tool with the subagent's thread id (requires `multi_agent_v2`). Do NOT infer completion from elapsed time.
  - On Claude Code / OpenCode, this means awaiting the Task/agent tool result before continuing.
- NEVER cancel or re-spawn a subagent that hasn't finished. If a subagent appears stuck, raise the wait timeout (Codex default 30s, max 1h) before judging it broken.
- Spawn subagents automatically when:
  - Parallelizable work (e.g., install + verify, npm test + typecheck, multiple tasks from plan)
  - Long-running or blocking tasks where a worker can run independently
  - Isolation for risky changes or checks

### Codex-only — `spawn_agent` parameters

When calling `spawn_agent`, ALWAYS pass `fork_turns="none"`. Without it the child inherits the parent transcript and sees your prior `spawn_agent(...)` records, then applies the "wait for spawned subagents" rule to itself — causing `wait_agent` self-deadlock.

```text
spawn_agent(agent_type="trellis-implement", message="...", fork_turns="none")
```

### Codex-only — multi-subagent close-loop

When `wait` returns a `completed` notification, treat it as an event signal — not as "all done". Run this loop:

1. Maintain an `expected_agents` set of dispatched sub-agent thread IDs.
2. After each `wait` update:
   1. Call `list_agents` to inspect ALL live agents' status.
   2. For each agent now in a terminal state:
      - Verify its promised deliverable exists (e.g. `{task_dir}/research/*.md`).
      - Read or summarize as needed.
      - `close_agent` to release the slot.
      - Remove from `expected_agents`.
   3. If `expected_agents` still contains running agents → keep waiting.
   4. If `expected_agents` is empty → continue main flow.
3. Never `wait` on an agent that has already reported `completed`.
4. If a `completed` agent is missing its deliverable, treat it as failed — surface that in your report instead of re-waiting.

Managed by Trellis. Edits outside this block are preserved; edits inside may be overwritten by a future `trellis update`.

<!-- TRELLIS:END -->
