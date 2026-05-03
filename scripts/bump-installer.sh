#!/usr/bin/env bash
# bump-installer.sh — reconcile the Installer's own supply chain after
# editing `requirements.in` or `templates/boto3.in`.
#
# Workflow:
#   1. edit requirements.in (or templates/boto3.in for shared boto3 pin)
#   2. ./bump-installer       (this script — runs compile + verify + render)
#   3. inspect git status, commit, push
#
# Options:
#   --dry-run     Skip the compile step; run the read-only verification
#                 against the currently-committed lock and confirm
#                 SECURITY.md is up-to-date with the template + config.
#                 Working tree is not modified. Useful for confirming
#                 "is my committed state still gate-clean today?"
#                 without intending to bump anything.
#
# This is an Installer-only convenience wrapper — it is intentionally
# NOT listed in the SCRIPTS=() array of refresh.zsh, so it stays
# resident in the Installer repo and does not get distributed to
# component repos (which use ./compile-requirements + ./publish
# directly per their existing workflow).
#
# All steps run in sequence; any failure halts immediately and
# preserves the working-tree state for inspection.

set -euo pipefail

DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        -h|--help)
            sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "unknown arg: $arg" >&2; exit 2 ;;
    esac
done

# Resolve symlinks so this works whether invoked as ./bump-installer
# (top-level convenience symlink) or scripts/bump-installer.sh.
_self="${BASH_SOURCE[0]}"
while [[ -L "$_self" ]]; do
    _link="$(readlink "$_self")"
    case "$_link" in
        /*) _self="$_link" ;;
        *)  _self="$(dirname "$_self")/$_link" ;;
    esac
done
cd "$(dirname "$_self")/.."
unset _self _link

# Sanity check: this only makes sense in the Installer repo.
if [[ ! -f requirements.in ]]; then
    echo "Error: no requirements.in at repo root."                          >&2
    echo "       bump-installer is for the Installer repo only."            >&2
    echo "       (component repos use ./compile-requirements + ./publish.)" >&2
    exit 2
fi

if [[ "$DRY_RUN" == true ]]; then
    echo "── verify-only (no compile, no write) ──"
    echo
    echo "── [1/2] verify committed lock (drift / CVE / hash / OSV / provenance) ──"
    scripts/_check-requirements.sh
    echo
    echo "── [2/2] verify SECURITY.md is current ──"
    scripts/_generate-security-md.sh --check
    echo
    echo "✓ Installer committed supply-chain state is gate-clean."
    exit 0
fi

echo "── [1/3] compile ──"
scripts/compile-requirements.sh

echo
echo "── [2/3] verify (drift / CVE / hash / OSV / provenance) ──"
scripts/_check-requirements.sh

echo
echo "── [3/3] render SECURITY.md ──"
scripts/_generate-security-md.sh

echo
echo "── git status ──"
git status --short

echo
echo "✓ Installer supply chain reconciled. Inspect the diff, commit, push."
