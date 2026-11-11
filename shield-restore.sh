#!/usr/bin/env bash
# Put the Shield back to the state captured by a backup: reinstall removed apps,
# re-enable/disable packages to match, restore launcher and settings.
#
#   ./shield-restore.sh                    dry run against the latest backup
#   ./shield-restore.sh --apply            do it
#   ./shield-restore.sh backups/2026... [--apply]   use a specific backup
#   ./shield-restore.sh --only <package> [--apply]  just that one app (reinstall and/or
#                                                    re-enable it); launcher and settings
#                                                    are left alone
#
# Apps installed AFTER the backup are only reported, never removed.
source "$(dirname "$0")/common.sh"
require_device

APPLY=0; backup=""; ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --only) ONLY="${2:-}"; [ -n "$ONLY" ] || die "--only needs a package name"; shift ;;
    *) backup="$1" ;;
  esac
  shift
done
[ -n "$backup" ] || backup=$(latest_backup)
[ -n "$backup" ] && [ -f "$backup/installed.txt" ] || die "no backup found (run ./shield-backup.sh)"
backup=$(cd "$backup" && pwd)
[ -z "$ONLY" ] || grep -qxF -- "$ONLY" "$backup/installed.txt" \
  || die "$ONLY wasn't installed when this backup was taken - nothing to restore"

# With --only, keep just that package from a list of package names.
only() { if [ -n "$ONLY" ]; then grep -xF -- "$ONLY" || true; else cat; fi; }

echo "Restoring from: $backup"
[ -z "$ONLY" ] || echo "Package:        $ONLY"
[ "$APPLY" = 1 ] || echo "(dry run - add --apply to make changes)"
changes=0

run() {  # run <description> <expected-output-regex> <cmd...>
  local desc="$1" ok="$2"; shift 2
  changes=$((changes + 1))
  if [ "$APPLY" = 0 ]; then echo "  would: $desc"; return; fi
  local out; out=$("$@" 2>&1 || true)
  if [ -z "$ok" ] || grep -E -- "$ok" >/dev/null <<<"$out"; then echo "  ok:    $desc"
  else echo "  FAIL:  $desc -> $out"; fi
}

# 1. Packages that were installed at backup time but are missing now.
echo "[1/5] Missing apps"
known_now=$(pkgs -u)
while read -r p; do
  [ -n "$p" ] || continue
  if has "$p" "$known_now"; then
    # System app (or app removed with -k): still on the device, just re-add for user 0.
    run "re-add $p" "installed for user" ash cmd package install-existing --user 0 "$p"
  elif ls "$backup/apks/$p"/*.apk >/dev/null 2>&1; then
    files=("$backup/apks/$p"/*.apk)
    if [ "${#files[@]}" -eq 1 ]; then
      run "install $p from backup APK" "Success" adb install -r "${files[0]}"
    else
      run "install $p from ${#files[@]} backup APKs" "Success" adb install-multiple -r "${files[@]}"
    fi
  else
    echo "  MANUAL: $p is gone and has no APK in this backup - reinstall it from the Play Store"
  fi
done < <(comm -23 "$backup/installed.txt" <(pkgs) | only)

# 2/3. Enabled/disabled state (re-read, since step 1 may have changed it).
echo "[2/5] Re-enable packages that were enabled"
while read -r p; do
  [ -n "$p" ] || continue
  run "enable $p" "new state: enabled" ash pm enable "$p"
done < <(comm -12 <(pkgs -d) "$backup/enabled.txt" | only)

echo "[3/5] Re-disable packages that were disabled"
while read -r p; do
  [ -n "$p" ] || continue
  run "disable $p" "new state: disabled" ash pm disable-user --user 0 "$p"
done < <(comm -12 <(pkgs -e) "$backup/disabled.txt" | only)

# 4-5, and the report, are for a full restore only.
if [ -z "$ONLY" ]; then
  # 4. Launcher.
  echo "[4/5] Launcher"
  want=$(cat "$backup/home.txt"); now=$(home_activity)
  if [ "$want" != "$now" ] && printf '%s' "$want" | grep -q '/'; then
    run "set launcher $now -> $want" "Success" ash pm set-home-activity "$want"
  fi

  # 5. Settings.
  echo "[5/5] Settings"
  while read -r ns key val; do
    [ -n "$key" ] || continue
    cur=$(ash settings get "$ns" "$key")
    [ "$cur" = "$val" ] && continue
    if [ "$val" = "null" ]; then
      run "delete $ns/$key (was $cur)" "" ash settings delete "$ns" "$key"
    else
      run "set $ns/$key $cur -> $val" "" ash settings put "$ns" "$key" "$val"
    fi
  done < "$backup/settings.txt"

  extra=$(comm -13 "$backup/installed.txt" <(pkgs))
  # shellcheck disable=SC2086 # unquoted on purpose: one package name per line
  [ -z "$extra" ] || { echo "Installed since this backup (left alone):"; printf '  %s\n' $extra; }
fi

if [ "$changes" = 0 ]; then echo "Nothing to do - device already matches the backup."
elif [ "$APPLY" = 0 ]; then echo "$changes change(s) pending. Re-run with --apply."
else echo "Done. A reboot is recommended: adb reboot"; fi
