#!/usr/bin/env python3
"""Build a release's notes from the changelog the repo already keeps.

The notes are generated at release time from `CHANGELOG.md` rather than typed
into the workflow, so they cannot drift from the changelog the app itself shows.
The body is plain markdown — headings, bullets, bold — because the app renders
it itself and has no HTML in its notes view, so an accordion arrived on the
phone as literal `<details>` text. A short summary opens then
overview and keeps each section collapsed until it is wanted.

    tool/release_notes.py --match 0.5.0 --title v0.5.0   # notes on stdout
    tool/release_notes.py --self-test                    # assert the parser

The changelog headings look like `## 0.5.0+30`; `--match 0.5.0` takes the
newest section for that version, so a build bump does not need a new heading.
"""
from __future__ import annotations

import argparse
import re
import sys

DEFAULT_REPO = "tab-gl/AceMail"
DEFAULT_CHANGELOG = "CHANGELOG.md"

_HEADING = re.compile(r"^##\s+(?P<version>\S+)\s*$")
_SUBSECTION = re.compile(r"^###\s+(?P<title>.+?)\s*$")


def section_for(text: str, match: str) -> str | None:
    """The body of the first `## <match>...` section, or None."""
    lines = text.splitlines()
    start = None
    for index, line in enumerate(lines):
        heading = _HEADING.match(line)
        if heading and heading.group("version").startswith(match):
            start = index + 1
            break
    if start is None:
        return None

    end = len(lines)
    for index in range(start, len(lines)):
        if lines[index].startswith("## "):
            end = index
            break
    return "\n".join(lines[start:end]).strip()


def split_subsections(body: str) -> tuple[str, list[tuple[str, str]]]:
    """(intro, [(title, content)]) for one version's section."""
    intro: list[str] = []
    parts: list[tuple[str, list[str]]] = []
    for line in body.splitlines():
        heading = _SUBSECTION.match(line)
        if heading:
            parts.append((heading.group("title"), []))
        elif parts:
            parts[-1][1].append(line)
        else:
            intro.append(line)
    return (
        "\n".join(intro).strip(),
        [(title, "\n".join(content).strip()) for title, content in parts],
    )


def _bullets(content: str) -> int:
    return sum(1 for line in content.splitlines() if line.startswith("- "))


def render(title: str, version: str, repo: str, body: str | None) -> str:
    """The release body: an overview, then one accordion per section."""
    out: list[str] = []

    if body is None:
        # A tag with no changelog entry still gets notes that say so, rather
        # than an empty body or someone else's.
        out.append(f"No changelog entry for `{version}` was found.")
        out.append("")
        out.append(
            f"See the [changelog](https://github.com/{repo}/blob/main/CHANGELOG.md)."
        )
        return "\n".join(out) + "\n"

    intro, parts = split_subsections(body)

    out.append(f"### What changed in {version}")
    out.append("")
    if intro:
        out.append(intro)
        out.append("")

    if parts:
        summary = " · ".join(
            f"**{name}** {_bullets(content)}" for name, content in parts
        )
        out.append(summary)
        out.append("")

    # Plain markdown, not an HTML accordion. The accordion is lovely on GitHub
    # and unreadable everywhere else — the app's own notes view has no HTML in
    # it by design, so `<details>` arrived on the phone as literal text, and so
    # did every `<b>`.
    for name, content in parts:
        out.append(f"#### {name} ({_bullets(content)})")
        out.append("")
        out.append(content)
        out.append("")

    out.append("---")
    out.append("")
    out.append(
        f"Full history: [CHANGELOG.md](https://github.com/{repo}/blob/main/CHANGELOG.md)."
    )
    return "\n".join(out).rstrip() + "\n"


def _self_test() -> int:
    sample = (
        "# Changelog\n\n"
        "## 0.9.9+1\n\n"
        "### Added\n"
        "- One thing\n"
        "- Another\n\n"
        "### Fixed\n"
        "- A bug\n\n"
        "## 0.9.8+1\n\n"
        "### Added\n"
        "- Older\n"
    )
    body = section_for(sample, "0.9.9")
    assert body is not None, "section not found"
    intro, parts = split_subsections(body)
    assert intro == "", f"unexpected intro: {intro!r}"
    assert [name for name, _ in parts] == ["Added", "Fixed"], parts
    assert _bullets(parts[0][1]) == 2 and _bullets(parts[1][1]) == 1

    notes = render("v0.9.9", "0.9.9+1", DEFAULT_REPO, body)
    assert "#### Added (2)" in notes and "#### Fixed (1)" in notes
    assert "<details>" not in notes and "<b>" not in notes
    assert "Older" not in notes, "leaked the next section"
    assert section_for(sample, "0.0.0") is None
    assert "No changelog entry" in render("v0.0.0", "0.0.0", DEFAULT_REPO, None)
    print("release_notes: self-test ok", file=sys.stderr)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--match", help="version to match, e.g. 0.5.0")
    parser.add_argument("--title", default="", help="release title, e.g. v0.5.0")
    parser.add_argument("--version", default="", help="full version, e.g. 0.5.0+30")
    parser.add_argument("--repo", default=DEFAULT_REPO)
    parser.add_argument("--changelog", default=DEFAULT_CHANGELOG)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        return _self_test()

    match = args.match or args.title.lstrip("v")
    version = args.version or match
    if not match:
        parser.error("one of --match, --title or --version is required")

    try:
        text = open(args.changelog, encoding="utf-8").read()
    except OSError:
        text = ""

    sys.stdout.write(render(args.title or version, version, args.repo, section_for(text, match)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
