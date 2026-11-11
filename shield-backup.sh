#!/usr/bin/env bash
# Snapshot the Shield's package state and pull the APKs of every user-installed app.
#
#   ./shield-backup.sh            full backup (state + APKs)
#   ./shield-backup.sh --no-apks  state only (fast; enough to undo disables/launcher changes)
#
# Saved under backups/<timestamp>/. App DATA (logins, settings inside apps) is not
# backed up - Android 11 doesn't allow that over adb for most apps.
source "$(dirname "$0")/common.sh"
require_device

PULL_APKS=1
[ "${1:-}" = "--no-apks" ] && PULL_APKS=0

dir="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$dir"
echo "Backing up to $dir"

{
  echo "model=$(ash getprop ro.product.model)"
  echo "device=$(ash getprop ro.product.device)"
  echo "android=$(ash getprop ro.build.version.release)"
  echo "build=$(ash getprop ro.build.display.id)"
  echo "date=$(date)"
} > "$dir/device.txt"

pkgs     > "$dir/installed.txt"    # installed for user 0 (enabled or disabled)
pkgs -u  > "$dir/known.txt"        # also includes apps uninstalled-for-user with data kept
pkgs -s  > "$dir/system.txt"
pkgs -3  > "$dir/thirdparty.txt"
pkgs -d  > "$dir/disabled.txt"
pkgs -e  > "$dir/enabled.txt"
home_activity > "$dir/home.txt"

{
  for k in window_animation_scale transition_animation_scale animator_duration_scale; do
    echo "global $k $(ash settings get global "$k")"
  done
  for k in screensaver_components screensaver_enabled; do
    echo "secure $k $(ash settings get secure "$k")"
  done
} > "$dir/settings.txt"

echo "  $(wc -l < "$dir/installed.txt" | tr -d ' ') packages, $(wc -l < "$dir/disabled.txt" | tr -d ' ') disabled, launcher: $(cat "$dir/home.txt")"

if [ "$PULL_APKS" = 1 ]; then
  echo "Pulling APKs for $(wc -l < "$dir/thirdparty.txt" | tr -d ' ') user-installed apps..."
  failed=0
  while read -r p; do
    [ -n "$p" ] || continue
    mkdir -p "$dir/apks/$p"
    ash pm path "$p" | sed 's/^package://' > "$dir/apks/$p/paths.txt"
    while read -r remote; do
      adb pull "$remote" "$dir/apks/$p/" >/dev/null 2>&1 < /dev/null \
        || { echo "  WARN: failed to pull $remote"; failed=1; }
    done < "$dir/apks/$p/paths.txt"
    n_remote=$(wc -l < "$dir/apks/$p/paths.txt" | tr -d ' ')
    # shellcheck disable=SC2012 # only counting files; package names have no odd characters
    n_local=$(ls "$dir/apks/$p"/*.apk 2>/dev/null | wc -l | tr -d ' ')
    [ "$n_remote" = "$n_local" ] || { echo "  WARN: $p got $n_local of $n_remote APK files"; failed=1; }
    printf '  %-42s %s file(s)\n' "$p" "$n_local"
  done < "$dir/thirdparty.txt"
  [ "$failed" = 0 ] || echo "Some APKs failed to pull - see warnings above."
fi

echo "Done: $dir ($(du -sh "$dir" | cut -f1))"
