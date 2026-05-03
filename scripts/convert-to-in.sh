#!/usr/bin/env bash
# convert-to-in.sh — one-shot Phase 4 / Phase 10 conversion tool.
#
# Walks a target component repo, discovers Lambda function directories
# that need conversion to the .in/.txt pattern, and writes a
# `requirements.in` for each. Refuses to overwrite an existing `.in`.
# Does not modify the legacy `requirements.txt` (that gets overwritten
# by `compile-requirements` next).
#
# Discovery rule: the union of
#   (a) every dir containing an existing `requirements.txt`, and
#   (b) every dir whose `.py` files import boto3 or botocore but lacks
#       `requirements.txt` and `requirements.in`.
# Uses the same exclusion list as `_requirements_lib.sh`
# (REQ_LIB_EXCLUDE_DIRS).
#
# Conversion rule per dir:
#   - If any `.py` imports boto3/botocore: `-r <relpath>/boto3.in`,
#     where <relpath> is the `..`-count from the dir to the repo root.
#   - For each non-boto3 dep in the existing `requirements.txt`
#     (`name==X.Y.Z`): emit `name>=X.Y.Z,<<X+1>>.0.0`.
#   - Pure stdlib (no boto3 imports, empty/missing legacy txt): no
#     `.in` written. Stale `.txt` left in place; maintainer handles.
#
# Usage:
#   convert-to-in.sh [--dry-run] <target-repo>
#
# Tooling: requires `uv` on PATH (uses uv-shipped Python 3.11+ stdlib).

set -euo pipefail

DRY_RUN=0
TARGET=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        -h|--help)
            sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        --) shift; break ;;
        -*) echo "unknown flag: $1" >&2; exit 2 ;;
        *)  TARGET="$1"; shift ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    echo "usage: convert-to-in.sh [--dry-run] <target-repo>" >&2
    exit 2
fi
if [[ ! -d "$TARGET" ]]; then
    echo "target is not a directory: $TARGET" >&2
    exit 2
fi
if ! command -v uv >/dev/null 2>&1; then
    echo "uv is not on PATH" >&2
    exit 2
fi

uv run --no-project --quiet --python ">=3.11" python - "$TARGET" "$DRY_RUN" <<'PY'
import re, sys
from pathlib import Path

target_root = Path(sys.argv[1]).resolve()
dry_run = sys.argv[2] == "1"

# Same exclusion list as _requirements_lib.sh REQ_LIB_EXCLUDE_DIRS.
EXCLUDE_DIRS = {
    ".git", ".aws-sam", ".venv", "venv",
    "node_modules", "__pycache__", ".pytest_cache",
}

# Convert-to-in-specific exclusions:
# - `tests/` subtrees: tests import boto3 for mocking but are not
#   deployment units; they don't need a requirements.in.
# - `scripts/`: refresh-distributed maintainer tooling (deploy.py
#   imports boto3) — not a deployment unit. Same case refresh.zsh
#   prunes for its own boto3-import detection (§4.9).
# Both exclusions are local to convert-to-in's discovery heuristic;
# the general-purpose walkers in _requirements_lib.sh do NOT exclude
# them (a `.in` placed deliberately under either would still be
# honoured by the gate).
CONVERT_EXCLUDE_PARTS = EXCLUDE_DIRS | {"tests", "scripts", "site-packages"}

IMPORT_RE = re.compile(
    r"^\s*(?:import|from)\s+(?:boto3|botocore)\b", re.MULTILINE
)
# Matches a requirements line: package name + version specifier.
# Captures (name, specifier). Specifier covers any PEP 440 form:
#   ==X.Y.Z (exact pin), >=X.Y.Z,<W.0.0 (range), >=X.Y.Z (no upper),
#   ~=X.Y (compatible release), etc.
TXT_LINE_RE = re.compile(r"^([A-Za-z0-9._-]+)\s*([<>=!~].+?)(?:\s*#.*)?$")
EXACT_PIN_RE = re.compile(r"^==\s*([0-9][0-9A-Za-z.+-]*)$")

def walk(root: Path):
    """Yield every file under root, skipping CONVERT_EXCLUDE_PARTS."""
    for path in root.rglob("*"):
        if any(part in CONVERT_EXCLUDE_PARTS for part in path.parts):
            continue
        yield path

