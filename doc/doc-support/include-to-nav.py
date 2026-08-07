#!/usr/bin/env python3
"""One-shot conversion of the `{=include=}` tree in doc/ into doc/nav.json.

Run once from the repository root:

    python3 doc/doc-support/include-to-nav.py

Every include block that the `--experimental-config` format can express is
removed from the Markdown sources and re-expressed as a nav.json node. Blocks
carrying arguments (and `options` blocks) are not expressible and stay in place.

A file that carries prose and also includes children becomes a group whose
first child is the file itself, so its prose and its anchor survive as a page.
"""

import json
import re
import sys
from pathlib import Path

DOC = Path(__file__).resolve().parent.parent
ROOT = DOC / "manual.md.in"

INCLUDE_RE = re.compile(r"^```\{=include=\}(?P<rest>.*)$")
FENCE_RE = re.compile(r"^(```|~~~)")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*(?:\{#([^}]+)\})?\s*$")


class Include:
    kind = "include"

    def __init__(self, typ, args, files, start, end):
        self.typ = typ
        self.args = args
        self.files = files
        self.start = start
        self.end = end

    def convertible(self):
        return self.typ != "options" and not self.args


class Heading:
    kind = "heading"

    def __init__(self, level, title, anchor):
        self.level = level
        self.title = title
        self.anchor = anchor


def lex(src):
    """Split a Markdown source into include blocks and headings."""
    lines = src.splitlines()
    items = []
    fenced = False
    i = 0
    while i < len(lines):
        line = lines[i]
        m = INCLUDE_RE.match(line)
        if m and not fenced:
            typ, *args = m.group("rest").split()
            end = i + 1
            while end < len(lines) and not lines[end].startswith("```"):
                end += 1
            if end == len(lines):
                sys.exit(f"unterminated include block at line {i + 1}")
            files = [f.strip() for f in lines[i + 1 : end] if f.strip()]
            items.append(Include(typ, args, files, i, end))
            i = end + 1
            continue
        if FENCE_RE.match(line):
            fenced = not fenced
            i += 1
            continue
        if not fenced:
            m = HEADING_RE.match(line)
            if m:
                items.append(Heading(len(m.group(1)), m.group(2), m.group(3)))
        i += 1
    return items


def read_source(p):
    """Return (text, actual path). Generated files only exist as `.md.in`."""
    if p.exists():
        return p.read_text(), p
    generated = Path(str(p) + ".in")
    if generated.exists():
        return generated.read_text(), generated
    sys.exit(f"{p}: include target not found")


visited = set()
rewrites = {}
group_ids = set()


def walk(p):
    if p in visited:
        sys.exit(f"{p}: reached twice")
    visited.add(p)

    text, actual = read_source(p)
    items = lex(text)
    blocks = [it for it in items if it.kind == "include" and it.convertible()]
    children = [walk((p.parent / f).resolve()) for b in blocks for f in b.files]
    rel = p.relative_to(DOC).as_posix()

    if not children:
        return {"file": rel}

    rewrites[actual] = [(b.start, b.end) for b in blocks]

    title = next((it for it in items if it.kind == "heading" and it.level == 1), None)
    if title is None:
        sys.exit(f"{p}: no level-1 heading to label its group")
    if not title.anchor:
        sys.exit(f"{p}: level-1 heading has no id")
    if title.anchor in group_ids:
        sys.exit(f"{p}: duplicate group id {title.anchor}")
    group_ids.add(title.anchor)

    return {
        "label": title.title.replace("`", ""),
        "id": title.anchor,
        "children": [{"file": rel}] + children,
    }


def rewrite(path, blocks):
    lines = path.read_text().splitlines()
    for s, e in sorted(blocks, reverse=True):
        del lines[s : e + 1]
        if 0 < s < len(lines) and not lines[s - 1].strip() and not lines[s].strip():
            del lines[s]
    while lines and not lines[-1].strip():
        lines.pop()
    path.write_text("\n".join(lines) + "\n")


def main():
    nav = DOC / "nav.json"
    if json.loads(nav.read_text())["items"]:
        sys.exit("nav.json already has items; refusing to run")

    root = walk(ROOT)
    # Drop the manual.md.in self-leaf: title and subtitle stay in --infile.
    items = root["children"][1:]

    nav.write_text(json.dumps({"open": [], "items": items}, indent=2) + "\n")
    for path, blocks in rewrites.items():
        rewrite(path, blocks)

    leaves = sum(1 for _ in re.finditer(r'"file"', nav.read_text()))
    print(f"{len(items)} top-level items, {leaves} leaves, {len(group_ids)} groups")
    print(f"rewrote {len(rewrites)} sources")


if __name__ == "__main__":
    main()
