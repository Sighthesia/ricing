# Implement: Dedicated Bottom Ear Overlay Windows

## Checklist

### Step 1: Add overlay window module
- [ ] create `modules/bar/BarBottomEarWindow.qml`
- [ ] create per-screen transparent overlay windows using `Variants { model: Quickshell.screens }`
- [ ] anchor one window to top-left and one to top-right
- [ ] size each window to the bottom ear radius

### Step 2: Draw the ears in the overlay windows
- [ ] implement native bottom-left ear canvas path
- [ ] implement native bottom-right ear canvas path
- [ ] keep fill/border colors consistent with current dockzone background

### Step 3: Wire overlay module into shell
- [ ] instantiate `Bar.BarBottomEarWindow {}` from `shell.qml`

### Step 4: Stop relying on in-body bottom ears
- [ ] remove or disable the current bottom-ear runtime drawing paths from `BarDockZoneBackground.qml`
- [ ] keep top ears and body logic intact

## Validation

- `qmllint modules/bar/BarBottomEarWindow.qml modules/bar/BarDockZoneBackground.qml modules/bar/BarSection.qml modules/bar/BarContent.qml modules/bar/BarWindow.qml modules/bar/widgets/WidgetPickerButton.qml shell.qml`
- visually confirm left and right bottom ears render
- visually confirm main bar height stays unchanged
- visually confirm center dockzone remains unchanged

## Risk Files

- `shell.qml` — top-level composition changes can affect which windows are instantiated
- `modules/bar/BarBottomEarWindow.qml` — new window anchoring and per-screen logic
- `modules/bar/BarDockZoneBackground.qml` — must not regress top ears or body shape

## Rollback Points

- after Step 1: delete new overlay module if window placement is wrong
- after Step 3: remove `Bar.BarBottomEarWindow {}` from `shell.qml`
- after Step 4: restore previous bottom-ear branches if overlay migration fails
