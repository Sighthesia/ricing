"""Source-level guard against QML binding cycles in the audio panel components.

A polish loop is invisible to every other tier: the components load, the values
settle to the right numbers, and the whole QML suite stays green, because nothing
about a loop makes an assertion fail. What it does is re-polish the same items on
every frame - so the popup costs CPU continuously while open, and the scene graph
fills the log with `possible QQuickItem::polish() loop`. That is exactly how the
volume panel shipped once: the header Row's scope text measured its own width
against the Row's width (which is the sum of its children's widths), and the Row
also wrote the `y` of children that anchored their `y` themselves.

Neither shape is wrong-looking, so both are checked here rather than left to
review. The rule is deliberately narrow - it flags the two cycles actually seen,
not every use of a positioner.
"""

import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[2]

# The components that make up the volume panel. The panel body itself is far too
# large to scan usefully; these are the ones with hand-laid-out rows.
AUDIO_PANEL_COMPONENTS = [
    REPO / "modules" / "bar" / "BarAudioLevelRow.qml",
    REPO / "modules" / "bar" / "BarAudioDeviceList.qml",
    REPO / "modules" / "BarAudioMixer.qml",
    REPO / "modules" / "bar" / "BarAudioMixer.qml",
]

AUDIO_PANEL_COMPONENTS = [path for path in AUDIO_PANEL_COMPONENTS if path.exists()]


def _strip_comments(source: str) -> str:
    """Drop `//` comments so prose about a pattern cannot trip the pattern."""
    return "\n".join(
        re.sub(r"//.*$", "", line, flags=re.IGNORECASE) for line in source.split("\n")
    )


def _blocks(source: str, keyword: str):
    """Yield (body, brace_depth_at_open) for every `keyword { ... }` block."""
    for match in re.finditer(r"\b" + keyword + r"\s*\{", source):
        depth = 0
        for index in range(match.end() - 1, len(source)):
            char = source[index]
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    yield source[match.end():index]
                    break


def test_components_exist():
    assert AUDIO_PANEL_COMPONENTS, "no audio panel components were found to scan"


def test_no_width_measured_against_a_positioners_width():
    # Row.width / Column.width is the sum of its children's widths, so a child
    # that measures its own width against it closes the loop:
    # row.width -> child.width -> row.width.
    pattern = re.compile(r"\bwidth\s*:.*\b(row|column|grid)\w*\.\s*width\b")
    offenders = []
    for path in AUDIO_PANEL_COMPONENTS:
        source = _strip_comments(path.read_text(encoding="utf-8"))
        for line_number, line in enumerate(source.split("\n"), start=1):
            if pattern.search(line):
                offenders.append(f"{path.name}:{line_number}: {line.strip()}")
    assert not offenders, "width measured against a positioner's width:\n" + "\n".join(offenders)


def test_positioners_do_not_hold_anchor_managed_y_children():
    # A positioner writes its children's `y` during polish. A child that anchors
    # its own `y` writes the same property in the same pass, and Qt re-polishes
    # forever. The two only ever agree by coincidence, when the siblings happen
    # to be the same height.
    pattern = re.compile(r"anchors\.(vertical|horizontal)Center")
    offenders = []
    for path in AUDIO_PANEL_COMPONENTS:
        source = _strip_comments(path.read_text(encoding="utf-8"))
        for body in _blocks(source, "Row"):
            for line in body.split("\n"):
                if pattern.search(line):
                    offenders.append(f"{path.name}: {line.strip()}")
    assert not offenders, (
        "anchored centring inside a positioner, which fights it for y/x:\n"
        + "\n".join(offenders)
    )


def test_panel_components_declare_no_positioners_at_all():
    # Stronger than the check above, and the state these three components are
    # meant to be in: every row in the panel is hand-laid-out from both edges,
    # because that is what makes the boxes provably non-overlapping. A Row is the
    # obvious way to reintroduce a positioner-managed axis, so its return is
    # treated as a regression rather than a style choice.
    for path in AUDIO_PANEL_COMPONENTS:
        source = _strip_comments(path.read_text(encoding="utf-8"))
        found = re.findall(r"^\s*\b(Row|Column|Grid)\s*\{", source, flags=re.MULTILINE)
        assert not found, f"{path.name} reintroduced a positioner: {found}"