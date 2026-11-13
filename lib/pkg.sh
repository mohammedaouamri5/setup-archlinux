# shellcheck shell=bash
# Package installation helpers. Sourced by install.sh.
#
# The installer is distro-agnostic on purpose:
#   * Arch family  -> pacman (+ an AUR helper when available)
#   * Fedora family -> dnf
#   * openSUSE     -> zypper
# Debian/Ubuntu are deliberately refused (the maintainer never uses them).
#
# packages/*.txt stay in the canonical Arch spelling.  Renames and packages
# that simply do not exist elsewhere are handled by packages/maps/<backend>.map:
#
#   arch-name   distro-name [more distro packages...]
#   arch-name   -                        # not available, skip silently
#   some-*      some-package             # shell glob, used after exact matches
#
# A package with no matching map entry is tried with its Arch name; if the
# distro does not know it, the install warns and continues (use --strict to
# turn those warnings into errors).

[[ -n "${_LIB_PKG_SH:-}" ]] && return 0
_LIB_PKG_SH=1

: "${REPO:?REPO must be set before sourcing lib/pkg.sh}"

AUR_HELPER=${AUR_HELPER:-paru}
PKG_BACKEND=${PKG_BACKEND:-}
DISTRO_FAMILY=${DISTRO_FAMILY:-}
DISTRO_ID=${DISTRO_ID:-}
DISTRO_LIKE=${DISTRO_LIKE:-}
DISTRO_PRETTY=${DISTRO_PRETTY:-}
STRICT_PKGS=${STRICT_PKGS:-0}

# ------------------------------------------------------------------ detect --
detect_distro() {
	local id='' like='' pretty=''
	if [[ -r /etc/os-release ]]; then
		# shellcheck disable=SC1091
		. /etc/os-release
		id=${ID:-}
		like=${ID_LIKE:-}
		pretty=${PRETTY_NAME:-${NAME:-$id}}
	fi

	# --distro is meant for testing the planning path (use it with --dry-run).
	if [[ -n ${DISTRO_OVERRIDE:-} ]]; then
		id=$DISTRO_OVERRIDE
		like=''
		pretty="$id (override)"
	fi

	case $id in
	arch | manjaro | manjaro-arm | endeavouros | garuda | cachyos | artix | arcolinux)
		PKG_BACKEND=pacman
		;;
	fedora | rhel | centos | rocky | almalinux | nobara | bazzite | ultramarine)
		PKG_BACKEND=dnf
		;;
	opensuse* | suse | sles | tumbleweed | leap | slowroll)
		PKG_BACKEND=zypper
		;;
	debian | ubuntu | linuxmint | pop | elementary | kali | raspbian | neon | zorin)
		die "Debian-based distributions are intentionally unsupported (no apt backend)"
		;;
	*)
		case " $like " in
		*debian* | *ubuntu*) die "Debian-based distributions are intentionally unsupported (no apt backend)" ;;
		*arch*) PKG_BACKEND=pacman ;;
		*fedora* | *rhel* | *centos*) PKG_BACKEND=dnf ;;
		*suse* | *sles*) PKG_BACKEND=zypper ;;
		*) PKG_BACKEND=${PKG_BACKEND:-} ;;
		esac
		;;
	esac

	[[ -n $PKG_BACKEND ]] || die "unsupported distribution '${id:-unknown}' (supported: Arch, Fedora, openSUSE)"

	DISTRO_ID=$id
	DISTRO_LIKE=$like
	DISTRO_PRETTY=$pretty
	case $PKG_BACKEND in
	pacman) DISTRO_FAMILY=arch ;;
	dnf) DISTRO_FAMILY=fedora ;;
	zypper) DISTRO_FAMILY=opensuse ;;
	esac
	export PKG_BACKEND DISTRO_FAMILY DISTRO_ID DISTRO_LIKE DISTRO_PRETTY

	log_info "distro: $DISTRO_PRETTY (backend: $PKG_BACKEND)"
	if ((DRY_RUN)); then
		command -v "$PKG_BACKEND" >/dev/null 2>&1 ||
			log_info "dry-run: $PKG_BACKEND is not installed on this host"
		return 0
	fi
	case $PKG_BACKEND in
	pacman) command -v pacman >/dev/null || die "pacman not found" ;;
	dnf) command -v dnf >/dev/null || die "dnf not found" ;;
	zypper) command -v zypper >/dev/null || die "zypper not found" ;;
	esac
}

