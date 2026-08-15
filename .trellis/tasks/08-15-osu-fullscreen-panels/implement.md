# Research Plan: osu Fullscreen Panels

## Ordered Steps

1. Capture the full shared base-class source and lifecycle paths.
2. Capture Wiki overlay, header, index, article, sidebar and markdown symbols.
3. Capture News overlay, header, sidebar, cards and pagination symbols.
4. Capture Beatmap listing overlay, header, filters, search, result layout, pagination and input tests.
5. Record exact file/line anchors for every major conclusion.
6. Build a cross-page comparison matrix.
7. Map osu mechanisms to Quickshell/QML equivalents and identify Afloat architectural gaps.
8. Write the final report under the task `research/` directory.
9. Review the report for unsupported visual claims, missing source anchors and accidental implementation scope.

## Validation

- Every architectural claim must point to at least one local source symbol.
- Unfinished or placeholder paths must be labelled.
- The report must not claim runtime behavior based only on class names.
- `git diff --check` must pass for research/task documentation.

## Modification Boundary

- Allowed: `.trellis/tasks/08-15-osu-fullscreen-panels/**`.
- Not allowed: osu source, Afloat product source, tests or assets.
