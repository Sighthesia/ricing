# 设置分类悬浮/聚焦诊断运行结果

## Task 1 Scope

本次只补充 snapshot 诊断字段并运行现有诊断入口，没有修改控件 handlers、Row 命中语义、Flickable、mask、tooltip 或持久化逻辑。

新增 snapshot 字段：

- `viewport.sceneRect`、`visible`、`enabled`、`opacity`、`z`、`clip`。
- 每个 Row 的 `cardSurface` 和 `cardHighlight` local/scene rect、可见性、enabled、opacity、z、border width。
- 每个控件的 `surface` local/scene rect 和层级状态，复用已有 `surfaceItem`、`headerItem`、`trackItem` 或 `nubItem`。
- 每个控件的 `focusRing` activeFocus、focusVisible 和 surface border width 诊断状态。
- `LazerSettingsRow.cardHighlightItem` 和 `LazerSettingsTextField.surfaceItem` 只读诊断别名。

## Environment

- Config: `/home/Sighthesia/0_Files/Producing/Software/Quickshell/afloat`
- Screen requested: `eDP-1`
- Production load: `Configuration Loaded`
- Existing warning: notification server already owned by another process; unrelated to settings hit testing.

## Commands And Results

### Static validation

```bash
qmllint modules/lazerbar/LazerSettingsRow.qml \
  modules/lazerbar/LazerSettingsContent.qml \
  modules/lazerbar/LazerSettingsTextField.qml \
  tests/qml/tst_settings_minimal_focus.qml
```

Result: passed with no output.

```bash
python3 ./.trellis/scripts/task.py validate \
  .trellis/tasks/08-18-settings-category-hover-focus
```

Result: passed. Both context manifests were accepted (`implement.jsonl: 0 entries`, `check.jsonl: 0 entries`).

### Production configuration

```bash
timeout 15s qs -p .
```

Result:

```text
INFO: Configuration Loaded
WARN: Could not register notification server ... one is already registered
```

The configuration loaded successfully. The command exited due to the requested timeout.

### Minimal and existing QML tests

```bash
qs -p tests/qml/tst_settings_minimal_focus.qml
```

Result: blocked before assertions:

```text
Type Lazer.LazerSettingsRow unavailable
caused by qrc:/qs-blackhole: No such file or directory
```

The existing controls test hit the same resource blocker. Neither test is counted as passing.

### Existing category diagnostic entry points

Attempted the required sequence:

```bash
qs ipc -p . call settings debugHover true
qs ipc -p . call settings debugCategory appearance
qs ipc -p . call settings openHoverDebug eDP-1
sleep 1
qs ipc -p . call settings snapshotHover
qs log --id <shell-id> -t 120
```

The IPC calls produced no response in this shell session. The subsequent log reader reported:

```text
No instances start with "e574461c7482006e7273e00358b215d0"
```

Therefore no new runtime JSON containing the newly added surface fields was captured in this environment. The existing diagnostic implementation remains default-off and uses the Row's own `HoverHandler.point.scenePosition`; no ancestor pointer observer was added.

## Existing Runtime Evidence

The prior category snapshot at `.trellis/tasks/08-18-settings-category-hit-diagnosis/runtime-results.md` remains the available runtime baseline.

### Appearance

```text
page: visible=true enabled=true opacity=1 z=0
contentHeight=538 contentY=0
viewport: y=100 height=885 clip=true
row-0: y=100 height=82, control standard y=134 height=38
row-1: y=190 height=52, control choice y=190 height=52
row-2: y=250 height=52, control split y=261 height=30
row-3: y=310 height=44, control inline y=322 height=20
row-4: y=362 height=52, control split y=373 height=30
```

All nine Appearance rows were present, visible, enabled, opacity `1`, z `0`; the prior snapshot reported no active row/control focus at capture time.

### Bar

```text
page: visible=true enabled=true opacity=1 z=0
contentHeight=284 contentY=0
row-0: y=100 height=52, control split y=111 height=30
row-1: y=160 height=52, control choice y=160 height=52
row-2: y=220 height=44, control inline y=232 height=20
row-3: y=272 height=52, row enabled=false opacity=0.3, control effectiveEnabled=false
row-4: y=332 height=52, control split y=343 height=30
```

The disabled fourth row is expected because `floating=false`.

### Notifications comparison

```text
contentHeight=224 contentY=0
row-0: y=100 height=44, control inline y=112 height=20
row-1: y=152 height=52, control split y=163 height=30
row-2: y=212 height=52, control split y=223 height=30
row-3: y=272 height=52, control choice y=272 height=52
```

The existing evidence shows continuous non-zero Row/control geometry and equivalent enabled state for the reported enabled Appearance/Bar rows. It does not prove that the visual surface, Row bounds, and control hit bounds are identical, because those fields were not previously emitted.

## QML Test Blocker

```bash
qs -p tests/qml/tst_lazer_settings_controls.qml
```

Result:

```text
Type Lazer.LazerSettingsRow unavailable
caused by qrc:/qs-blackhole: No such file or directory
```

This is an environment/resource blocker before test assertions. It is not counted as a passing behavior test.

## Task 1 Conclusion

- Static diagnostic additions are valid and production configuration loads.
- Existing runtime evidence rules out missing rows, zero-size rows, and the expected disabled Bar row as the sole explanation.
- The prior evidence continues to leave pointer/focus ownership and Flickable routing as high-value hypotheses.
- The new card/control surface scene-rect fields could not be observed at runtime because no IPC-responsive shell instance was available after the production load command.

**Decision: stop before Task 2.** Proceeding to a production interaction fix would exceed the evidence gate. First rerun the same IPC sequence against a persistent, IPC-responsive shell instance and capture Appearance, Bar, and Notifications snapshots containing `cardSurface`, `cardHighlight`, control `surface`, viewport scene state, and focus/hover fields.
