# Task 3 Report: Notify KDE Applications

## Files

- Modified `scripts/theming/apply_app_themes.py`.
  - Added `notify_kde_theme() -> bool`.
  - Uses `jeepney` session-D-Bus signaling first.
  - Falls back to `dbus-send` only when `jeepney` is unavailable.
  - Converts all notifier and process failures into `False`, so KDE notification cannot fail app-theme synchronization.
  - Calls the notifier after rendering and `sync_kde_theme(home)`, only when `--home-prefix` is not set.
- Modified `scripts/tests/test_apply_app_themes.py`.
  - Added `test_sandbox_skips_kde_notification` with a monkeypatched notifier boundary.

## Commit

- `e9248783` `feat(theming): notify kde after color sync`

## Tests

### Required failure-first test

Command:

```text
python3 -m pytest scripts/tests/test_apply_app_themes.py::test_sandbox_skips_kde_notification -q
```

Output before implementation:

```text
F                                                                        [100%]
AttributeError: <module 'apply_app_themes' ...> has no attribute 'notify_kde_theme'
1 failed in 0.89s
```

### Required boundary test after implementation

Command:

```text
python3 -m pytest scripts/tests/test_apply_app_themes.py::test_sandbox_skips_kde_notification -q
```

Output:

```text
.                                                                        [100%]
1 passed in 1.07s
```

### Focused test file

Command:

```text
python3 -m pytest scripts/tests/test_apply_app_themes.py -q
```

Output:

```text
.................                                                        [100%]
17 passed in 4.88s
```

### Static and notifier self-checks

Command:

```text
python3 -m py_compile scripts/theming/apply_app_themes.py scripts/tests/test_apply_app_themes.py
```

Output:

```text
```

Command:

```text
git diff --check
```

Output:

```text
```

The direct notifier self-check verified that a missing `dbus-send` returns `False`, while an available fallback command returning exit code zero returns `True`.

## Concerns

- The live session D-Bus path was not exercised against a running KDE session in this test environment.
- The fallback is intentionally limited to `ModuleNotFoundError`, matching the brief: runtime failures from an installed but unusable `jeepney` path are treated as a notification failure rather than switching transports.

## Review Fix Report

### Changes

- Replaced the sandbox notification test's subprocess invocation with a same-process `module.main()` call using monkeypatched `sys.argv`. The notifier is now injected and observed in the process where it is patched.
- Added deterministic jeepney success coverage, asserting the `/KGlobalSettings` address, `SESSION` bus, `notifyChange` signal, `ii` signature, `(0, 0)` payload, and sent signal.
- Added deterministic `dbus-send` fallback coverage, asserting the exact command and arguments, timeout, and captured output configuration.
- Production behavior in `scripts/theming/apply_app_themes.py` was unchanged.

### Tests and outputs

Command:

```text
python3 -m pytest scripts/tests/test_apply_app_themes.py::test_sandbox_skips_kde_notification scripts/tests/test_apply_app_themes.py::test_notify_kde_theme_uses_jeepney_signal scripts/tests/test_apply_app_themes.py::test_notify_kde_theme_falls_back_to_dbus_send -q
```

Output:

```text
...                                                                      [100%]
3 passed in 1.07s
```

Command:

```text
python3 -m pytest scripts/tests/test_apply_app_themes.py -q
```

Output:

```text
...................                                                      [100%]
19 passed in 5.12s
```

Command:

```text
python3 -m py_compile scripts/theming/apply_app_themes.py scripts/tests/test_apply_app_themes.py
git diff --check
```

Output:

```text
```

### Fix commit

- Pending commit for this review fix: same-process sandbox boundary and notifier transport coverage.

### Concerns

- Tests mock both transport paths and intentionally do not require a live KDE session or session bus.
