# Panel Unification and Notification Diagnostics Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Unify panel close behavior and centered placement, make widget-settings-driven layout mode temporary and safe, and expose readable diagnostics when another daemon owns desktop notifications.



---


**Files:**

**Step 1: Write the failing assertion**


Use a pattern like:

```qml
root._assert(typeof BarLayoutService.widgetSettingsAutoEnteredLayout === "boolean",
    "BarLayoutService should track whether widget settings auto-entered layout mode")
```

Adjust the exact property name to the final implementation name, but make the test fail because the state does not exist yet.

**Step 2: Run the harness to verify it fails**

Run:

```bash
```

Expected: FAIL on the new missing layout-session assertion.

---

### Task 2: Add shared layout-session state and cleanup rules

**Files:**
- Modify: `services/BarLayoutService.qml`
- Modify: `modules/bar/BarContextMenu.qml`
- Modify: `modules/bar/WidgetSettingsPanel.qml`

**Step 1: Add shared session state to `BarLayoutService.qml`**

Introduce the minimal shared state needed to represent:

- whether widget settings auto-entered layout mode for the current session
- whether widget left-click business actions should be suppressed while layout mode is active

Keep the state narrow and bar-domain-specific.

**Step 2: Record temporary layout entry in `BarContextMenu.qml`**

When the user opens widget settings from the widget context menu:

- detect whether layout mode was already active
- only set the auto-enter flag when the context menu had to enter layout mode
- continue opening widget settings as before

**Step 3: Close widget settings with correct cleanup in `WidgetSettingsPanel.qml`**

Update the close control so it always closes the panel, clears the active widget key, and only exits layout mode when the session entered it automatically.


Run:

```bash
```

Expected: PASS on the new service/session assertions.

---

### Task 3: Center major panels and add explicit close buttons

**Files:**
- Modify: `modules/bar/SettingsPanelWindow.qml`
- Modify: `modules/bar/WidgetPickerWindow.qml`
- Possibly modify: `modules/bar/settings/SettingsPanelContent.qml`

**Step 1: Add failing structural assertions**


Keep assertions structural:

- centered anchor configuration or explicit horizontal center contract
- close button object/function exists

**Step 2: Center `SettingsPanelWindow.qml`**

Change the panel placement so it opens centered below the bar instead of aligned to the right edge.

Add a clear close control in the panel chrome that closes the settings panel only.

**Step 3: Center `WidgetPickerWindow.qml`**

Change the picker placement so it opens centered below the bar instead of tracking the clicked section’s left edge.

Add a clear close control in the picker chrome that closes the picker only.


Run:

```bash
```

Expected: PASS with the new centered-panel and close-affordance assertions.

---

### Task 4: Remove copy/delete from the widget context menu

**Files:**
- Modify: `modules/bar/BarContextMenu.qml`

**Step 1: Add failing assertion**


Keep this structural and low-risk, such as checking for the absence of dedicated action handles after instantiating the component in a harness if practical, or by asserting a smaller action count contract if that is the stable public structure.

**Step 2: Remove the actions**

Delete the `复制组件` and `删除组件` menu entries from `BarContextMenu.qml` while preserving the `组件设置` entry.

Delete any now-unused clipboard helper/process code that only served the widget-copy menu path.


Run:

```bash
```

Expected: PASS.

---

### Task 5: Suppress widget left-click business actions during layout mode

**Files:**
- Modify: `modules/bar/BarWidgetWrapper.qml`
- Modify: one or more interactive widget files if wrapper integration requires small adaptations

**Step 1: Write the failing test**


Choose the smallest stable target widget or wrapper-level test surface.

**Step 2: Implement wrapper-level suppression**

Update `BarWidgetWrapper.qml` so layout mode blocks business left-click interaction centrally instead of requiring each widget to add its own guard.

Keep drag behavior and right-click context menus working.


Run the smallest relevant harness command, for example:

```bash
```

Or a new focused harness if one is introduced.

Expected: PASS.

---

### Task 6: Add notification ownership diagnostics

**Files:**
- Modify: `services/NotificationService.qml`
- Modify: `modules/bar/settings/AboutPage.qml` or another existing settings surface that can safely show a lightweight diagnostics row
- Modify: `config/settings-default.json` and `services/SettingsService.qml` only if a user-visible notification diagnostics setting is actually introduced

**Step 1: Add failing diagnostics assertions**


- ownership/availability boolean
- current owner name string
- readable guidance message string

The exact property names can vary, but the harness should fail because the diagnostics state does not exist yet.

**Step 2: Implement diagnostics in `NotificationService.qml`**

Add minimal state and logic so registration failures can surface:

- whether shell notifications are currently available
- which external service currently owns `org.freedesktop.Notifications` when detectable
- a user-readable recommendation string

Do not auto-kill or auto-replace external daemons.

**Step 3: Surface diagnostics in an existing settings view**

Add a lightweight diagnostics row or section in an existing settings surface so users can see that, for example, `swaync` currently owns notifications and that disabling it is required for shell takeover.

Keep this read-only.


Run:

```bash
```

Expected: PASS with the new diagnostics assertions.

---

### Task 7: Run full verification

**Files:**
- Verify: all files touched above


```bash
```

Expected: PASS.


```bash
```

Expected: PASS.


```bash
```

Expected: PASS.

**Step 4: Run full-shell load check**

```bash
timeout 10 qs --path .
```

Expected: PASS aside from pre-existing environment warnings.

**Step 5: Inspect the current notification owner for evidence**

```bash
busctl --user status org.freedesktop.Notifications
```

Expected: output identifies the current owner when takeover is unavailable (for example `swaync` in the current environment), matching the diagnostics state surfaced in the UI/service.
