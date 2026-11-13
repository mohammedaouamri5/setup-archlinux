#!/usr/bin/env bash
# setup-archlinux - restore this machine after a format (post-install).
#
# Works on Arch (pacman/AUR), Fedora (dnf) and openSUSE (zypper).
# Debian/Ubuntu are deliberately not supported.
#
#   ./install.sh                 # everything, in order
#   ./install.sh --dry-run       # show what would happen, change nothing
#   ./install.sh --stage configs # one stage only (packages,configs,system,shell,post)
#   ./install.sh --update        # also `git submodule update --remote`
#   ./install.sh --distro fedora --dry-run   # test the planning path
#
# Run as your normal user (it calls sudo when needed), never as root.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO"

# Home directory the repo's configs were captured from; replaced by $HOME when
# files have to be copied instead of symlinked.
REPO_HOME="${REPO_HOME:-/home/mohammedaouamri}"

# shellcheck source=lib/log.sh
source lib/log.sh
# shellcheck source=lib/pkg.sh
source lib/pkg.sh
# shellcheck source=lib/link.sh
source lib/link.sh
# shellcheck source=lib/configs.sh
source lib/configs.sh

CANONICAL_STAGES=(packages configs system shell post)
STAGES=()
WITH_KDE=1
WITH_NVIDIA=1
UPDATE_SUBMODULES=0
SKIP_WALLPAPERS=0
SKIP_GROUPS=()
STRICT_PKGS=0

ZEN_URL="${ZEN_URL:-https://github.com/zen-browser/desktop/releases/latest/download/zen.linux-x86_64.tar.xz}"
SDDM_THEME_TAG="${SDDM_THEME_TAG:-v1.5.0}"
SDDM_THEME_DIR=/usr/share/sddm/themes/silent

usage() {
	cat <<'EOF'
usage: ./install.sh [options]

  --all                 run every stage (default)
  --stage LIST          comma separated: packages,configs,system,shell,post
  --dry-run             print actions, change nothing
  --update              pull latest submodule commits before linking
  --skip-group NAME     skip a package group, e.g. 20-nvidia or 50-kde
  --no-kde              do not install 50-kde.txt
  --no-nvidia           do not install 20-nvidia.txt
  --skip-wallpapers     do not download wallpapers in the post stage
  --strict              a package missing from this distro is an error
  --distro NAME         pretend to be arch|fedora|opensuse (use with --dry-run)
  --force               allow replacing config dirs with uncommitted changes
  -h, --help            this help

Supported systems: Arch and derivatives (pacman + AUR), Fedora and
derivatives (dnf), openSUSE/SUSE (zypper). Debian/Ubuntu are refused.
EOF
}

