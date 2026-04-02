#!/usr/bin/env python3
import re, sys, pathlib


def normalize_channels(text: str) -> str:
    pattern = re.compile(r"(red|green|blue|alpha):\s*([0-9]+(?:\.[0-9]+)?)")

    def repl(m):
        channel = m.group(1)
        value = float(m.group(2))
        if channel == "alpha":
            return f"{channel}: {1.0 if value > 1 else value}"
        if value > 1:
            return f"{channel}: {value / 255.0}"
        return m.group(0)

    return pattern.sub(repl, text)


def main():
    if len(sys.argv) < 2:
        print("Usage: cosmic_postprocess.py <file>", file=sys.stderr)
        sys.exit(1)
    path = pathlib.Path(sys.argv[1]).expanduser()
    data = path.read_text()
    new = normalize_channels(data)
    path.write_text(new)


if __name__ == "__main__":
    main()
