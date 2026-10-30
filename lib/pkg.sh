# shellcheck shell=bash
# Package installation helpers (pacman + AUR). Sourced by install.sh.

[[ -n "${_LIB_PKG_SH:-}" ]] && return 0
_LIB_PKG_SH=1

: "${REPO:?REPO must be set before sourcing lib/pkg.sh}"
AUR_HELPER=${AUR_HELPER:-paru}

# Print package names from one or more list files (comments and blanks skipped).
list_pkgs() {
	grep -vhE '^[[:space:]]*(#|$)' "$@" | awk '{print $1}'
}

is_installed() {
	pacman -Qq "$1" >/dev/null 2>&1
}

# Enable the multilib repository (needed for steam / wine / lib32-vulkan).
enable_multilib() {
	if grep -qE '^\[multilib\]' /etc/pacman.conf; then
		log_ok "multilib already enabled"
		return 0
	fi
	log_info "enabling [multilib] in /etc/pacman.conf"
	sudo_run cp -a /etc/pacman.conf "/etc/pacman.conf.bak-$STAMP"
	sudo_run sed -i -e 's/^#\[multilib\]/[multilib]/' -e '/^\[multilib\]/{n;s/^#[[:space:]]*Include/Include/}' /etc/pacman.conf
}

refresh_repos() {
	log_info "refreshing package databases (full upgrade)"
	sudo_run pacman -Syu --noconfirm --needed
}

ensure_base_devel() {
	sudo_run pacman -S --needed --noconfirm base-devel git
}

ensure_aur_helper() {
	if command -v "$AUR_HELPER" >/dev/null 2>&1; then
		log_ok "AUR helper available: $AUR_HELPER"
		return 0
	fi
	if command -v yay >/dev/null 2>&1; then
		AUR_HELPER=yay
		log_ok "AUR helper available: yay"
		return 0
	fi
	log_info "bootstrapping paru-bin from the AUR"
	local dir
	dir=$(mktemp -d)
	run git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$dir/paru-bin"
	run_sh "cd '$dir/paru-bin' && makepkg -si --noconfirm"
	run rm -rf "$dir"
	AUR_HELPER=paru
	command -v "$AUR_HELPER" >/dev/null 2>&1 || log_warn "paru-bin bootstrap failed, AUR packages will be skipped"
}

# pacman_group <file>
pacman_group() {
	local file=$1
	local -a pkgs
	mapfile -t pkgs < <(list_pkgs "$file")
	((${#pkgs[@]})) || return 0
	log_info "pacman: ${#pkgs[@]} package(s) from $(basename "$file")"
	if ((DRY_RUN)); then
		log_cmd "sudo pacman -S --needed --noconfirm ${pkgs[*]}"
		return 0
	fi
	if sudo pacman -S --needed --noconfirm "${pkgs[@]}"; then
		return 0
	fi
	log_warn "batch install from $(basename "$file") failed, retrying one by one"
	local p
	for p in "${pkgs[@]}"; do
		sudo pacman -S --needed --noconfirm "$p" || log_err "pacman failed: $p"
	done
}

# aur_group <file>
aur_group() {
	local file=$1
	local -a pkgs
	mapfile -t pkgs < <(list_pkgs "$file")
	((${#pkgs[@]})) || return 0
	if ! command -v "$AUR_HELPER" >/dev/null 2>&1; then
		log_warn "no AUR helper, skipping $(basename "$file")"
		return 0
	fi
	log_info "AUR: ${#pkgs[@]} package(s) from $(basename "$file") (this can take a while)"
	if ((DRY_RUN)); then
		log_cmd "$AUR_HELPER -S --needed --noconfirm ${pkgs[*]}"
		return 0
	fi
	if "$AUR_HELPER" -S --needed --noconfirm "${pkgs[@]}"; then
		return 0
	fi
	log_warn "batch AUR install failed, retrying one by one"
	local p
	for p in "${pkgs[@]}"; do
		"$AUR_HELPER" -S --needed --noconfirm "$p" || log_err "AUR failed: $p"
	done
}
