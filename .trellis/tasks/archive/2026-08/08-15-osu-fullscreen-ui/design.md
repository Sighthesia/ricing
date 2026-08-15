# Technical Design: osu-style Fullscreen UI

## Ownership

- `TopBar` remains the per-screen entry point and owns one persistent fullscreen `PanelWindow`.
- A single `FullscreenOverlayHost` owns route state, focus, modal input, backdrop, surface geometry and transition progress.
- `FullscreenHeader`, `FullscreenSidebar`, and `FullscreenPageViewport` are reusable visual slots.
- Static page components own only page-specific layout and local display state.
- Existing settings/music/notification surfaces are adapted at the route boundary; they do not create additional fullscreen owners.

## Route And State

```text
route: "" | "settings" | "music" | "wiki" | "news" | "beatmap"
phase: "closed" | "opening" | "open" | "closing"
selectedSidebarEntry: string
loading: bool
focusedRegion: "header" | "sidebar" | "content"
```

- `route` is the single source of truth for mutually exclusive fullscreen pages.
- `phase` controls visibility, input capture and close-complete cleanup.
- Static page data is local QML arrays/objects; no service request is made by page templates.
- Existing setting writes remain in settings pages; the new host only changes presentation ownership.

## Layout Contract

```text
PanelWindow (fixed screen size, non-exclusive)
└─ FullscreenOverlayHost
   ├─ Backdrop
   └─ Surface (fixed centered bounds)
      ├─ FullscreenHeader
      │  ├─ Title / icon
      │  └─ HeaderSlot(route)
      └─ PageViewport (clip)
         ├─ LoadingSlot
         └─ PageLayout
            ├─ SidebarSlot(route)
            └─ ContentSlot(route)
```

- Use a fixed outer host and animate the inner surface/content to avoid per-frame layer-shell resize.
- Sidebar width is stable; sidebar and content remain one layout owner, with independent scrolling only when explicitly needed.
- The host mask covers the actual surface, not the entire transparent screen window when closed.

## Page Templates

- `WikiLikePage`: breadcrumb header, table-of-contents sidebar, centered article blocks, mixed two-column/full-width panels.
- `NewsLikePage`: breadcrumb header, archive sidebar, stacked static cards with image/title/metadata hierarchy.
- `BeatmapLikePage`: title header, search/filter placeholders, dense card grid, card-size visual toggle.
- All templates consume the same `pageWidth`, `headerHeight`, `sidebarWidth`, `contentPadding`, `cardGap` and `motion` tokens.

## Input And Motion

- Inner focused Item owns `Keys.*`; `PanelWindow` stays a compositor surface only.
- Escape first delegates to the active page's reversible state, then returns to the host route, then closes.
- Backdrop click closes only while the host is interactive.
- Open/close animates opacity and surface translation/scale together; close completion clears the route and restores opener focus.
- Reduced motion sets translation/scale deltas to zero and keeps opacity/color transitions.

## Compatibility And Rollback

- Preserve existing service contracts and current QML singleton registration.
- New components can initially be mounted behind existing settings/music entry points; rollback is limited to route host and page template files.
- Existing notification host remains independent unless the new fullscreen route explicitly replaces it; avoid mixing transient notification masking with modal page masking.
