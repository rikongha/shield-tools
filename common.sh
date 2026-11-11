# shellcheck shell=bash
# Shared helpers for the shield-* scripts. Sourced, not run directly.
# If more than one device is connected, export ANDROID_SERIAL=<ip>:5555 first.
set -euo pipefail
export LC_ALL=C   # stable sort order so comm(1) works

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_ROOT="$TOOLS_DIR/backups"
# shellcheck disable=SC2034 # used by shield-launcher.sh, which sources this file
STOCK_LAUNCHER="com.google.android.tvlauncher"

# Never disable/uninstall these, even if someone uncomments them in debloat.txt.
PROTECTED="android com.android.systemui com.android.tv.settings com.android.vending
com.android.shell com.android.providers.settings com.android.providers.tv
com.android.providers.media com.android.providers.media.module com.android.providers.downloads
com.google.android.gms com.google.android.gsf com.google.android.webview
com.google.android.packageinstaller com.google.android.permissioncontroller
com.google.android.tungsten.setupwraith com.google.android.tvlauncher com.spocky.projengmenu
com.google.android.leanback.ime com.android.bluetooth com.nvidia.shieldtech.hooks"

die()  { echo "error: $*" >&2; exit 1; }

# adb shell that never swallows the caller's stdin (-n) and strips CRs.
ash()  { adb shell -n "$@" | tr -d '\r'; }

# Sorted package names, e.g. `pkgs -d` for disabled packages.
pkgs() { ash pm list packages "$@" | sed 's/^package://' | sort; }

has()  { grep -xF -- "$1" >/dev/null <<<"$2"; }   # has <item> <newline-list>

# shellcheck disable=SC2086 # unquoted on purpose: split PROTECTED into one name per line
is_protected() { grep -xF -- "$1" >/dev/null <<<"$(printf "%s\n" $PROTECTED)"; }

home_activity() {
  ash cmd package resolve-activity --brief \
    -a android.intent.action.MAIN -c android.intent.category.HOME | tail -1
}

require_device() {
  command -v adb >/dev/null || die "adb not found on PATH"
  local state
  state=$(adb get-state 2>&1 || true)
  [ "$state" = "device" ] || die "no single device connected ($state).
  Run: adb connect <shield-ip>:5555   (or export ANDROID_SERIAL if several are attached)"
}

latest_backup() {
  # shellcheck disable=SC2012 # backup dirs are our own YYYYMMDD-HHMMSS names
  ls -1d "$BACKUP_ROOT"/2*/ 2>/dev/null | sort | tail -1 | sed 's:/$::'
}
