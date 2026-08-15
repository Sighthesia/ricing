# Implementation Plan: osu-style Fullscreen UI

## Ordered Checklist

1. Load the project Glass Liquid, transition, QML declaration-comment, and relevant layout-debugging skills.
2. Inspect current `TopBar`, existing settings/music overlays, `qmldir`, and tests before editing.
3. Add pure route/layout helpers and tests for route transitions, page dimensions, and Escape precedence.
4. Implement the fixed per-screen fullscreen owner with inner surface, backdrop, focus boundary and close-complete cleanup.
5. Implement shared header, sidebar and viewport slots with static content contracts.
6. Implement Wiki-like, News-like and Beatmap-like static pages using local models only.
7. Adapt existing settings/music entry points to the new owner without reintroducing independent fullscreen windows.
8. Add focused QML tests for host lifecycle, route switching, layout geometry, static page composition, focus, Escape and reduced motion.
9. Run every relevant QML test sequentially after QML edits and fix all new WARN/ERROR lines.
10. Run full relevant QML regression, Python backend tests, `qs -p .`, and `git diff --check`.
11. Review for accidental API/network/business-data integration and ensure `.opencode/package.json` and `docs/image.png` remain untouched.

## Validation Commands

```sh
/usr/lib/qt6/bin/qmltestrunner -input tests/qml/<focused-test>.qml -o -,txt -v1
python -m unittest discover -s scripts/tests -v
timeout 12s qs -p .
git diff --check
```

## Risky Boundaries

- Per-screen `PanelWindow` ownership and fixed host geometry.
- Replacing existing settings/music overlay windows without breaking focus restoration.
- `ListView`/`GridView` clipping and mask ownership around the modal surface.
- Escape routing between page-local reversible state and host close.
- Static page components accidentally importing or triggering service/API requests.

## Review Gates

- Do not implement business data, network requests, or real page persistence.
- Do not create one fullscreen window per static page.
- Do not use `width`/`height` for Wlr layer-shell host sizing where `implicitWidth`/`implicitHeight` is required.
- Do not report visual similarity based only on colors; verify hierarchy and layout structure.
