# shellcheck shell=bash
# Symlink / copy helpers with timestamped backups. Sourced by install.sh.

[[ -n "${_LIB_LINK_SH:-}" ]] && return 0
_LIB_LINK_SH=1

# Move an existing path out of the way (kept as <path>.bak-<stamp>).
backup_path() {
	local path=$1 bak="$1.bak-$STAMP"
	[[ -e $path || -L $path ]] || return 0
	if ((DRY_RUN)); then
		log_cmd "mv '$path' '$bak'"
		return 0
	fi
	mv -f "$path" "$bak"
	log_warn "backed up $path -> $bak"
}

# Point <dst> at <src> with a symlink. Refuses to replace a real directory.
link_file() {
	local src dst
	src=$(realpath "$1")
	dst=$2
	if [[ -L $dst && $(readlink -f "$dst") == "$src" ]]; then
		log_ok "already linked: $dst"
		return 0
	fi
	if [[ -d $dst && ! -L $dst ]]; then
		die "refusing to replace directory $dst with a file symlink"
	fi
	if ((DRY_RUN)); then
		log_cmd "mkdir -p '$(dirname "$dst")'"
	else
		mkdir -p "$(dirname "$dst")"
	fi
	backup_path "$dst"
	run ln -s "$src" "$dst"
	log_ok "$dst -> $src"
}

# Replace <dst> directory with a symlink to <src>. Refuses to delete a git
# worktree with uncommitted changes unless --force.
link_dir() {
	local src dst
	src=$(realpath "$1")
	dst=$2
	if [[ -L $dst && $(readlink -f "$dst") == "$src" ]]; then
		log_ok "already linked: $dst"
		return 0
	fi
	if [[ -d $dst && ! -L $dst ]]; then
		if [[ -d $dst/.git ]] && [[ -n $(git -C "$dst" status --porcelain --untracked-files=no 2>/dev/null) ]] && ((!FORCE)); then
			die "$dst has uncommitted changes - commit/push them first, or re-run with --force"
		fi
	fi
	if ((DRY_RUN)); then
		log_cmd "mkdir -p '$(dirname "$dst")'"
	else
		mkdir -p "$(dirname "$dst")"
	fi
	backup_path "$dst"
	run ln -s "$src" "$dst"
	log_ok "$dst -> $src"
}

# Copy a single file, skipping when content is already identical.
copy_file() {
	local src dst
	src=$(realpath "$1")
	dst=$2
	if [[ -f $dst && ! -L $dst ]] && cmp -s "$src" "$dst"; then
		log_ok "up to date: $dst"
		return 0
	fi
	if ((DRY_RUN)); then
		log_cmd "mkdir -p '$(dirname "$dst")'"
	else
		mkdir -p "$(dirname "$dst")"
	fi
	backup_path "$dst"
	run cp -a "$src" "$dst"
	log_ok "copied: $dst"
}

# Copy a file while replacing the canonical home path (REPO_HOME) with $HOME.
# Used for app state that stores absolute paths and cannot contain symlinks.
render_copy() {
	local src dst tmp
	src=$(realpath "$1")
	dst=$2
	tmp=$(mktemp)
	sed "s|${REPO_HOME:-/home/mohammedaouamri}|$HOME|g" "$src" >"$tmp"
	copy_file "$tmp" "$dst"
	rm -f "$tmp"
}

# Install a root-owned file (/etc, xkb, ...) with a sudo backup.
sudo_install() {
	local src dst
	src=$(realpath "$1")
	dst=$2
	if ((DRY_RUN)); then
		log_cmd "install -D -m 644 '$src' '$dst'"
		return 0
	fi
	if [[ -f $dst && ! -L $dst ]] && cmp -s "$src" "$dst" 2>/dev/null; then
		log_ok "up to date: $dst"
		return 0
	fi
	if [[ -e $dst || -L $dst ]]; then
		sudo_run cp -a "$dst" "$dst.bak-$STAMP"
		log_warn "backed up $dst -> $dst.bak-$STAMP"
	fi
	sudo_run install -D -m 644 "$src" "$dst"
	log_ok "installed: $dst"
}

# Clone a git repo if the target directory does not exist.
clone_if_missing() {
	local url=$1 dst=$2
	shift 2
	if [[ -d $dst ]]; then
		log_ok "present: $dst"
		return 0
	fi
	log_info "cloning $url"
	run git clone "$@" "$url" "$dst"
}
