# Update repository AGENTS.md

## Goal

Update the root `AGENTS.md` so future OpenCode sessions quickly understand the repository's dual nature: a Quickshell shell config at the root, plus project-local Trellis/OpenCode workflow customizations under `.trellis/` and `.opencode/`.

## Requirements

- Preserve the managed `<!-- TRELLIS:START --> ... <!-- TRELLIS:END -->` block unchanged.
- Improve `AGENTS.md` in place instead of rewriting blindly.
- Keep the file compact and high-signal; omit generic advice and unverifiable claims.
- Prefer executable sources of truth over prose when documenting commands or workflow.
- Document only repo-specific guidance that an agent would likely miss without help.
- Cover both layers in the final file: the Quickshell app structure and the local Trellis/OpenCode workflow layer.
- Cover the real repository structure that affects work: `shell.qml`, `modules/`, `services/`, `.trellis/`, and `.opencode/`.
- Capture validated command entry points for Trellis workflow operations that are actually present in the repo, including `python3 ./.trellis/scripts/get_context.py`, `python3 ./.trellis/scripts/task.py ...`, `/trellis:continue`, and `/trellis:finish-work`.
- Mention important workflow caveats that are enforced by local code or config, such as session-scoped active tasks and the fact that workflow-state/session-start behavior is driven by OpenCode plugins under `.opencode/plugins/`.
- Avoid inventing build, test, lint, or CI commands that do not exist in the repository.
- Reconcile the root file with the current repository state: there is no root README, no visible CI workflow, and no root app package manifest; the only `package.json` is under `.opencode/` for plugin dependencies.

## Acceptance Criteria

- [ ] `AGENTS.md` still contains the Trellis-managed block exactly as managed content.
- [ ] The file adds concise, verified guidance about the Quickshell app entrypoint and major directories.
- [ ] The file adds concise, verified guidance about the local Trellis/OpenCode workflow and where those behaviors are implemented.
- [ ] Every documented command or convention is backed by a checked file in this repository.
- [ ] The file does not include speculative setup steps, generic coding advice, or nonexistent CI/build commands.
- [ ] The result is shorter than a typical full project handbook and optimized for fast agent ramp-up.

## Confirmed Facts

- `shell.qml` is the top-level Quickshell composition root and instantiates feature windows from `modules/background` and `modules/bar`.
- `modules/` contains feature-scoped QML UI; `services/` contains shared singleton state and `services/qmldir` exports those services.
- `.trellis/workflow.md` is the workflow source of truth for phases, routing, and `[workflow-state:*]` prompt blocks.
- `.trellis/scripts/task.py` provides the real task lifecycle commands (`create`, `start`, `current`, `finish`, `archive`, `add-context`, `validate`).
- `.opencode/plugins/session-start.js` injects SessionStart context on first user message.
- `.opencode/plugins/inject-workflow-state.js` injects a workflow breadcrumb on every user message and reads status templates from `.trellis/workflow.md`.
- `.opencode/commands/trellis/continue.md` and `.opencode/commands/trellis/finish-work.md` define the preferred command-level entrypoints for resuming and wrapping tasks in OpenCode.
- `.opencode/package.json` is only for OpenCode plugin dependencies and is not evidence of a normal app build/test toolchain.
- `.trellis/spec/frontend/directory-structure.md` confirms the intended top-level split between shell root, feature modules, and shared services.

## Out of Scope

- Adding new project workflow features or changing Trellis/OpenCode behavior.
- Creating README or broader architecture docs.
- Filling incomplete generic spec templates under `.trellis/spec/backend/` or `.trellis/spec/frontend/` beyond what is already needed to describe the repo accurately in `AGENTS.md`.
- Inventing developer commands for Quickshell runtime validation when the repo does not currently define them.

## Open Questions

- None at the moment; the repository answers the needed scope for this documentation update.

## Scope Decision

- Use a dual-layer root `AGENTS.md`: document both the runtime code structure (`shell.qml`, `modules/`, `services/`) and the agent workflow structure (`.trellis/`, `.opencode/`).

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
