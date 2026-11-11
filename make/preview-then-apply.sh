#!/usr/bin/env bash
# Used by the Makefile: show a script's dry run, then ask before running it again with --apply.
#
#   make/preview-then-apply.sh ./shield-debloat.sh [args...]
#
# If the dry run has nothing to change, it doesn't ask.
set -euo pipefail

preview=$(mktemp)
trap 'rm -f "$preview"' EXIT

"$@" | tee "$preview"
if ! grep -q '^[[:space:]]*would' "$preview"; then echo; echo "Nothing to apply."; exit 0; fi
if "$(dirname "$0")/ask.sh" "Apply these changes?"; then "$@" --apply; fi
