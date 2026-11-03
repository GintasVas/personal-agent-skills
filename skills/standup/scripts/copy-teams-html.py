#!/usr/bin/env python3
"""Copy HTML onto the macOS clipboard as rich text so Teams pastes clickable links."""

from __future__ import annotations

import binascii
import re
import subprocess
import sys


def html_to_plain(html: str) -> str:
    text = re.sub(r"<br\s*/?>", "\n", html, flags=re.I)
    text = re.sub(r"</p\s*>", "\n\n", text, flags=re.I)
    text = re.sub(r"<[^>]+>", "", text)
    text = (
        text.replace("&nbsp;", " ")
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", '"')
    )
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def applescript_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def copy_html(html: str) -> None:
    hexdata = binascii.hexlify(html.encode("utf-8")).decode("ascii")
    plain = html_to_plain(html)
    script = (
        "set the clipboard to {«class HTML»:«data HTML"
        + hexdata
        + "», string:"
        + applescript_string(plain)
        + "}"
    )
    subprocess.run(["osascript", "-e", script], check=True)


def main() -> int:
    html = sys.stdin.read()
    if not html.strip():
        print("copy-teams-html.py: empty stdin", file=sys.stderr)
        return 1
    copy_html(html)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