parse_args() {
	while (($#)); do
		case $1 in
		--all) STAGES=("${CANONICAL_STAGES[@]}") ;;
		--stage)
			shift
			[[ -n ${1:-} ]] || die "--stage needs a value"
			IFS=, read -ra _stages <<<"$1"
			STAGES+=("${_stages[@]}")
			;;
		--dry-run) DRY_RUN=1 ;;
		--update) UPDATE_SUBMODULES=1 ;;
		--skip-group)
			shift
			[[ -n ${1:-} ]] || die "--skip-group needs a value"
			SKIP_GROUPS+=("$1")
			;;
		--no-kde) WITH_KDE=0 ;;
		--no-nvidia) WITH_NVIDIA=0 ;;
		--skip-wallpapers) SKIP_WALLPAPERS=1 ;;
		--strict) STRICT_PKGS=1 ;;
		--distro)
			shift
			[[ -n ${1:-} ]] || die "--distro needs a value"
			DISTRO_OVERRIDE=$1
			;;
		--force) FORCE=1 ;;
		-h | --help)
			usage
			exit 0
			;;
		*) die "unknown option: $1 (try --help)" ;;
		esac
		shift
	done
	((${#STAGES[@]})) || STAGES=("${CANONICAL_STAGES[@]}")
	local s
	for s in "${STAGES[@]}"; do
		[[ " ${CANONICAL_STAGES[*]} " == *" $s "* ]] || die "unknown stage: $s"
	done
}

preflight() {
	((EUID != 0)) || die "run this as your normal user, not root"
	detect_distro
	if ((DRY_RUN)); then
		log_info "DRY RUN - nothing on the system will change"
	fi
	log_info "repo: $REPO"
	log_info "home: $HOME (captured from $REPO_HOME)"
	[[ -f $REPO/config/manifest.txt ]] || die "missing config/manifest.txt"
}

start_log() {
	mkdir -p "$REPO/logs"
	LOG_FILE="$REPO/logs/install-$STAMP.log"
	: >"$LOG_FILE"
	log_info "log: $LOG_FILE"
}

group_enabled() {
	local name=$1 g
	for g in "${SKIP_GROUPS[@]}"; do
		[[ $name == "$g" || $name == "$g.txt" ]] && return 1
	done
	[[ $name == 20-nvidia.txt ]] && ((!WITH_NVIDIA)) && return 1
	[[ $name == 50-kde.txt ]] && ((!WITH_KDE)) && return 1
	return 0
}

# ---------------------------------------------------------------- packages --
stage_packages() {
	log_info "== stage: packages =="
	# multilib only exists on Arch; harmless no-op elsewhere
	enable_multilib
	pkg_refresh
	pkg_base_devel

	local f
	for f in packages/00-base.txt packages/10-desktop.txt packages/20-nvidia.txt \
		packages/30-dev.txt packages/40-apps.txt packages/50-kde.txt; do
		[[ -f $f ]] || continue
		group_enabled "$(basename "$f")" || {
			log_info "skipping group $(basename "$f")"
			continue
		}
		pkg_group "$f"
	done

	# Distro-specific extras (native names, optional by design).
	if [[ -f packages/extra/$DISTRO_FAMILY.txt ]]; then
		pkg_group_optional "packages/extra/$DISTRO_FAMILY.txt"
	fi

	ensure_aur_helper
	aur_group packages/90-aur.txt
}

# ----------------------------------------------------------------- configs --
stage_configs() {
	log_info "== stage: configs =="
	update_submodules
	deploy_configs
	migrate_legacy_ii
	ensure_wallpaper_dir
	log_ok "config manifest deployed"
}

# ------------------------------------------------------------------ system --
install_sddm_theme() {
	if [[ -f $SDDM_THEME_DIR/Main.qml ]]; then
		log_ok "sddm theme present: $SDDM_THEME_DIR"
		return 0
	fi
	log_info "installing SilentSDDM $SDDM_THEME_TAG"
	# Canonical names on purpose: packages/maps translates them per distro.
	pkg_install sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg qt6-imageformats
	local tmp
	tmp=$(mktemp -d)
	run git clone --depth 1 --branch "$SDDM_THEME_TAG" https://github.com/uiriansan/SilentSDDM.git "$tmp/silent"
	sudo_run rm -rf "$SDDM_THEME_DIR"
	sudo_run cp -a "$tmp/silent" "$SDDM_THEME_DIR"
	sudo_run rm -rf "$SDDM_THEME_DIR/.git"
	run rm -rf "$tmp"
}

unit_exists() {
	systemctl list-unit-files --no-legend "$1" 2>/dev/null | grep -q .
}

enable_services() {
	local unit
	local -a service_lists=(system/services/system.txt)
	[[ -f system/services/system.$DISTRO_FAMILY.txt ]] && service_lists+=("system/services/system.$DISTRO_FAMILY.txt")

	local list
	for list in "${service_lists[@]}"; do
		[[ -f $list ]] || continue
		while read -r unit; do
			[[ -z $unit || $unit == \#* ]] && continue
			if ((DRY_RUN)); then
				log_cmd "sudo systemctl enable $unit"
			elif ! unit_exists "$unit"; then
				log_warn "unit not provided by $DISTRO_ID: $unit"
			else
				log_info "systemctl enable $unit"
				sudo systemctl enable "$unit" || log_warn "could not enable $unit"
			fi
		done <"$list"
	done

	sudo_run systemctl daemon-reload

	if [[ -n ${XDG_RUNTIME_DIR:-} && -S ${XDG_RUNTIME_DIR:-}/bus ]]; then
		run systemctl --user daemon-reload
		local u
		while read -r u; do
			[[ -z $u || $u == \#* ]] && continue
			log_info "systemctl --user enable $u"
			run systemctl --user enable "$u" || log_warn "could not enable user unit $u"
		done <system/services/user.txt
	else
		log_warn "no user session bus - after your first login run:"
		log_warn "  systemctl --user daemon-reload && systemctl --user enable --now aria2.service"
	fi
}

stage_system() {
	log_info "== stage: system =="
	command -v sudo >/dev/null || die "sudo is required for the system stage"

	local f
	while IFS= read -r f; do
		# pacman.conf only makes sense on Arch.
		if [[ $f == pacman.conf ]] && ! is_arch_family; then
			log_info "skipping /etc/pacman.conf on $DISTRO_ID"
			continue
		fi
		sudo_install "$REPO/system/etc/$f" "/etc/$f"
	done < <(cd system/etc && find . -type f | sed 's|^\./||' | sort)

	# /usr/share/X11/xkb is the portable location (Arch symlinks it).
	sudo_install "$REPO/system/usr/share/xkb/symbols/us" /usr/share/X11/xkb/symbols/us

	install_sddm_theme
	enable_services
}

# ------------------------------------------------------------------- shell --
stage_shell() {
	log_info "== stage: shell =="

	if [[ -d $HOME/.oh-my-zsh ]]; then
		log_ok "oh-my-zsh present"
	else
		log_info "installing oh-my-zsh (keeping the repo .zshrc)"
		run_sh 'RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
	fi

	local custom=$HOME/.oh-my-zsh/custom
	clone_if_missing https://github.com/zsh-users/zsh-autosuggestions "$custom/plugins/zsh-autosuggestions"
	clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting.git "$custom/plugins/zsh-syntax-highlighting"
	clone_if_missing https://github.com/chrissicool/zsh-256color "$custom/plugins/zsh-256color"
	clone_if_missing https://github.com/romkatv/powerlevel10k.git "$custom/themes/powerlevel10k"

	clone_if_missing https://github.com/pyenv/pyenv.git "$HOME/.pyenv"

	local me zsh_bin
	me=$(id -un)
	zsh_bin=$(command -v zsh || true)
	if [[ -z $zsh_bin ]]; then
		log_warn "zsh is not installed; install it and re-run this stage"
	elif [[ $(getent passwd "$me" | cut -d: -f7) != "$zsh_bin" ]]; then
		log_info "setting zsh as login shell ($zsh_bin)"
		sudo_run chsh -s "$zsh_bin" "$me"
	fi

	install_zen
}

install_zen() {
	local dir=$HOME/.local/opt/zen
	if [[ -x $dir/zen ]]; then
		log_ok "zen present: $dir/zen"
		return 0
	fi
	log_info "downloading Zen browser"
	local tmp
	tmp=$(mktemp -d)
	run curl -fL --retry 3 -o "$tmp/zen.tar.xz" "$ZEN_URL"
	run tar -xf "$tmp/zen.tar.xz" -C "$tmp"
	run mkdir -p "$dir"
	if [[ -d $tmp/zen ]]; then
		run_sh "cp -a '$tmp/zen/.' '$dir/'"
	else
		run_sh "cp -a '$tmp/.' '$dir/'"
	fi
	run rm -rf "$tmp"
	run mkdir -p "$HOME/.local/share/applications"
	if ((!DRY_RUN)); then
		cat >"$HOME/.local/share/applications/zen.desktop" <<-EOF
			[Desktop Entry]
			Type=Application
			Name=Zen
			Comment=Zen Browser
			Exec=$dir/zen %u
			Icon=$dir/browser/chrome/icons/default/default128.png
			Terminal=false
			Categories=Network;WebBrowser;
		EOF
		log_ok "desktop entry: ~/.local/share/applications/zen.desktop"
	fi
}

# -------------------------------------------------------------------- post --
stage_post() {
	log_info "== stage: post =="

	if ((SKIP_WALLPAPERS)); then
		log_info "skipping wallpapers (--skip-wallpapers)"
	elif ((DRY_RUN)); then
		log_cmd "scripts/fetch-wallpapers.sh"
	else
		"$REPO/scripts/fetch-wallpapers.sh" || log_warn "wallpaper download had problems"
	fi

	command -v fc-cache >/dev/null && run fc-cache -f || log_warn "fc-cache not available"

	if [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
		log_info "reloading Hyprland"
		run hyprctl reload || log_warn "hyprctl reload failed"
	fi

	cat <<EOF

${C_BLUE}Manual steps left${C_RESET}
  1. SSH keys:      ssh-keygen -t ed25519 && gh auth login
  2. pyenv:         pyenv install 3.12 && pyenv global 3.12
  3. Model/AI keys: open the Quickshell settings (Super+Escape) and re-enter provider keys
  4. LM Studio:     ~/.lmstudio/bin/lms bootstrap
  5. Reboot once so the NVIDIA modules and SDDM theme load cleanly
  6. Wallpaper URLs live in config/wallpapers/urls.txt
  7. Distro notes:  Arch uses AUR; Fedora/openSUSE install native equivalents
                    and skip AUR-only apps (see packages/maps/).

EOF
}

# -------------------------------------------------------------------- main --
main() {
	parse_args "$@"
	preflight
	start_log
	local s
	for s in "${CANONICAL_STAGES[@]}"; do
		[[ " ${STAGES[*]} " == *" $s "* ]] || continue
		"stage_$s"
	done
	summary
	((ERRORS == 0))
}

main "$@"
