# Clipboard Metadata Design

## Goal

Show useful metadata in launcher clipboard result descriptions without adding a
new decode or filesystem cold path.

## Behavior

- Text entries show the character count from the `cliphist list` preview.
- Long previews use a generic long-text label rather than presenting a count
  that may be truncated.
- Image entries parse the `cliphist` binary preview format:
  `[[ binary data <size> <format> <width>x<height> ]]`.
- Image titles show resolution; descriptions show format and size.
- If image metadata cannot be parsed, descriptions fall back to the MIME type.
- Existing clipboard timestamps remain part of the description.

## Scope

- Metadata parsing stays in the pure launcher adapter layer.
- No `cliphist decode`, image probing, or additional process is added to list
  rendering.
- Existing clipboard filtering, ordering, preview decoding, and execution
  behavior remain unchanged.

## Validation

- Unit-test text metadata for short and truncated previews.
- Unit-test image metadata parsing for valid and invalid preview strings.
- Keep launcher page and launcher service test suites passing.
