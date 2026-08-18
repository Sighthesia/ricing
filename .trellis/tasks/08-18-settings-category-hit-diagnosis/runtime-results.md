# 分类命中诊断运行结果

## Environment

- Branch: `lazer`
- Config: `/home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat`
- Screen: `eDP-1`
- Panel: `570 x 1029`
- Content: `400 x 1029`
- Viewport: `y=100`, `width=400`, `height=885`, `clip=true`
- Mask: active, owner `settingsOverlay`

## Feedback Loop

```bash
qmllint modules/lazerbar/LazerSettingsContent.qml
qs ipc -p . call settings debugHover true
qs ipc -p . call settings debugCategory appearance
qs ipc -p . call settings openHoverDebug eDP-1
sleep 1
qs ipc -p . call settings snapshotHover
qs log --id jep39voyjt -t 80
```

The command completed and emitted JSON snapshots. The QML test runner remains blocked before assertions by `qrc:/qs-blackhole: No such file or directory`, so the runtime snapshot is the available red-capable structural probe.

## Appearance Snapshot

Selected page:

```text
page: visible=true enabled=true opacity=1 z=0
contentHeight=538 contentY=0
viewport: y=100 height=885 clip=true
```

All nine Appearance rows were present, visible, enabled, opacity `1`, z `0`, with continuous geometry:

```text
row-0: y=100 height=82, control standard y=134 height=38
row-1: y=190 height=52, control choice y=190 height=52
row-2: y=250 height=52, control split y=261 height=30
row-3: y=310 height=44, control inline y=322 height=20
row-4: y=362 height=52, control split y=373 height=30
row-5: y=422 height=52, control split y=433 height=30
row-6: y=482 height=52, control split y=493 height=30
row-7: y=542 height=44, control inline y=554 height=20
row-8: y=594 height=44, control inline y=606 height=20
```

At snapshot time all rows reported `rowHighlighted=false`, `cardBorderWidth=0`, `focus=false`; all enabled controls reported `effectiveEnabled=true` and `activeFocusOnTab=true`.

## Bar Snapshot

After reopening with debug category `bar` and waiting for the transition:

```text
page: visible=true enabled=true opacity=1 z=0
contentHeight=284 contentY=0
row-0: y=100 height=52, control split y=111 height=30
row-1: y=160 height=52, control choice y=160 height=52
row-2: y=220 height=44, control inline y=232 height=20
row-3: y=272 height=52, row enabled=false opacity=0.3, control effectiveEnabled=false
row-4: y=332 height=52, control split y=343 height=30
```

The disabled fourth row is expected because `floating=false`; it is not evidence of a hit-area failure. The first three and fifth rows have normal enabled control contracts.

## Notifications Comparison

The Notifications page has the same Row/control geometry contract, but its content is shorter:

```text
contentHeight=224 contentY=0
row-0: y=100 height=44, control inline y=112 height=20
row-1: y=152 height=52, control split y=163 height=30
row-2: y=212 height=52, control split y=223 height=30
row-3: y=272 height=52, control choice y=272 height=52
```

## Current Conclusion

- Not a missing-row or zero-size problem.
- Not a disabled-control problem for the reported enabled Appearance/Bar rows.
- Not explained by tooltip or mask state.
- Geometry and enabled state are equivalent enough that the remaining high-value hypothesis is pointer/focus ownership in the page container, especially the `Flickable` path used by all category pages.
- A compositor-level pointer proof is still unavailable because no reliable Wayland coordinate injection tool is installed. The next probe must be a single-variable `Flickable.interactive`/gesture ownership comparison or a QML test run in an environment where `qrc:/qs-blackhole` resolves.