is_arch_family() { [[ $DISTRO_FAMILY == arch ]]; }

# ------------------------------------------------------------------- lists --
# Print package names from one or more list files (comments and blanks skipped).
list_pkgs() {
	grep -vhE '^[[:space:]]*(#|$)' "$@" | awk '{print $1}'
}

# Resolve one canonical (Arch) package name to zero or more native packages.
pkg_translate() {
	local name=$1 map="$REPO/packages/maps/${DISTRO_FAMILY}.map"
	if [[ $PKG_BACKEND == pacman || ! -f $map ]]; then
		printf '%s\n' "$name"
		return 0
	fi

	local pattern targets found exact=0
	# First pass: exact match.
	while IFS= read -r line; do
		[[ -z $line || $line == \#* ]] && continue
		pattern=${line%%[[:space:]]*}
		[[ $pattern == "$name" ]] || continue
		targets=${line#"$pattern"}
		exact=1
		break
	done <"$map"
	# Second pass: glob (only when no exact match was found).
	if ((!exact)); then
		while IFS= read -r line; do
			[[ -z $line || $line == \#* ]] && continue
			pattern=${line%%[[:space:]]*}
			[[ $pattern == "$name" ]] && continue
			# shellcheck disable=SC2053 # intentional glob match
			if [[ $name == $pattern ]]; then
				targets=${line#"$pattern"}
				exact=1
				break
			fi
		done <"$map"
	fi

	if ((!exact)); then
		printf '%s\n' "$name"
		return 0
	fi
	read -r -a _targets <<<"${targets//,/ }"
	for t in "${_targets[@]}"; do
		[[ $t == '-' ]] && continue
		printf '%s\n' "$t"
	done
}

# Expand a list file into native package names (deduplicated).
pkg_expand_file() {
	local file=$1 p t
	while IFS= read -r p; do
		[[ -n $p ]] || continue
		while IFS= read -r t; do
			[[ -n $t ]] && printf '%s\n' "$t"
		done < <(pkg_translate "$p")
	done < <(list_pkgs "$file") | awk '!seen[$0]++'
}

# ---------------------------------------------------------------- backends --
pkg_refresh() {
	log_info "refreshing package databases (full upgrade)"
	case $PKG_BACKEND in
	pacman) sudo_run pacman -Syu --noconfirm ;;
	dnf) sudo_run dnf -y --refresh upgrade ;;
	zypper)
		sudo_run zypper --non-interactive refresh
		if grep -qi 'tumbleweed\|slowroll' /etc/os-release 2>/dev/null; then
			sudo_run zypper --non-interactive dup
		else
			sudo_run zypper --non-interactive update
		fi
		;;
	esac
}

# Base build dependencies: a compiler, git, curl, tar.
pkg_base_devel() {
	log_info "installing base build dependencies"
	case $PKG_BACKEND in
	pacman) pkg_install base-devel git curl ;;
	dnf) pkg_install @development-tools git curl tar ;;
	zypper)
		sudo_run zypper --non-interactive install -t pattern devel_basis
		pkg_install git curl tar
		;;
	esac
}

_pkg_install_cmd() {
	local -a pkgs=("$@")
	case $PKG_BACKEND in
	pacman) sudo_run pacman -S --needed --noconfirm "${pkgs[@]}" ;;
	dnf) sudo_run dnf install -y --setopt=install_weak_deps=False "${pkgs[@]}" ;;
	zypper) sudo_run zypper --non-interactive install --no-recommends "${pkgs[@]}" ;;
	esac
}

_pkg_install_one() {
	local p=$1
	case $PKG_BACKEND in
	pacman) sudo pacman -S --needed --noconfirm "$p" ;;
	dnf) sudo dnf install -y --setopt=install_weak_deps=False "$p" ;;
	zypper) sudo zypper --non-interactive install --no-recommends "$p" ;;
	esac
}

