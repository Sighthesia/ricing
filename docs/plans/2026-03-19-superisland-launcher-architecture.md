# SuperIsland as Launcher Hub - Architecture Design Doc

**Date:** 2026-03-19

## Overview

Traditional Linux desktop environments use disjointed components for the status bar and the application launcher. Clicking a small icon on the bar abruptly spawns a large window in the center or corner of the screen. This jump lacks physical continuity. 

As part of the DymicShell vision, we are abandoning the "Panel + Window Popups" model. We will implement a **Monolithic Growth Component** architecture, utilizing the exact center of the screen — the **SuperIsland**, as the physical origin of the Launcher. When clicked, the SuperIsland will physically stretch and expand out of the Wayland bar's boundary to become the Launcher itself. 

## 1. Interaction Modality & Visual Metaphor

*   **Trigger:** User clicks on the SuperIsland baseline (or presses Super key) when in its idle/clock state.
*   **Expansion (Pivot Growth):** The island component visually swells out of its narrow horizontal constraints, growing in both width and height to form a floating, centered canvas (approx. 1/3 of the screen). 
*   **Modality - Local Floating Non-Modal:** The expanded launcher does not block the entire screen with a heavily blurred dim-layer. Other parts of the desktop remain visible. Niri windows underneath stay in place.
*   **Dismissal:** Clicking anywhere outside the expanded area, or pressing Escape, fluidly collapses the giant panel back into the tiny Pill clock.

## 2. Technical Architecture: "Popup Disguise" (Popup 连体伪装)

Due to Wayland protocol limitations, a thin, top-aligned Layer Shell window (the Bar) cannot drastically change its geometry to a large square without causing tearing and relayout chaos with the compositor.

To bypass this, we use the **Pivot Growth Trick (Popup 连体伪装)**:

1.  **The Anchor (SuperIslandWidget):** Remains a small component in `shell.qml` -> `Bar`. When triggered, it emits `requestExplode(sourceRect)`, transferring its absolute screen coordinates, and hides its own content (becoming fully transparent).
2.  **The Growth Stage (Global Overlay):** A separate Quickshell `PanelWindow` (or appropriately sized temporary window) acts as an invisible overlay stage perfectly aligned with the screen center. 
3.  **The Illusion:** Inside the Growth Stage, a placeholder rectangle perfectly matches the SuperIsland's small `sourceRect` geometry. It then immediately applies `Theme.anim.spring` to interpolate its `width`, `height`, and `radius`, stretching out. To the user's eye, the SuperIsland itself has grown. 

## 3. Component Boundary & State-Folding (SRP)

If we shove a full application grid, search indexing, and D-Bus DBusMenu logic into `SuperIslandWidget.qml`, it would violate the 300-line limit and become an unmaintainable monolith. 

We isolate the heavy logic from the visual growth:

*   **`modules/bar/widgets/SuperIslandWidget.qml` (The Trigger):** Renders the idle pill. Triggers expansion. Ignorant of Launcher logic.
*   **`modules/launcher/LauncherExpandedContent.qml` (The Payload):** The heavy UI (App grid, search bar) injected dynamically into the expanded stage. Loaded on-demand. 
*   **`services/SuperIslandService.qml` (The Arbitrator):** Coordinates the state transition (`"idle"` -> `"expanding"` -> `"launcher_open"`). 
*   **`services/LauncherService.qml`:** Handles the actual app search and desktop-entry data, completely decoupled from the UI. 

## 4. Conflict Resolution & Priority

The SuperIsland currently handles Media transients and Niri weak-hints.
*   **Launcher Priority:** Expanding the Launcher is an explicit, high-intent user action. It overrides any ongoing weak-hints or transients. If a notification arrives while the Launcher is open, the notification should be deferred or shown elsewhere (since the island is currently huge). 
*   **State Locking:** `SuperIslandService` will introduce a lock state. While `State == EXPLODED_LAUNCHER`, no other services can queue round-trip animations on the island.

## 5. Implementation Path (Next Steps)

1.  Create `LauncherExpandedContent.qml`.
2.  Modify `shell.qml` or Bar layer to host the `GrowthStage` floating panel.
3.  Implement coordinate transfer and the `Theme.anim.spring` expansion geometry animation.
4.  Wire `SuperIslandWidget` single-click to trigger the expansion.