# Implementation Plan: Center Dockzone Island 展开

## Execution Order

### Step 1: Create IslandService singleton
- [ ] Create `services/IslandService.qml` with expanded/query/mode state
- [ ] Register in `services/qmldir`
- [ ] Add IPC handler (`target: "island"`, functions: toggle, open, close)
- [ ] Wire `LauncherService.toggle()` to delegate to `IslandService.toggle()`

### Step 2: Create IslandWindow shell
- [ ] Create `modules/island/` directory
- [ ] Create `IslandWindow.qml`: PanelWindow per-screen, Top layer, exclusiveZone -1, full-screen height, transparent
- [ ] Add mask region tracking island body bounds
- [ ] Add click-away MouseArea for dismiss
- [ ] Add keyboard focus switching (Exclusive when expanded, None when collapsed)
- [ ] Register in `shell.qml`

### Step 3: Create IslandBody with animation
- [ ] Create `IslandBody.qml`: animated width/height/radius driven by IslandService.expanded
- [ ] SpringAnimation on width/height/radius (spring: 5.0, mass: 3.6, damping: 0.75)
- [ ] Background Rectangle with rounded corners + surface color
- [ ] Ear decorations (left/right Canvas) connecting to screen top edge
- [ ] Shadow (DropShadow or manual)

### Step 4: Content switching (collapsed ↔ expanded)
- [ ] Collapsed content: reuse existing Clock widget (or simplified time display)
- [ ] Expanded content: search input + results loader
- [ ] Opacity crossfade between collapsed/expanded content (duration: 200ms)
- [ ] Results loader: switch between AppGrid.qml and ClipboardList.qml based on mode

### Step 5: Adapt launcher components for island context
- [ ] Ensure AppGrid.qml works with 480px width constraint (may need column count adjustment)
- [ ] Ensure ClipboardList.qml works within island height constraint
- [ ] Wire app launch → IslandService.close()
- [ ] Wire clipboard select → IslandService.close()

### Step 6: Remove center section from BarWindow
- [ ] Hide/remove center BarSection from BarContent.qml (island owns center content now)
- [ ] Or: keep center section but make it invisible when IslandWindow is present

### Step 7: Polish & edge cases
- [ ] Escape key handling
- [ ] Focus management (auto-focus search input on expand)
- [ ] Smooth transition when query is cleared
- [ ] Verify multi-screen behavior (Variants model)

## Validation Commands

```bash
# Run quickshell to test (no build step needed for QML)
quickshell -c shell.qml

# Test IPC
qs ipc call island.toggle
qs ipc call launcher.toggle  # should still work via delegation
```

## Risky Files

- `modules/bar/BarContent.qml` — removing center section changes bar layout
- `services/LauncherService.qml` — IPC delegation change
- `shell.qml` — adding new window

## Rollback Points

- After Step 1: IslandService exists but nothing uses it → safe
- After Step 2-3: IslandWindow renders but no content → can revert module
- After Step 6: Center section removed from bar → this is the point of no return for the old layout
