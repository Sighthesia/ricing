# Research Design: osu Fullscreen Panels

## Evidence Boundary

- Primary evidence: CodeGraph-indexed source under `/home/Sighthesia/0_Files/Producing/Software/Quickshell/osu`.
- Secondary evidence: visual and unit tests in the same repository where they clarify expected interaction.
- Afloat source is used only to frame QML transfer recommendations, not to redefine osu behavior.

## Analysis Model

1. Trace the common inheritance and composition spine.
2. Decompose each concrete overlay into header, navigation, body, state, data and motion.
3. Compare the three overlays in one matrix.
4. Translate mechanisms, not individual classes, into QML concepts.
5. Identify gaps between Afloat's current surface model and osu's persistent full-screen page model.

## Report Structure

- Executive finding: why the current Afloat UI feels unlike osu.
- Shared fullscreen architecture and lifecycle.
- Wiki implementation.
- News implementation.
- Beatmap listing implementation.
- Cross-page comparison matrix.
- QML mapping and recommended Afloat architecture.
- Migration priorities and risks.

## Important Distinctions

- Structural fidelity is more important than copying individual colours or radii.
- osu's drawable scene graph and dependency injection are not QML APIs; recommendations must preserve behavior using QML ownership and bindings.
- Source limitations and unfinished code must be stated explicitly.
