#!/usr/bin/env bash
# setup-archlinux - restore this Arch system from scratch (post-install).
#
#   ./install.sh                 # everything, in order
#   ./install.sh --dry-run       # show what would happen, change nothing
#   ./install.sh --stage configs # one stage only (packages,configs,system,shell,post)
#   ./install.sh --update        # also `git submodule update --remote`
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

CANONICAL_STAGES=(packages configs system shell post)
STAGES=()
WITH_KDE=1
WITH_NVIDIA=1
UPDATE_SUBMODULES=0
SKIP_WALLPAPERS=0
SKIP_GROUPS=()

ZEN_URL="${ZEN_URL:-https://github.com/zen-browser/desktop/releases/latest/download/zen.linux-x86_64.tar.xz}"SDDM_THEME_TAG="${SDDM_THEME_TAG:-v1.5.0}"
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
  --force               allow replacing config dirs with uncommitted changes
  -h, --help            this help
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
	[[ -f /etc/arch-release ]] || die "this installer targets Arch Linux"
	command -v pacman >/dev/null || die "pacman not found"
	if ((DRY_RUN)); then
		log_warn "DRY RUN - nothing on the system will change"
	fi
	log_info "repo: $REPO"
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
	enable_multilib
	refresh_repos
	ensure_base_devel

	local f
	for f in packages/00-base.txt packages/10-desktop.txt packages/20-nvidia.txt \
		packages/30-dev.txt packages/40-apps.txt packages/50-kde.txt; do
		[[ -f $f ]] || continue
		group_enabled "$(basename "$f")" || {
			log_info "skipping group $(basename "$f")"
			continue
		}
		pacman_group "$f"
	done

	ensure_aur_helper
	aur_group packages/90-aur.txt
}

# ----------------------------------------------------------------- configs --
update_submodules() {
	if ((UPDATE_SUBMODULES)); then
		log_info "updating submodules to latest upstream commits"
		run git submodule update --init --recursive --remote
	else
		run git submodule update --init --recursive
	fi
}

stage_configs() {
	log_info "== stage: configs =="
	update_submodules

	local pair src dst
	for pair in \
		"submodules/hypr:$HOME/.config/hypr" \
		"submodules/nvim:$HOME/.config/nvim" \
		"submodules/end4-pC:$HOME/.config/quickshell/end4-pC" \
		"submodules/scripts:$HOME/.scripts"; do
		src=${pair%%:*}
		dst=${pair#*:}
		link_dir "$REPO/$src" "$dst"
	done

	# Whole directories that are safe to symlink (apps write into the repo).
	local d
	for d in btop cava kitty fish foot mpv MangoHud rofi wlogout Kvantum \
		qt5ct qt6ct fontconfig gtk-3.0 gtk-4.0 matugen xsettingsd yay \
		kde-material-you-colors systemd/user \
		illogical-impulse/actions illogical-impulse/translations; do
		[[ -e $REPO/config/.config/$d ]] || continue
		link_dir "$REPO/config/.config/$d" "$HOME/.config/$d"
	done

	# Static dotfiles.
	local f
	for f in .zshrc .p10k.zsh .gitconfig .npmrc \
		.config/starship.toml .config/user-dirs.dirs \
		.config/code-flags.conf .config/chrome-flags.conf .config/thorium-flags.conf; do
		[[ -e $REPO/config/$f ]] || continue
		link_file "$REPO/config/$f" "$HOME/$f"
	done

	# Files that the owning application rewrites: keep them as real copies.
	for f in \
		.config/kdeglobals .config/dolphinrc .config/katerc .config/kwinrc \
		.config/kwinoutputconfig.json .config/spectaclerc .config/darklyrc \
		.config/QtProject.conf .config/Trolltech.conf \
		.config/Code/User/settings.json .config/Code/User/keybindings.json \
		.config/qBittorrent/qBittorrent.conf .config/qBittorrent/categories.json \
		.config/illogical-impulse/config.json; do
		[[ -e $REPO/config/$f ]] || continue
		render_copy "$REPO/config/$f" "$HOME/$f"
	done

	# aria2.conf is rendered so it follows $HOME instead of a hardcoded path.
	if [[ -f $REPO/config/.config/aria2/aria2.conf.tmpl ]]; then
		local tmp
		tmp=$(mktemp)
		sed "s|@HOME@|$HOME|g" "$REPO/config/.config/aria2/aria2.conf.tmpl" >"$tmp"
		copy_file "$tmp" "$HOME/.config/aria2/aria2.conf"
		rm -f "$tmp"
	fi

	run mkdir -p "$HOME/Wallpapers" "$HOME/.local/bin" "$HOME/.local/opt"
}

# ------------------------------------------------------------------ system --
install_sddm_theme() {
	if [[ -f $SDDM_THEME_DIR/Main.qml ]]; then
		log_ok "sddm theme present: $SDDM_THEME_DIR"
		return 0
	fi
	log_info "installing SilentSDDM $SDDM_THEME_TAG"
	sudo_run pacman -S --needed --noconfirm sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg qt6-imageformats
	local tmp
	tmp=$(mktemp -d)
	run git clone --depth 1 --branch "$SDDM_THEME_TAG" https://github.com/uiriansan/SilentSDDM.git "$tmp/silent"
	sudo_run rm -rf "$SDDM_THEME_DIR"
	sudo_run cp -a "$tmp/silent" "$SDDM_THEME_DIR"
	sudo_run rm -rf "$SDDM_THEME_DIR/.git"
	run rm -rf "$tmp"
}

enable_services() {
	local unit
	while read -r unit; do
		[[ -z $unit || $unit == \#* ]] && continue
		log_info "systemctl enable $unit"
		sudo_run systemctl enable "$unit"
	done <system/services/system.txt

	sudo_run systemctl daemon-reload

	if [[ -n ${XDG_RUNTIME_DIR:-} && -S ${XDG_RUNTIME_DIR:-}/bus ]]; then
		run systemctl --user daemon-reload
		local u
		while read -r u; do
			[[ -z $u || $u == \#* ]] && continue
			log_info "systemctl --user enable $u"
			run systemctl --user enable "$u"
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
		sudo_install "$REPO/system/etc/$f" "/etc/$f"
	done < <(cd system/etc && find . -type f | sed 's|^\./||' | sort)

	sudo_install "$REPO/system/usr/share/xkb/symbols/us" /usr/share/xkeyboard-config-2/symbols/us

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

	local me
	me=$(id -un)
	if [[ $(getent passwd "$me" | cut -d: -f7) != /usr/bin/zsh ]]; then
		log_info "setting zsh as login shell"
		sudo_run chsh -s /usr/bin/zsh "$me"
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

	run fc-cache -f

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
