#!/usr/bin/env python3
"""Build the single-file Apps Script bundle for the Rumman Calculator backend.

Output (both generated, never edit by hand):
  backend/dist/Code.gs          = sheets/setup.gs + backend/src/*.gs
                                  (Config.gs and Util.gs first, the rest sorted by name)
  backend/dist/appsscript.json  = copy of backend/appsscript.json

The order matches the Node test harness (backend/test/harness.js), so what is tested is what is
deployed. The build fails if two files declare the same top-level name, because Apps Script loads
every file into one global scope and a duplicate `const`/`let`/`class` breaks the whole project.

Usage:  python3 backend/build.py
"""
from __future__ import annotations

import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SETUP = ROOT / "sheets" / "setup.gs"
SRC = ROOT / "backend" / "src"
MANIFEST = ROOT / "backend" / "appsscript.json"
DIST = ROOT / "backend" / "dist"
FIRST = ["Config.gs", "Util.gs"]

HEADER = """\
/**
 * حاسبة الرمان — الخادم (Google Apps Script)
 *
 * ملف مولَّد تلقائيًا بواسطة backend/build.py — لا تعدّله يدويًا.
 * المصادر: sheets/setup.gs ثم backend/src/*.gs (Config.gs وUtil.gs أولًا ثم الباقي بالترتيب الأبجدي).
 * العقد: docs/API.md. خطوات النشر: backend/DEPLOY.md.
 *
 * GENERATED FILE — do not edit. Edit sheets/build_sheet.py or backend/src/*.gs and run
 * `python3 backend/build.py` again.
 */
"""

DECL = re.compile(r"^(?:const|let|var|function|class)\s+([A-Za-z_$][\w$]*)", re.M)


def ordered_sources() -> list[Path]:
    names = sorted(p.name for p in SRC.glob("*.gs"))
    head = [n for n in FIRST if n in names]
    rest = [n for n in names if n not in head]
    return [SETUP] + [SRC / n for n in head + rest]


def check_duplicates(files: list[Path]) -> None:
    seen: dict[str, Path] = {}
    problems = []
    for f in files:
        for name in DECL.findall(f.read_text(encoding="utf-8")):
            if name in seen and seen[name] != f:
                problems.append(f"{name}: {seen[name].relative_to(ROOT)} and {f.relative_to(ROOT)}")
            seen.setdefault(name, f)
    if problems:
        sys.exit("Duplicate top-level declarations:\n  " + "\n  ".join(problems))


def main() -> None:
    if not SETUP.exists():
        sys.exit(f"Missing {SETUP.relative_to(ROOT)} (run sheets/build_sheet.py first).")
    files = ordered_sources()
    if len(files) == 1:
        sys.exit(f"No backend sources in {SRC.relative_to(ROOT)}.")
    check_duplicates(files)
    json.loads(MANIFEST.read_text(encoding="utf-8"))  # must be valid JSON

    parts = [HEADER]
    for f in files:
        rel = f.relative_to(ROOT).as_posix()
        body = f.read_text(encoding="utf-8").rstrip() + "\n"
        parts.append(f"\n// {'=' * 92}\n// المصدر: {rel}\n// {'=' * 92}\n\n{body}")
    DIST.mkdir(parents=True, exist_ok=True)
    out = DIST / "Code.gs"
    out.write_text("".join(parts), encoding="utf-8")
    shutil.copyfile(MANIFEST, DIST / "appsscript.json")
    size_kb = out.stat().st_size / 1024
    print(f"Wrote {out.relative_to(ROOT)} ({len(files)} files, {size_kb:.0f} KB) and {(DIST / 'appsscript.json').relative_to(ROOT)}")


if __name__ == "__main__":
    main()
