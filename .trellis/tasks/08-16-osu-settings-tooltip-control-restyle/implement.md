# Implementation Plan

## 1. Tooltip arbitration

- Add stable request ordering/update semantics to `SettingsOverlayBridge.qml`.
- Update `LazerSettingsContent.qml` to retain a valid equal-priority owner, accept higher priority, update active text in place, and use deterministic fallback.
- Extend bridge/panel/overlay tests for simultaneous row/control and adjacent same-priority sources.

## 2. Settings tokens

- Add settings-only accent, trough, panel, rail, and inactive-nav tokens to `LazerTheme.qml`.
- Replace settings-specific pink/grey references without changing unrelated global theme uses.
- Update token assertions.

## 3. Row presentation contract

- Add control-provided row presentation metadata to Toggle and Slider.
- Refactor `LazerSettingsRow.qml` to render standard, inline Toggle, and split Slider modes without per-row card backgrounds.
- Preserve revert zone, search visibility, disabled propagation, width budgets, and tooltip behavior.

## 4. Toggle and Slider visuals

- Replace Toggle Nub with the `44x20` checked/unchecked capsule.
- Replace Slider track/Nub with the `24px` trough, travelled purple fill, and `4x20` embedded Thumb.
- Keep existing behavior APIs and expose the Thumb as `nubItem`.
- Add exact geometry/color and interaction tests.

## 5. Sidebar and search chrome

- Remove inactive nav indicator and apply `#8A8795` icon/text foreground.
- Remove content header collapse/close controls and update panel aliases/focus navigation/tests.
- Right-align the search icon, set `输入以搜索`, and let clear replace the icon while text exists.
- Verify Sidebar Back, Sidebar collapse, and Esc remain operable.

## 6. Verification and finish

- Run relevant settings QML suites sequentially and repeat panel/overlay lifecycle suites.
- Run `python3 -m pytest -q`.
- Run `qmllint` on modified QML files.
- Run `git diff --check`.
- Run `timeout 15s qs -p .`; require `Configuration Loaded` and review every WARN/ERROR.
- Run Trellis quality check, update frontend spec if the arbitration/layout contract is reusable, commit with Conventional Commits, and archive the task.
