# Wallpaper-First Startup Design

## Status

Proposed. The user approved the direction in chat; implementation starts after
review of this written design.

## Context

Afloat currently mounts the wallpaper, bar, overview backdrop, notification
host, screen-corner mask, and session-lock owner as synchronous children of the
root shell. The first wallpaper is then held in `bootWallpaper` while
`WallpaperBackground` waits for a run of clean frames before assigning the
incoming image and starting the reveal. The result is that bar and other shell
scene construction can delay the first visible wallpaper transition.

The startup requirement is stronger than merely shortening the delay:

- the wallpaper reveal must begin before the bar scene is constructed;
- the existing live wallpaper-switch reveal must remain unchanged and smooth;
- the shell must still show a usable fallback when no wallpaper is configured
  or the image fails to load;
- all screens must be handled without leaving chrome permanently unloaded;
- palette extraction remains after the reveal, as already established;
- startup diagnostics must not remain in production code or create a surface.

## Reference Comparison

The following open-source implementations were inspected for behavior and
startup structure:

- DymicShell `BackgroundWindow.qml`:
  https://github.com/Sighthesia/DymicShell/blob/main/modules/background/BackgroundWindow.qml
  starts its startup timer independently of the bar and assigns the incoming
  wallpaper directly when the timer fires.
- DymicShell `shell.qml`:
  https://github.com/Sighthesia/DymicShell/blob/main/shell.qml
  groups normal shell content separately from the root and mounts the
  background as an independent surface.
- dots-hyprland `Background.qml`:
  https://github.com/end-4/dots-hyprland/blob/main/dots/.config/quickshell/ii/modules/ii/background/Background.qml
  binds the wallpaper image independently and does not gate it on bar startup.
- dots-hyprland `Bar.qml`:
  https://github.com/end-4/dots-hyprland/blob/main/dots/.config/quickshell/ii/modules/ii/bar/Bar.qml
  uses `LazyLoader` for the bar window, so bar construction is not a prerequisite
  for the background image.

These references inform the startup separation only. Afloat keeps its own
OpacityMask implementation, osu!lazer timing tokens, and service contracts.

## Design

### 1. Split the root into wallpaper bootstrap and chrome bootstrap

`shell.qml` will keep `LazerBar.WallpaperBackground` as the only eagerly
mounted visual shell surface. The following objects move into a `Component`
owned by a `Loader`:

- `OverviewBackgroundWindow`;
- `Bar.TopBar`;
- `NotificationHost`;
- `ScreenRoundedCorners`;
- `LockModule.Lock`.

The chrome loader becomes active only after the wallpaper bootstrap reports
that the first reveal has completed on every current screen. The existing
service injection into `LazerTheme` remains at root completion so the wallpaper
floor can resolve its color without waiting for chrome.

The explicit startup calls for `AppThemeService`, `LauncherService`,
`ClipboardService`, and the automatic lock move into the chrome component's
completion path. They therefore cannot occupy the wallpaper-first scene-build
window.

### 2. Make the first wallpaper start from image readiness, not clean frames

`WallpaperBackground` keeps the first request as a boot request but removes the
30-frame startup gate. Once the surface has a non-zero size, it will:

1. resolve and snapshot the reveal origin;
2. assign the incoming wallpaper source to the existing offscreen reveal image;
3. wait only for `WallpaperReveal.imageReady` or `imageFailed`;
4. start the existing circular animation when pixels are ready;
5. report boot completion after the animation settles.

The `WallpaperReveal` image remains synchronous (`asynchronous: false`) and the
existing live-switch path remains unchanged. The first boot path only changes
the point at which it is entered and the readiness condition used before its
animation starts.

When reduced motion is enabled, when the requested path already equals the
settled source, or when there is no path, the boot path reports completion
immediately after settling the fallback state. An image failure also reports
completion after returning to the floor, so chrome cannot be stranded behind a
bad wallpaper.

### 3. Coordinate multiple screens

`WallpaperBackground` will expose a root-level `bootReady` property and count
one completion per screen instance. The chrome loader activates only when all
currently listed screens have reported completion. A zero-screen startup does
not occur on a mapped shell; if the screen list changes before completion, the
count must be clamped or recomputed so a newly added screen cannot cause an
invalid early activation.

The per-screen completion callback is idempotent. A later wallpaper switch
cannot change `bootReady` or retrigger chrome construction.

### 4. Preserve runtime behavior after bootstrap

After the chrome loader is active:

- bar widgets and overlays retain their current ownership and bindings;
- the lock service is created once and receives the existing startup-lock call;
- overview and corner surfaces keep their current layer and visibility rules;
- wallpaper changes continue through `beginWallpaper()` with the existing
  click-origin snapshot, synchronous decode, reveal animation, and palette gate.

No change is made to the screen-corner mask or the proven live wallpaper swap
effect.

## Error Handling

- Empty wallpaper path: paint the existing theme floor, skip the reveal, and
  report that screen's boot completion.
- Image error: clear the pending reveal, release the palette gate if needed, and
  report completion.
- Screen removal during startup: ignore completion from destroyed instances and
  recompute readiness from the current screen count.
- Screen addition during startup: require the new screen to complete before
  activating chrome.
- Loader creation failure: retain the wallpaper surface and log only the normal
  QML error; no diagnostic process or extra input surface is introduced.

## Testing

Before implementation, the current pure reveal geometry and image-readiness
tests provide the baseline:

```fish
QML_IMPORT_PATH=/usr/lib/qt6/qml /usr/lib/qt6/bin/qmltestrunner \
  -input tests/qml/tst_wallpaper_reveal.qml -o -,txt
```

The implementation will add a pure JS/QML-testable boot readiness seam for:

- one screen completing;
- all screens completing;
- duplicate completion being ignored;
- empty/error/reduced-motion completion paths;
- a newly added screen delaying readiness.

After every QML change, the relevant Qt 6 test files and `qmllint` will run.
The production shell will not be launched by a test harness, and no test will
mount an extra full-screen surface.

## Acceptance Criteria

1. On startup, the first wallpaper source begins loading without waiting for
   bar or chrome construction.
2. The circular boot reveal begins as soon as its pixels are ready, subject
   only to the image readiness boundary.
3. The bar and other chrome are created after the reveal completes on all
   screens.
4. The first reveal remains visible and smooth; no startup path silently
   settles directly to the final wallpaper unless reduced motion, an empty
   path, or an image error requires it.
5. Live wallpaper changes retain their current smooth circular reveal behavior.
6. Existing wallpaper, corner-mask, launcher, and Python tests remain green.
7. No temporary probe marker, `/tmp` writer, or diagnostic-only import remains.
