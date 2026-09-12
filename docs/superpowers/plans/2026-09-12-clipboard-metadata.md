# Clipboard Metadata Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show text character counts and image format, byte size, and resolution in launcher clipboard results.

**Architecture:** Parse metadata from the existing `cliphist list` preview inside the pure `LauncherAdapters.js` layer. Keep the QML result row unchanged because it already renders the adapter-provided `displayName` and `description`; no decode or filesystem probe is added.

**Tech Stack:** Qt 6 QML, JavaScript `.pragma library`, QtTest/qmltestrunner.

## Global Constraints

- Do not add `cliphist decode`, image probing, or additional process work to list rendering.
- Preserve clipboard filtering, ordering, preview decoding, timestamps, and execution behavior.
- Use the existing adapter result fields consumed by `LauncherResultRow`.
- Use ASCII source text and the repository's Qt6 test command.

---

### Task 1: Add Pure Clipboard Metadata Parsing

**Files:**
- Modify: `services/launcher/LauncherAdapters.js:252-287`
- Test: `tests/qml/tst_launcher_adapters.qml` near the existing clipboard adapter tests

**Interfaces:**
- Produces `parseClipboardImageMeta(preview)` returning `{ size, format, width, height }` or `null`.
- Produces clipboard item descriptions using the existing `description` field.

- [ ] **Step 1: Add failing adapter tests**

Test that a short text preview includes its character count, a truncated preview uses a long-text label, a valid binary image preview exposes format/size/resolution, and an invalid image preview falls back to MIME.

- [ ] **Step 2: Run the focused adapter test and verify failure**

Run:

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launcher_adapters.qml -o -,txt
```

Expected: the new metadata assertions fail before implementation.

- [ ] **Step 3: Implement minimal parsing and formatting**

Add a regex matching:

```text
[[ binary data <size> <format> <width>x<height> ]]
```

For text, use the existing preview length and treat previews at or above the truncation threshold as unknown/long instead of claiming an exact count. Preserve the existing timestamp suffix.

- [ ] **Step 4: Run the adapter test and verify success**

Run the same Qt6 qmltestrunner command. Expected: all adapter tests pass with no warnings.

- [ ] **Step 5: Commit the implementation**

```bash
git add services/launcher/LauncherAdapters.js tests/qml/tst_launcher_adapters.qml
git commit -m "feat(launcher): show clipboard item metadata"
```

### Task 2: Run Launcher Regression Suites

**Files:**
- No source changes expected.
- Test: `tests/qml/tst_launcher_service.qml`
- Test: `tests/qml/tst_launcher_page.qml`
- Test: `tests/qml/tst_overlay_coordinator_logic.qml`

**Interfaces:**
- Verifies adapter metadata remains compatible with the existing launcher session and result row.

- [ ] **Step 1: Run all affected suites**

```bash
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launcher_adapters.qml -o -,txt
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launcher_service.qml -o -,txt
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_launcher_page.qml -o -,txt
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner -input tests/qml/tst_overlay_coordinator_logic.qml -o -,txt
```

- [ ] **Step 2: Check the final diff**

```bash
git diff --check
git status --short
```

Expected: no whitespace errors; unrelated existing untracked files remain untouched.

- [ ] **Step 3: Commit any required test-only adjustment**

Only if the existing tests require an assertion update for the new descriptions:

```bash
git add tests/qml/tst_launcher_service.qml tests/qml/tst_launcher_page.qml
git commit -m "test(launcher): cover clipboard metadata display"
```
