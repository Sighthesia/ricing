# AGENTS.md

## What This Is

Afloat is a Wayland desktop shell built with [Quickshell](https://quickshell.outfoxxed.me/) (QML). Entry point: `shell.qml`. No build step — QML is interpreted at runtime by `qs`.

## Running

```bash
qs .                       # launch the shell from repo root
qs ipc -p . call <target> <function> [args...]   # IPC call
./scripts/afloat-ipc <target> <function> [args...]  # shortcut wrapper
```

## Tests

```bash
# Python unit tests
python -m pytest scripts/tests/

# QML tests (requires Qt Test; run inside a Quickshell session or with qmltestrunner)
qmltestrunner -input tests/qml/
```

QML tests import services via `../../services` relative paths and use `TestCase` + `tryVerify` / `compare`. Python tests live under `scripts/tests/`.

## Architecture

```
shell.qml              root ShellRoot; imports all module windows
modules/
  background/          wallpaper + screen corner overlays
  bar/                 top status bar, widgets, context menu, widget picker
  island/              dynamic island (clock, launcher)
  launcher/            full-screen app launcher overlay
  notification/        transient popup notifications
  osd/                 volume/brightness/media OSD
  settings/            settings panel popup
  workspace-hint/      workspace/window hint OSD (mod-key held)
services/              singletons declared in qmldir (one file each)
scripts/               Python helpers (IPC bridge, lyrics bridge, window hint trigger, theming)
tests/qml/             QML TestCase files
docs/superpowers/      feature plans + specs
```

### Services Pattern

All services are `pragma Singleton` QML files registered in `services/qmldir`. Import them as:
```qml
import "./" as Services   # or relative path to services/
```
Then access as `Services.MediaService.someProperty`. Every singleton is globally unique.

### Key Services

- `NiriService` — compositor integration (niri IPC)
- `MediaService` / `MediaControlService` / `NeteaseWebLyricsService` — media playback + lyrics
- `Color` / `ColorService` — Material You color tokens from `colors.json`
- `Motion` — centralized animation timing constants
- `SettingsService` — persistent user settings
- `VolumeService` / `BrightnessService` — hardware control
- `WindowHintService` / `WindowHintTriggerService` — workspace hint on mod-key

### Environment Variables

| Variable | Purpose | Default |
|---|---|---|
| `AFLOAT_NETEASE_WEB_LYRICS_PORT` | Lyrics bridge HTTP port | 18765 |
| `AFLOAT_WINDOW_HINT_META_KEYS` | Comma-separated meta key names/codes | leftmeta,rightmeta |
| `AFLOAT_WINDOW_HINT_INPUT` | Colon-separated input device paths | auto-detect `/dev/input/by-path/*-kbd` |

## Design Rules (load skills for full detail)

| Skill | When |
|---|---|
| `glass-liquid-design` | Any visible QML surface, motion, state, or interaction |
| `visual-transition-rules` | Any color, radius, opacity, blur, shadow, spacing, or scale change |
| `comment-before-declarations` | Editing QML modules |
| `surface-owner-split-debugging` | Surface moved/split from prior owner; hover/edit/content/sizing regressions |

Key contracts:
- Every perceptible visual change must animate. Never hard-cut opacity, color, radius, or position.
- Prefer morphing existing elements over destroying and recreating.
- Services are singletons — never instantiate them, always access via the module namespace.
- Place a brief descriptive comment before each major QML element declaration.

## File Conventions

- `services/qmldir` is the source of truth for service singletons. Update it when adding/removing services.
- Colors come from `$CACHE_DIR/colors.json` watched by `Color.qml`; defaults are hardcoded dark palette fallbacks.
- `scripts/theming/` generates `colors.json` from templates.
- `docs/superpowers/plans/` and `docs/superpowers/specs/` hold implementation plans and design specs.
- `.agent-workflow/` contains durable workflow state (decisions, facts, preferences, open questions).

## Workflow Skills

Load `using-agent-workflow` at the start of any non-trivial work to route to the correct workflow skill (intake, execution, verification, memory, docs).
