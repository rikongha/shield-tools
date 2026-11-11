# shield-tools

Small, reversible adb scripts for making an NVIDIA SHIELD TV feel faster. They back up the
device's package state, disable telemetry and unused system apps, speed up animations and
swap the launcher, and can undo all of it.

> **Unofficial.** This project is not affiliated with, endorsed by or supported by NVIDIA or
> Google. "NVIDIA" and "SHIELD" are trademarks of NVIDIA Corporation, used here only to
> describe the hardware the scripts target. Use at your own risk (see [License](#license)).

Developed against a **2019 SHIELD TV Pro on Android 11** (SHIELD Experience 9.x). Other
SHIELD models probably work, but package names can differ, so always read the dry run.

## Why debloat instead of a custom ROM?

My SHIELD became slow and I thought about flashing a custom ROM on it to boost its performance but after researching the trade-offs, I decided against it.
The SHIELD's slowdowns come mostly from background services and the stock launcher, not
the firmware itself. Staying on stock firmware keeps NVIDIA's own features (AI upscaling,
Dolby Vision, certified DRM for HD/4K streaming apps) and OTA updates, which custom ROMs may
lose. Debloating gets most of the speed-up and can be undone in one command.

## Requirements

- `adb` ([Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools))
- `bash` (Or your preferred shell)
- On the SHIELD: **Settings → Device Preferences → About**, click **Build** 7 times, then
  **Device Preferences → Developer options → Network debugging** on.

```sh
adb connect <shield-ip>:5555     # accept the prompt on the TV
adb devices                      # should list the SHIELD as "device"
```

On macOS, `failed to connect ... No route to host` usually means your terminal lacks the
**Local Network** permission: System Settings → Privacy & Security → Local Network → enable
your terminal app, then restart it. If several devices are connected,
`export ANDROID_SERIAL=<shield-ip>:5555` first.

## Usage

```sh
./shield-backup.sh               # 1. snapshot package state + APKs of user-installed apps
./shield-debloat.sh              # 2. dry run: shows exactly what would change
./shield-debloat.sh --apply      # 3. do it
adb reboot                       # 4. free the memory held by stopped services
```

Undo everything:

```sh
./shield-restore.sh              # dry run against the latest backup
./shield-restore.sh --apply      # restore it
./shield-restore.sh backups/20260101-120000 --apply   # or a specific backup
```

Just one app:

```sh
./shield-debloat.sh --only com.nvidia.feedback [--apply]   # disable/uninstall one package
./shield-restore.sh --only com.nvidia.feedback [--apply]   # bring that one back
```

`--only` uses the same safety checks (protected list, backup required) and leaves the
animation speed, launcher and settings alone.

Change the launcher (defaults to [Projectivy Launcher](https://play.google.com/store/apps/details?id=com.spocky.projengmenu)):

or AT4K (if you prefer the Apple TV look and feel)
[AT4K](https://play.google.com/store/apps/details?id=com.overdevs.at4k):

```sh
./shield-launcher.sh status
./shield-launcher.sh set [package] [--disable-stock]
./shield-launcher.sh stock       # undo: re-enable and use the stock launcher
```

### Make shortcuts

If you'd rather not remember flags, `make` lists shortcuts for every step. Anything that
changes the device shows the dry run first and asks `Apply these changes? [y/N]`. Only
`y` applies it; anything else, or no terminal at all, applies nothing.

```sh
make connect SHIELD=192.168.1.20   # adb connect 192.168.1.20:5555
make backup                        # 1. snapshot package state + APKs
make debloat                       # 2-3. preview, then asks before applying
make reboot                        # 4.
make restore                       # undo: preview, then asks (BACKUP=backups/... for an older one)
make remove                        # one app: search by name, pick it, preview, ask (or PKG=<package>)
make reinstall                     # bring one app back from the backup, same way
make launcher-set                  # switch to Projectivy (PKG=<package>, DISABLE_STOCK=1), asks first
make launcher-stock                # back to the stock launcher, asks first
```

`SHIELD=<ip>[:port]` picks the device for any target when several are connected.

## What each script does

| Script                                                | Changes                                                                                                                                                                                                                                                   |
| ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `shield-backup.sh [--no-apks]`                        | Nothing on the device. Saves installed/enabled/disabled package lists, the default launcher, animation and screensaver settings, and pulls the APKs (including split APKs) of user-installed apps to `backups/<timestamp>/`.                              |
| `shield-debloat.sh [--only <pkg>] [--apply]`          | For each package in the list: **system apps are disabled** (`pm disable-user`, nothing deleted). **User-installed apps are uninstalled**, but only if their APK is in the latest backup. Sets animation scales to `0.5`. Refuses to run without a backup. |
| `shield-restore.sh [backup] [--only <pkg>] [--apply]` | Reinstalls missing apps (from the device itself or the backed-up APKs), re-enables/re-disables packages to match the backup, restores the launcher and settings. Apps installed after the backup are only reported, never removed.                        |
| `shield-launcher.sh`                                  | Sets the default HOME activity; optionally disables the stock launcher.                                                                                                                                                                                   |

## Customising

- **Package list:** `debloat.txt` is a commented starting point: only telemetry and feedback
  services are enabled by default. Copy it to `debloat.local.txt` and edit that: the script
  prefers it, and it's git-ignored. Or point at any file with `DEBLOAT_LIST=path`.
- **Animation speed:** `ANIM_SCALE=0 ./shield-debloat.sh --apply` turns animations off,
  `1` is stock. Default `0.5`.
- **Protected packages:** `common.sh` has a `PROTECTED` list (system UI, settings, Play
  Store, Play Services, keyboard, launchers, ...) that is never touched, even if listed.

## Development

```sh
brew install shellcheck   # or your package manager's shellcheck
make lint                 # shellcheck every script
```

CI (`.github/workflows/lint.yml`) runs `make lint` on every push to `main` and on every
pull request, using a pinned, checksum-verified shellcheck release. `.shellcheckrc` lets
shellcheck follow `common.sh` into each script. Any warning that's intentionally ignored
has an inline `# shellcheck disable=…` comment explaining why. `make/` holds the small
helpers behind the Makefile's preview-and-ask prompts.

## Safety notes

- Everything is a **dry run** unless you pass `--apply`.
- Only package state is backed up. **App data** (logins, settings inside apps) is not:
  Android 11 doesn't allow that over adb for most apps.
- **Your `backups/` folder is private.** It contains copies of third-party APKs, which you
  must not redistribute. It's git-ignored; keep it that way.
- A firmware update may re-enable disabled packages. Re-run `./shield-debloat.sh` afterwards.
- Disabling `com.nvidia.ota` is possible but not recommended: you'd lose security fixes.

## Prior art and further reading

These scripts were written independently, but these two projects cover the same ground and
are worth reading:

- **[[Tutorial] De-Bloat and De-Google Nvidia Shield Pro](https://forum.level1techs.com/t/tutorial-de-bloat-and-de-google-nvidia-shield-pro/247451)**
  (Level1Techs forum, 2026): a SHIELD Pro specific package-by-package walkthrough. It's
  more aggressive, using `pm uninstall -k --user 0` and removing Play Services and the
  Play Store. This repo deliberately takes the conservative, disable-and-restore route instead.
- **[Universal Android Debloater Next Generation (UAD-ng)](https://github.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation)**:
  a cross-platform GUI that debloats non-rooted Android devices over adb, with a
  community-maintained, documented package list. Good for researching what an unfamiliar
  package does before adding it to your list.

## License

[MIT](LICENSE). Provided "as is", without warranty of any kind.
