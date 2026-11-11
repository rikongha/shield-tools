#!/usr/bin/env bash
# Disable/uninstall everything listed (uncommented) in the package list, and set animation speed.
#
#   ./shield-debloat.sh           dry run - shows exactly what would happen
#   ./shield-debloat.sh --apply   do it
#   ./shield-debloat.sh --only <package> [--apply]
#                                 just that one package (same safety checks; animation
#                                 speed is left alone)
#
# Package list: debloat.local.txt if it exists (your private copy, git-ignored),
# otherwise debloat.txt. Override with DEBLOAT_LIST=path/to/list.txt.
#
# System apps are DISABLED (pm disable-user): reversible, nothing deleted.
# User-installed apps are UNINSTALLED, but only if their APK is in the latest backup.
# Undo everything with ./shield-restore.sh --apply.
source "$(dirname "$0")/common.sh"
require_device

ANIM_SCALE="${ANIM_SCALE:-0.5}"   # 0.5 = twice as fast, 0 = off, 1 = stock
APPLY=0; ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --only) ONLY="${2:-}"; [ -n "$ONLY" ] || die "--only needs a package name"; shift ;;
    *) die "usage: $0 [--only <package>] [--apply]" ;;
  esac
  shift
done

if [ -n "$ONLY" ]; then
  packages="$ONLY"
else
  LIST="${DEBLOAT_LIST:-$TOOLS_DIR/debloat.local.txt}"
  [ -f "$LIST" ] || [ -n "${DEBLOAT_LIST:-}" ] || LIST="$TOOLS_DIR/debloat.txt"
  [ -f "$LIST" ] || die "package list not found: $LIST"
  packages=$(sed -e 's/#.*//' -e 's/[[:space:]]//g' "$LIST" | grep -v '^$' || true)
fi

backup=$(latest_backup)
[ -n "$backup" ] || die "no backup found - run ./shield-backup.sh first"
if [ -n "$ONLY" ]; then echo "Package:      $ONLY"; else echo "Package list: $LIST"; fi
echo "Safety net:   $backup"
[ "$APPLY" = 1 ] || echo "(dry run - add --apply to make changes)"

installed=$(pkgs); system=$(pkgs -s); disabled=$(pkgs -d)
n=0

while read -r p; do
  [ -n "$p" ] || continue
  if is_protected "$p"; then echo "  SKIP   $p (protected - would break the system/launcher)"; continue; fi
  if ! has "$p" "$installed"; then echo "  skip   $p (not installed)"; continue; fi
  if has "$p" "$disabled"; then echo "  skip   $p (already disabled)"; continue; fi

  if has "$p" "$system"; then
    action="disable"; cmd=(ash pm disable-user --user 0 "$p"); ok="new state: disabled"
  else
    if ! ls "$backup/apks/$p"/*.apk >/dev/null 2>&1; then
      echo "  SKIP   $p (user app with no APK in the backup - run ./shield-backup.sh first)"; continue
    fi
    action="remove "; cmd=(ash pm uninstall "$p"); ok="Success"
  fi

  n=$((n + 1))
  if [ "$APPLY" = 0 ]; then echo "  would $action $p"; continue; fi
  out=$("${cmd[@]}" 2>&1 || true)
  if grep -F -- "$ok" >/dev/null <<<"$out"; then echo "  $action $p"
  else echo "  FAIL   $p -> $out"; fi
done <<<"$packages"

if [ -z "$ONLY" ]; then
  echo "Animation scale -> $ANIM_SCALE"
  for k in window_animation_scale transition_animation_scale animator_duration_scale; do
    cur=$(ash settings get global "$k")
    [ "$cur" = "$ANIM_SCALE" ] && continue
    if [ "$APPLY" = 1 ]; then ash settings put global "$k" "$ANIM_SCALE"; echo "  $k: $cur -> $ANIM_SCALE"
    else echo "  would set $k: $cur -> $ANIM_SCALE"; fi
  done
fi

if [ "$APPLY" = 0 ]; then echo "$n package change(s) pending. Re-run with --apply."
else echo "Done. Reboot to free memory from stopped services: adb reboot"; fi
