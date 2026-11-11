#!/usr/bin/env bash
# Used by the Makefile: search for a package by part of its name and print the one picked.
#
#   make/pick-package.sh remove               enabled apps that can be removed
#   make/pick-package.sh reinstall [backup]   apps the backup can bring back (missing or
#                                             disabled now, but enabled in the backup)
#
# Questions go to stderr, so `pkg=$(make/pick-package.sh remove)` still shows them.
source "$(dirname "$0")/../common.sh"
require_device
[ -t 0 ] || die "no terminal to ask on - pass PKG=<package> instead"

case "${1:-}" in
  remove)
    candidates=$(pkgs -e | while read -r p; do is_protected "$p" || echo "$p"; done)
    what="installed apps" ;;
  reinstall)
    backup="${2:-$(latest_backup)}"
    [ -n "$backup" ] && [ -f "$backup/installed.txt" ] || die "no backup found (run ./shield-backup.sh)"
    candidates=$(sort -u <(comm -23 "$backup/installed.txt" <(pkgs)) \
      <(comm -12 <(pkgs -d) "$backup/enabled.txt"))
    what="apps the backup can bring back" ;;
  *) die "usage: $0 remove | reinstall [backup]" ;;
esac
[ -n "$candidates" ] || die "no $what"

read -r -p "Search $what (part of the name): " query
matches=$(grep -iF -- "$query" <<<"$candidates" || true)
[ -n "$matches" ] || die "nothing matches '$query'"

count=$(wc -l <<<"$matches" | tr -d ' ')
if [ "$count" = 1 ]; then echo "$matches"; exit 0; fi
nl -w3 -s') ' <<<"$matches" >&2
read -r -p "Pick a number: " pick
[[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -ge 1 ] && [ "$pick" -le "$count" ] || die "not a number from the list"
sed -n "${pick}p" <<<"$matches"
