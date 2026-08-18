# Mask A/B Runtime Results

## Commands

- `qmllint services/SettingsService.qml modules/lazerbar/TopBar.qml modules/lazerbar/LazerSettingsOverlay.qml`
- `timeout 15s qs -p .`
- `qs ipc -p . show`
- `qs ipc -p . call settings debugHover true`
- `qs ipc -p . call settings maskOverride auto`
- `qs ipc -p . call settings maskOverride on`
- `qs ipc -p . call settings maskOverride off`
- `qs ipc -p . call settings maskOverride invalid`
- `qs ipc -p . call settings openHoverDebug eDP-1`
- `qs ipc -p . call settings snapshotHover`
- `qs log --id lpj1h3cyjt -t 80`

## IPC Evidence

`qs ipc -p . show` now exposes:

```text
target settings
  function maskOverride(mode: string): void
```

Calls `auto`, `on`, and `off` completed without CLI errors. An invalid value was normalized to `auto`. Logs contained:

```json
{"event":"mask-override","override":"auto","token":1}
{"event":"mask-override","override":"on","token":2}
{"event":"mask-override","override":"off","token":3}
{"event":"mask-override","override":"auto","token":4}
```

The override is process-local and does not call `save()` or write settings data.

## Same-Geometry A/B

With the Settings panel open on `eDP-1`, Appearance selected, the debug snapshot reported the following in both modes:

```text
overlay rect: x=0 y=0 width=570 height=1029
sidebar: x=0 width=170 z=1
content: x=170 width=400 z=0
viewport: y=100 width=400 height=885 clip=true
wallpaper row: scene x=178 y=100 width=384 height=82
wallpaper field: scene x=190 y=134 width=324 height=38
color choice: scene x=178 y=190 width=336 height=52
panel opacity control: scene x=335.8 y=261 width=178.2 height=30
enable blur control: scene x=470 y=322 width=44 height=20
```

Mask-enabled snapshot:

```json
{"mask":{"active":true,"overlayBlocksDesktop":true,"override":"auto","owner":"settingsOverlay"}}
```

Mask-disabled snapshot:

```json
{"mask":{"active":false,"overlayBlocksDesktop":true,"override":"off","owner":"settingsOverlay"}}
```

The overlay, page, row, and control geometry remained unchanged. The only observed state difference was the effective mask flag.

## Pointer Evidence Limitation

The environment has `/usr/bin/wtype`, but no `ydotool` or `wlrctl`. No reliable automated Wayland coordinate injection was available. Consequently the snapshots show `hover=false` unless the existing pointer happened to be over a row; they prove the mask toggle and geometry isolation, but do not prove whether hover behavior changes between A/B modes.

## Validation

- `qmllint`: passed with no output.
- `timeout 15s qs -p .`: configuration loaded; existing notification server registration warning remained.
- `git diff --check`: passed.
- Settings QML tests remain blocked at load time by `qrc:/qs-blackhole: No such file or directory` and did not reach assertions.

## Result

The mask A/B control is operational and safe for diagnosis. No hover conclusion can be drawn until the same pointer coordinates are sampled in both modes. If a later pointer-capable run shows hover only with `override=off`, the root cause is the PanelWindow/Region boundary; if hover is unchanged, investigation must continue inside the QML scene.
