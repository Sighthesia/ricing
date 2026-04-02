---
name: reference-attribution
description: Use when adapting code, templates, config patterns, or architecture from another repository and you need to document attribution consistently in DymicShell.
---

# Reference Attribution

Document external inspiration directly in the touched file when the implementation or template is adapted from another repository.

## When To Add Attribution

- Adapted code structure, template layout, or config schema from another repository.
- Reused a known pattern closely enough that a maintainer would benefit from the origin.
- Added a helper script or generated-config wiring inspired by another project.

Do not add attribution for broad ecosystem conventions that are not traceable to one clear source.

## Required Content

- Repository or project name.
- Direct URL to the repository, or the most relevant file if stable.
- Short wording such as `Reference:` or `Inspired by:`.

## Placement

- Put attribution at the top of the file when the whole file is adapted.
- Put attribution immediately above the relevant block when only one section is adapted.
- Keep the note short; it should explain origin, not history.

## Comment Syntax

- Shell, Python, TOML, Kitty, YAML: `#`
- QML, JS, KDL: `//`
- CSS: `/* ... */`
- INI or `.colors`: `#` or `;`

## Examples

```toml
# Reference: Noctalia Shell
# https://github.com/noctalia-dev/noctalia-shell
```

```css
/*
 * Reference: InioX/matugen-themes
 * https://github.com/InioX/matugen-themes
 */
```

```qml
// Inspired by: upstream-project
// https://github.com/example/upstream-project
```

## DymicShell Rule

- If a user explicitly asks for attribution, every adapted file in the change must carry it.
- Prefer referencing the upstream repository once per adapted file instead of repeating many links inline.
- Keep attribution comments valid for the target file format so generated configs remain loadable.