def imports_boto(dir_path: Path) -> bool:
    """True iff the dir's own .py files import boto3/botocore.
    Non-recursive — descendant dirs are separate function dirs in their
    own right; a parent directory only used as a Python-package
    container (e.g. functions/__init__.py) must not be flagged via
    its descendants' imports."""
    for py in dir_path.glob("*.py"):
        try:
            text = py.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        if IMPORT_RE.search(text):
            return True
    return False

def parse_legacy_txt(txt_path: Path):
    """Return list of (name, specifier_string) for non-boto3 deps.
    Specifier is whatever the legacy line had — exact pin (==X.Y.Z),
    range (>=X.Y.Z,<W.0.0), etc. Renderer decides whether to widen."""
    deps = []
    if not txt_path.exists():
        return deps
    for line in txt_path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or line.startswith("-"):
            continue
        m = TXT_LINE_RE.match(line)
        if not m:
            continue
        name = m.group(1)
        if name.lower() in ("boto3", "botocore"):
            continue
        deps.append((name, m.group(2).strip()))
    return deps

def relpath_to_repo_root(dir_path: Path) -> str:
    """`../..`-style string from dir_path up to target_root."""
    rel = dir_path.relative_to(target_root)
    return "/".join([".."] * len(rel.parts))

def next_major_bound(version: str) -> str:
    """Given X.Y.Z, return (X+1).0.0 — used for the upper bound."""
    parts = version.split(".")
    try:
        major = int(parts[0])
    except (ValueError, IndexError):
        return version  # fallback; maintainer will need to fix
    return f"{major + 1}.0.0"

def render_requirements_in(dir_path: Path):
    """Compute the .in content for a dir, or None if no .in is needed."""
    boto = imports_boto(dir_path)
    deps = parse_legacy_txt(dir_path / "requirements.txt")
    if not boto and not deps:
        return None
    lines = []
    if boto:
        rel = relpath_to_repo_root(dir_path)
        lines.append(f"-r {rel}/boto3.in" if rel else "-r boto3.in")
    for name, spec in deps:
        # Exact pin -> widen to >=X.Y.Z,<(X+1).0.0; otherwise keep
        # the legacy spec verbatim (already a range, maintainer's
        # judgment is preserved).
        m = EXACT_PIN_RE.match(spec)
        if m:
            ver = m.group(1)
            upper = next_major_bound(ver)
            lines.append(f"{name}>={ver},<{upper}")
        else:
            lines.append(f"{name}{spec}")
    return "\n".join(lines) + "\n"

# Discovery — set A (legacy txt) and set B (boto3 imports without
# requirements files). Walk once, build both.
set_a = set()  # dirs with requirements.txt
set_b = set()  # dirs with .py files (candidates for boto3-import detection)
has_in = set() # dirs with requirements.in (excluded from set B)

for path in walk(target_root):
    if not path.is_file():
        continue
    name = path.name
    parent = path.parent
    if name == "requirements.txt":
        set_a.add(parent)
    elif name == "requirements.in":
        has_in.add(parent)
    elif name.endswith(".py"):
        set_b.add(parent)

# Set B becomes: dirs with boto3 imports, lacking both .txt and .in.
set_b_filtered = set()
for d in set_b:
    if d in set_a or d in has_in:
        continue
    if imports_boto(d):
        set_b_filtered.add(d)

candidates = sorted(set_a | set_b_filtered)

if not candidates:
    print(f"no candidate directories found under {target_root}")
    sys.exit(0)

print(f"convert-to-in: {len(candidates)} candidate dir(s) under {target_root}")
if dry_run:
    print("(dry-run mode — no files will be written)")
print()

written = 0
skipped_existing = 0
skipped_stdlib = 0

for d in candidates:
    in_path = d / "requirements.in"
    rel_display = d.relative_to(target_root)
    if in_path.exists():
        print(f"  · {rel_display}/requirements.in  (already exists, skipping)")
        skipped_existing += 1
        continue
    content = render_requirements_in(d)
    if content is None:
        print(f"  · {rel_display}  (pure stdlib, no .in needed)")
        skipped_stdlib += 1
        continue
    if dry_run:
        print(f"  → {rel_display}/requirements.in  (would write):")
        for line in content.splitlines():
            print(f"        {line}")
    else:
        in_path.write_text(content, encoding="utf-8")
        print(f"  ✓ {rel_display}/requirements.in")
    written += 1

print()
print(f"  candidates:        {len(candidates)}")
print(f"  written:           {written}{'  (dry-run)' if dry_run else ''}")
print(f"  skipped (exists):  {skipped_existing}")
print(f"  skipped (stdlib):  {skipped_stdlib}")
PY
