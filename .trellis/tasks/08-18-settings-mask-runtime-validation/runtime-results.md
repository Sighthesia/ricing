# Runtime Validation Results

## Commands Executed

- `qs ipc -p . show`
- `qs ipc -p . call settings debugHover true`
- `qs ipc -p . call settings snapshotHover`
- `qs ipc -p . call settings openHoverDebug eDP-1`
- `qs list --all`
- `qs log --id lpj1h3cyjt -t 120`
- `qs -p tests/qml/tst_lazer_settings_controls.qml`
- `qs -p tests/qml/tst_lazer_settings_panel.qml`
- `command -v ydotool; command -v wtype; command -v wlrctl; command -v xdotool; command -v swaymsg`

## Confirmed Runtime Evidence

The active instance is:

- instance: `lpj1h3cyjt`
- process: `72201`
- shell id: `e574461c7482006e7273e00358b215d0`
- config: `/home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat/shell.qml`
- display: `wayland/wayland-1`
- screen: `eDP-1`

`qs ipc -p . show` exposes the expected Settings target:

```text
target settings
  function openHoverDebug(screenName: string): void
  function toggle(): void
  function snapshotHover(): void
  function debugHover(enabled: string): void
```

The debug calls returned without CLI errors. The log contained an opening sequence followed by an open snapshot with:

```text
overlay: rect x=0 y=0 width=570 height=1029 phase=open visible=true enabled=true blocksDesktop=true
sidebar: x=0 width=170 z=1
content: x=170 width=400 z=0
viewport: y=100 width=400 height=885 clip=true
mask: active=true owner=settingsOverlay
```

Representative open-page rectangles were inside the fixed window:

- wallpaper Row: scene x `178`, y `100`, width `384`, height `82`; TextField scene x `190`, y `134`, width `324`, height `38`.
- color Choice Row: scene x `178`, y `190`, width `384`, height `52`; Choice scene x `178`, y `190`, width `336`, height `52`.
- panel opacity split control: scene x `335.8`, y `261`, width `178.2`, height `30`.
- enable blur inline control: scene x `470`, y `322`, width `44`, height `20`.

The snapshot showed `hover=false` and no `hoverScenePoint` because no automated pointer coordinate was injected during the experiment. Therefore this is geometry/mask state evidence, not proof of pointer delivery.

## Test Environment Evidence

Both settings QML test commands failed before assertions:

```text
Type Lazer.LazerSettingsRow unavailable
caused by qrc:/qs-blackhole[-1:-1]: No such file or directory
```

and:

```text
Type Lazer.LazerSettingsPanel unavailable
caused by qrc:/qs-blackhole[-1:-1]: No such file or directory
```

No QML assertion or hover result can be inferred from those runs.

## Mask Comparison Status

No valid `mask=false` comparison was obtained.

Reasons:

- The existing Settings IPC exposes debug snapshots and open control, but no mask diagnostic property or function.
- The task forbids changing production QML in this validation phase.
- Available input tools are `/usr/bin/wtype` and `/usr/bin/xdotool`; no `ydotool` or `wlrctl` is installed, and no reliable automated Wayland pointer-coordinate injection was available.

## Conclusion

1. IPC and debug logging are operational.
2. The Settings overlay reaches the expected open geometry and reports `mask.active=true`.
3. The open QML scene rectangles are internally coherent and fit inside the 570px window.
4. The experiment did not establish whether the compositor mask admits or rejects the user's pointer coordinates.
5. The next valid step requires either a temporary, default-off non-persistent mask toggle or a separate runtime harness that can create the same PanelWindow with mask enabled/disabled, plus reliable pointer coordinate injection.

No production files were modified by this validation task.
