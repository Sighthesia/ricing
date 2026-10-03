---
name: quickshell-variants-delegate-hijack
description: Use when one component's surfaces are missing from the compositor while the rest of the shell works — the desktop shows the compositor's own background colour, or a full-screen surface simply never appears — with no error beyond one qs:-category warning naming a file and a type. Covers Variants.delegate being taken from the root object's first data entry (including inline children written at the instantiation site), how to prove a surface is unmapped rather than covered or empty, and why a static test can stay green through a completely dead surface.
---

# Quickshell `Variants` delegate hijack

`Variants` creates one instance of its delegate per `model` entry, and
`delegate` **defaults to the first entry in the root object's `data` list**
(<https://quickshell.org/docs/v0.3.1/types/Quickshell/Variants/>; upstream
`Q_CLASSINFO("DefaultProperty", "delegate")` in `src/core/variants.hpp`).

A wrong-type object in that first slot is **not dropped for being the wrong
type** — it becomes the delegate. Quickshell then injects `modelData` into it,
injection fails, and the object is discarded. Your per-screen `Scope` is never
instantiated, so **every surface that component owns silently never reaches the
compositor.**

## The two vectors (both were hit, in sequence)

```qml
// Vector 1 — inside the component file. Wrong, and easy to spot.
Variants {
    model: Quickshell.screens
    Connections { target: Foo; function onBarChanged() {} }   // ← becomes delegate
    Scope { required property var modelData; PanelWindow { … } }
}
```

```qml
// Vector 2 — at the instantiation site. Same data list, invisible from the file.
LazerBar.WallpaperBackground {
    id: wallpaperBackground
    onBootReadyChanged: { … }
    Connections { target: Services.SettingsService; … }     // ← becomes delegate
}
```

Vector 2 is the nasty one: removing an in-file offender changes nothing, because
the delegate was being hijacked from **outside** the file the whole time. `id:` and
`onXChanged:` handlers are property assignments and do **not** enter `data`; a
nested *object* declaration does.

## Why it masquerades as something else

In Afloat this presented as a performance complaint and then as a styling bug:

- The wallpaper window never existed, so its own floor `Rectangle` never painted →
  the desktop showed **niri's own** `background-color`.
- `bootReady` could never become true (only a real `PanelWindow` reports boot), so
  the startup watchdog released every gate → **the rest of the shell mounted and
  looked completely healthy.**
- The overview still showed the wallpaper, because that is a *separate* surface
  loading the same path. "It works in overview" is not evidence the main surface
  exists.

## Proving "unmapped" vs "covered" vs "empty"

Do this before reading any source. It settles the question in two commands.

```sh
niri msg -j layers | python3 -c "
import json,sys
for s in json.load(sys.stdin): print(f\"{s['layer']:11} {s['namespace']}\")"
```

If your namespace is absent, the surface was never mapped — nothing is covering it.
Then confirm the pixels, because "window absent" and "window painting nothing" have
different causes:

```sh
grim -o eDP-1 /tmp/opencode/shots/desk.png
# sample a spot of bare desktop and compare against BOTH candidates:
#   niri's  layout.background-color, and your own floor colour
```

Matching niri's colour **exactly** proves the compositor's own background is what is
visible, i.e. your surface contributed nothing at all — not even its background
rectangle.

**The log line's file prefix tells you where the offending object was written.**
`qs:@/qs/shell.qml: Setting initial properties failed: Connections does not have a
property called modelData` names `shell.qml`, not the component file. Reading it as
"the component file has a stray object" sent the first fix to the wrong file.

**Full logs are on disk; `qs log` is a ring buffer that rolls over.**
`/run/user/1000/quickshell/by-id/<id>/log.qslog` has everything since launch, and
that path is printed in the instance's own startup output.

## Rules

**Rule: the first object child of a `Variants` is its delegate. Nothing may precede
the per-screen `Scope`, in the component file *or* at the instantiation site.**

**Rule: put wiring beside the component, never inside it.**

```qml
LazerBar.WallpaperBackground {
    id: wallpaperBackground
    onBootReadyChanged: { … }
}
// sibling, not child
Connections { target: Services.SettingsService; function onSettingsReadyChanged() { … } }
```

**Rule: a test that only reads the component file cannot see vector 2.** It stayed
green through a fully dead wallpaper surface. Scan instantiation sites too — brace-
match the `TypeName { … }` block and assert it has no direct object child. See
`tests/qml/tst_variants_delegate.qml`.

**Rule: never trust a comment that asserts framework behaviour.** The comment here
read "Variants drops every child that is not a Scope" — the opposite of the truth,
and precisely what made the bug look safe to add. Verify against upstream source or
a probe before relying on it.

## Behavioural probe beats a text assertion

`Variants` is a Quickshell **core** type and `Quickshell/qmldir` only declares
`linktarget quickshell-coreplugin`, so `qmltestrunner` cannot mount these files at
all. A two-file offscreen probe can still prove the mechanism — read the public
`instances` property, which is `readonly list<QtObject>`:

```qml
// Variant component: root object is a Variants, first child is the Scope.
Variants { model: ["alpha"]
    Scope { required property var modelData; property string who: "Scope" } }

// Probe: a Scope carries `who`; a hijacked Connections does not.
console.warn("instances=" + wallpaperBackground.instances.length
              + " who=" + (wallpaperBackground.instances[0].who !== undefined
                           ? wallpaperBackground.instances[0].who : "<not a Scope>"))
```

```
inline Connections present → instances=1 who=<not a Scope>   (+ the modelData warning)
no inline child           → instances=1 who=Scope
```

Run it with `QT_QPA_PLATFORM=offscreen` and an `Item` root (never a `PanelWindow`),
so it maps nothing on the live desktop. `Component.onCompleted` inside a bare `Scope`
is unavailable — `Component` needs `import QtQml`, and the failure is a silent
"Non-existent attached object" that looks like the probe not logging.

## Don't

- Don't conclude "covered by another surface" from a desktop that looks wrong.
- Don't grep only the component file when a warning names a *different* file.
- Don't accept a green static test as proof a surface is on screen.
- Don't re-add an in-file fix and call it done without checking instantiation sites.

## Verification

- `niri msg -j layers` lists the namespace.
- The `modelData` warning is gone from the log for that instance.
- A `grim` sample of bare desktop no longer matches the compositor's background.
- The red/green proof: temporarily reintroduce an inline child and confirm the test
  goes red **naming the file**.