# pkg_install <native packages...> - batch install, then per-package retry.
pkg_install() {
	(($#)) || return 0
	if ((DRY_RUN)); then
		case $PKG_BACKEND in
		pacman) log_cmd "sudo pacman -S --needed --noconfirm $*" ;;
		dnf) log_cmd "sudo dnf install -y --setopt=install_weak_deps=False $*" ;;
		zypper) log_cmd "sudo zypper --non-interactive install --no-recommends $*" ;;
		esac
		return 0
	fi
	if _pkg_install_cmd "$@"; then
		return 0
	fi
	log_warn "batch install failed, retrying one by one"
	local p rc=0
	for p in "$@"; do
		if ! _pkg_install_one "$p"; then
			if ((STRICT_PKGS)); then
				log_err "$PKG_BACKEND could not install: $p"
				rc=1
			else
				log_warn "skipped unavailable package: $p"
			fi
		fi
	done
	return $rc
}

# pkg_group <file> - install one canonical package list on the current distro.
pkg_group() {
	local file=$1
	local -a pkgs
	mapfile -t pkgs < <(pkg_expand_file "$file")
	((${#pkgs[@]})) || {
		log_info "nothing to install from $(basename "$file") on $DISTRO_ID"
		return 0
	}
	log_info "$PKG_BACKEND: ${#pkgs[@]} package(s) from $(basename "$file")"
	pkg_install "${pkgs[@]}"
}

# A group that is nice-to-have: never fail the run when packages are absent.
pkg_group_optional() {
	local file=$1
	local -a pkgs
	mapfile -t pkgs < <(pkg_expand_file "$file")
	((${#pkgs[@]})) || return 0
	log_info "$PKG_BACKEND: ${#pkgs[@]} optional package(s) from $(basename "$file")"
	if ((DRY_RUN)); then
		pkg_install "${pkgs[@]}"
		return 0
	fi
	local p
	for p in "${pkgs[@]}"; do
		_pkg_install_one "$p" 2>/dev/null || log_warn "optional package unavailable: $p"
	done
}

# ---------------------------------------------------------------- Arch bits --
# Enable the multilib repository (needed for steam / wine / lib32-vulkan).
enable_multilib() {
	is_arch_family || return 0
	if grep -qE '^\[multilib\]' /etc/pacman.conf; then
		log_ok "multilib already enabled"
		return 0
	fi
	log_info "enabling [multilib] in /etc/pacman.conf"
	sudo_run cp -a /etc/pacman.conf "/etc/pacman.conf.bak-$STAMP"
	sudo_run sed -i -e 's/^#\[multilib\]/[multilib]/' -e '/^\[multilib\]/{n;s/^#[[:space:]]*Include/Include/}' /etc/pacman.conf
}

ensure_aur_helper() {
	is_arch_family || return 0
	if command -v "$AUR_HELPER" >/dev/null 2>&1; then
		log_ok "AUR helper available: $AUR_HELPER"
		return 0
	fi
	if command -v yay >/dev/null 2>&1; then
		AUR_HELPER=yay
		log_ok "AUR helper available: $AUR_HELPER"
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

aur_available() {
	is_arch_family && command -v "$AUR_HELPER" >/dev/null 2>&1
}

# aur_group <file> - Arch: AUR helper; other distros: translated native pass.
aur_group() {
	local file=$1
	if aur_available; then
		local -a pkgs
		mapfile -t pkgs < <(list_pkgs "$file")
		((${#pkgs[@]})) || return 0
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
		return 0
	fi

	# Non-Arch: 90-aur.txt is used as a source of *optional* native packages.
	log_info "no AUR on $DISTRO_ID - translating $(basename "$file") to native packages"
	pkg_group_optional "$file"
}

# -------------------------------------------------------------- inspection --
# Installed package names (best effort, used by scripts/check-packages.sh).
pkg_list_installed() {
	case $PKG_BACKEND in
	pacman) pacman -Qq | sort -u ;;
	dnf | zypper) rpm -qa --qf '%{NAME}\n' | sort -u ;;
	esac
}

pkg_list_explicit() {
	case $PKG_BACKEND in
	pacman) pacman -Qqen | sort -u ;;
	dnf)
		# dnf history userinstalled is fragile; fall back to everything.
		rpm -qa --qf '%{NAME}\n' | sort -u
		;;
	zypper) rpm -qa --qf '%{NAME}\n' | sort -u ;;
	esac
}
