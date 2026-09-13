# Task 2 Report: Merge KDE Scheme Into `kdeglobals`

## Changed Files

- `scripts/tests/test_apply_app_themes.py`
  - Added `test_kdeglobals_preserves_unrelated_settings`.
  - Seeds existing `[KDE]` and `[Fonts]` settings and verifies they survive the apply.
- `scripts/theming/apply_app_themes.py`
  - Added `sync_kde_theme(home: Path) -> bool`.
  - Merges rendered `Afloat.colors` sections into `kdeglobals` with case-preserving keys.
  - Invoked after `sync_kitty_clear_text` in both the normal rendering path and kitty-only path.

## Commit

- `cd4fba53` — `feat(theming): merge kde colors into kdeglobals`

## Tests

Preservation test before implementation:

```text
$ python3 -m pytest scripts/tests/test_apply_app_themes.py::test_kdeglobals_preserves_unrelated_settings -q
F                                                                        [100%]
...
E       AssertionError: assert 'BackgroundNormal=#1e1e2e' in '[KDE]\\nwidgetStyle=oxygen\\n\\n[Fonts]\\nfixed=Monospace,10\\n'
1 failed in 0.95s
```

Focused preservation test after implementation:

```text
$ python3 -m pytest scripts/tests/test_apply_app_themes.py::test_kdeglobals_preserves_unrelated_settings -q
.                                                                        [100%]
1 passed in 0.95s
```

Related test file:

```text
$ python3 -m pytest scripts/tests/test_apply_app_themes.py -q
...............                                                          [100%]
15 passed in 4.16s
```

Diff whitespace check:

```text
$ git diff --check
(no output)
```

## Concerns

- `configparser` rewrites the complete `kdeglobals` file and normalizes formatting/comments while preserving sections and case-sensitive option names. This matches the requested merge behavior but may remove comments or original spacing in the target file.
- The kitty-only path now calls `sync_kde_theme`, but it still has no rendered source in the normal use case, so it returns `False` without changing `kdeglobals`.

## Fix Report

### Files Changed

- `scripts/theming/apply_app_themes.py`
  - Removed `sync_kde_theme(home)` from the `--only-kitty-text` fast path.
  - KDE synchronization remains only after normal template rendering.
- `scripts/tests/test_apply_app_themes.py`
  - Added `test_only_kitty_text_does_not_touch_kdeglobals`, covering an existing rendered `Afloat.colors` file and existing `kdeglobals` content.
- `.superpowers/sdd/2026-09-13-kde-dynamic-theme/task-2-report.md`
  - Appended this fix report.

### Test

Regression test before the fix:

```text
$ python3 -m pytest scripts/tests/test_apply_app_themes.py::test_only_kitty_text_does_not_touch_kdeglobals -q
F                                                                        [100%]
...
E       AssertionError: assert '[KDE]\\nwidge...l=#1e1e2e\\n\\n' == '[KDE]\\nwidgetStyle=oxygen\\n'
1 failed in 0.92s
```

Focused regression test after the fix:

```text
$ python3 -m pytest scripts/tests/test_apply_app_themes.py::test_only_kitty_text_does_not_touch_kdeglobals -q
.                                                                        [100%]
1 passed in 0.85s
```

Full focused test file after the fix:

```text
$ python3 -m pytest scripts/tests/test_apply_app_themes.py -q
................                                                         [100%]
16 passed in 4.25s
```

### Commit

- `438cbccf` — `fix(theming): keep kde sync out of kitty fast path`

### Concerns

- No remaining concerns for the reported fast-path regression. KDE merging remains limited to the normal rendering path.
