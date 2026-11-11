#!/usr/bin/env bash
# Used by the Makefile: ask a yes/no question. Exits 0 only if someone at a terminal says yes.
#
#   make/ask.sh "Switch to the stock launcher?" && ...
#
# Anything but y/yes, or no terminal at all (CI, a pipe), counts as no.
set -euo pipefail

if [ ! -t 0 ]; then echo "No terminal to ask on - nothing applied."; exit 1; fi
printf '\n%s [y/N] ' "$1"
read -r answer || answer=""
case "$answer" in
  [yY] | [yY][eE][sS]) exit 0 ;;
  *) echo "Nothing applied."; exit 1 ;;
esac
