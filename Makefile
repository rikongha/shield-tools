# shield-tools, from the command line.
#
# Shortcuts for the scripts. Anything that changes the device shows its dry run first
# and only applies it after you answer y. Without a terminal (CI, a pipe) nothing is applied.
#
# `make` on its own lists what there is.

.DEFAULT_GOAL := help
.PHONY: help connect devices backup backup-state debloat restore remove reinstall launcher \
	launcher-set launcher-stock reboot lint

SHELLCHECK ?= shellcheck
SHIELD ?=
BACKUP ?=
PKG ?=
DISABLE_STOCK ?=
DEFAULT_LAUNCHER = com.spocky.projengmenu

# SHIELD=<ip> or <ip>:<port> picks the device for every target (adb reads ANDROID_SERIAL).
ifneq ($(SHIELD),)
export ANDROID_SERIAL := $(if $(findstring :,$(SHIELD)),$(SHIELD),$(SHIELD):5555)
endif

help: ## List what there is
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  SHIELD=<ip> picks the device, e.g. make connect SHIELD=192.168.1.20"

## ── Device ─────────────────────────────────────────────────────────

connect: ## Connect to the SHIELD over the network (needs SHIELD=<ip>)
	@test -n "$(SHIELD)" || { echo "usage: make connect SHIELD=<shield-ip>"; exit 1; }
	@adb connect $(ANDROID_SERIAL)
	@adb devices

devices: ## List connected devices
	@adb devices

backup: ## Snapshot package state and APKs of user-installed apps
	@./shield-backup.sh

backup-state: ## Snapshot package state only (fast, no APKs)
	@./shield-backup.sh --no-apks

debloat: ## Preview the debloat, then ask before applying it
	@make/preview-then-apply.sh ./shield-debloat.sh

restore: ## Preview a restore from the latest backup (or BACKUP=<dir>), then ask
	@make/preview-then-apply.sh ./shield-restore.sh $(BACKUP)

remove: ## Disable/uninstall one app, after a preview (PKG=<package>, or search)
	@pkg="$(PKG)"; [ -n "$$pkg" ] || pkg=$$(make/pick-package.sh remove) || exit 1; \
	make/preview-then-apply.sh ./shield-debloat.sh --only "$$pkg"

reinstall: ## Bring one app back from the backup, after a preview (PKG=<package>, or search)
	@pkg="$(PKG)"; [ -n "$$pkg" ] || pkg=$$(make/pick-package.sh reinstall $(BACKUP)) || exit 1; \
	make/preview-then-apply.sh ./shield-restore.sh $(BACKUP) --only "$$pkg"

launcher: ## Show the default launcher and the ones available
	@./shield-launcher.sh status

launcher-set: ## Switch launcher, after asking (PKG=<package>, DISABLE_STOCK=1)
	@./shield-launcher.sh status
	@if make/ask.sh "Set the default launcher to $(or $(PKG),$(DEFAULT_LAUNCHER))$(if $(DISABLE_STOCK), and disable the stock launcher)?"; then \
		./shield-launcher.sh set $(or $(PKG),$(DEFAULT_LAUNCHER)) $(if $(DISABLE_STOCK),--disable-stock); \
	fi

launcher-stock: ## Go back to the stock launcher, after asking
	@./shield-launcher.sh status
	@if make/ask.sh "Re-enable the stock launcher and make it the default?"; then \
		./shield-launcher.sh stock; \
	fi

reboot: ## Reboot the SHIELD (frees memory held by stopped services)
	@adb reboot

## ── Development ────────────────────────────────────────────────────

lint: ## shellcheck every script (what CI runs)
	@command -v $(SHELLCHECK) >/dev/null || { echo "shellcheck not found: brew install shellcheck"; exit 1; }
	@$(SHELLCHECK) *.sh make/*.sh
	@echo "shellcheck: ok"
