# Context

- User-reported bug: the center dockzone ear implementation differs from left/right and forms a visible inverted-trapezoid overlap inside the body.
- Visible symptom: semi-transparent center surface becomes darker inside the body because multiple fills stack in the same region.
- Scope: fix the center dockzone only, preserving the current left/right dockzone silhouette and behavior.
- Primary implementation file: `modules/island/IslandBody.qml`
- Reference behavior: `modules/bar/DockzoneSurfaceRoot.qml` paints the dockzone body as a single shape instead of layering a top flattening fill.
- Follow-up user correction: left/right dockzone ear blur works after the bar blur refactor, but the center dockzone/island ears still do not blur.
- Current center owner: center visible surface is `modules/island/IslandBody.qml`, not the hidden `BarContent.centerSection`, so center blur must be exposed from island geometry.
- Updated scope: touch `modules/island/IslandBody.qml` and `modules/island/IslandWindow.qml`; keep the already-working left/right bar dockzone blur unchanged.
- Expected result: center body and both top ears contribute geometry-aligned blur parts, using rectangle-strip ear regions rather than unsupported subtract/ellipse regions.
