Read [AGENTS.md](AGENTS.md) before starting any task.

This branch (`lazer`) contains the full shell: osu!lazer-styled frontend (`modules/`, `shell.qml`) plus the service/backend layer (`services/`, `scripts/`, `tests/qml/`).

## Skills

Load these for detailed context on specific topics:

| Skill | When to use |
|---|---|
| [osu-sharp-design-language](.agents/skills/osu-sharp-design-language/SKILL.md) | Creating or reshaping any visible QML element (surfaces, blocks, rows, controls, icons). Enforces the osu!lazer "sharp" visual language: sharp rectangles/geometry on major surfaces, rounded corners only on details. Load before adding any new UI shape. |
| [lazer-settings-surface-details](.agents/skills/lazer-settings-surface-details/SKILL.md) | When modifying the lazer settings panel, settings rows, reset-default button, category blocks, search strip, or their hover/press/motion behavior. Preserves verified geometry, z-order, input isolation, and slide transition contracts. |
| [visual-transition-rules](.agents/skills/visual-transition-rules/SKILL.md) | When adjusting QML visual styles, colors, radii, opacity, blur, shadows, spacing, scale, or related presentation variables. |
| [qml-testing](.agents/skills/qml-testing/SKILL.md) | Running or writing tests. `qs -p` does not run QtTest; use the Qt6 qmltestrunner for logic tests and root-level harnesses for singleton services. |
| [active-window-live-sync](.agents/skills/active-window-live-sync/SKILL.md) | Active-window title or app identity stops updating after Niri focus, workspace, or event-stream changes. |
| [marquee-exit-ghosts](.agents/skills/marquee-exit-ghosts/SKILL.md) | Modifying marquee scrolling or diagnosing long titles whose old characters disappear instead of falling during a switch. |
