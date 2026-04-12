# Technical Notes

- Reuse the existing launcher detached outgoing layer in `modules/launcher/LauncherResultsList.qml`.
- Detect same-provider query refinement in `modules/launcher/LauncherCore.qml` and prefer the incremental sync path for that case.
- Keep broadening searches and provider switches on the current replace/expand logic unless the incremental path is already safe.
