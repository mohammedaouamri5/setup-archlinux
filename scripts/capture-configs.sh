#!/usr/bin/env bash
# Capture the live dotfiles listed in config/manifest.txt into config/.
#
#   ./scripts/capture-configs.sh            # refresh config/ from $HOME
#   ./scripts/capture-configs.sh --dry-run  # show what would be copied
#   ./scripts/capture-configs.sh --keep     # do not delete stale files first
#   ./scripts/capture-configs.sh --force    # also overwrite curated files
#
# Secrets and app state are never captured because they are not in the
# manifest: no ~/.ssh, ~/.gnupg, gh auth, opencode/service.json, browser
# profiles, caches or model files.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST="$REPO/config/manifest.txt"
REPO_HOME="${REPO_HOME:-/home/mohammedaouamri}"

DRY_RUN=0
KEEP=0
FORCE=0
for arg in "$@"; do
	case $arg in
	--dry-run) DRY_RUN=1 ;;
	--keep) KEEP=1 ;;
	--force) FORCE=1 ;;
	-h | --help)
		sed -n '2,14p' "$0"
		exit 0
		;;
	*)
		echo "unknown option: $arg" >&2
		exit 2
		;;
	esac
done

[[ -f $MANIFEST ]] || {
	echo "missing $MANIFEST" >&2
	exit 1
}

# Paths that are state, secrets or build noise even inside a captured dir.
EXCLUDES=(
	'.git'
	'__pycache__'
	'*.pyc'
	'*.bak'
	'*.bak-*'
	'*.log'
	'*.log.*'
	'*.tmp'
	'*.zip'
	'odysseus.service'
	'openclaw-gateway.service'
	'Logs'
	'FontsOpenAtLastQuit'
	'globalStorage'
	'*.wants'
	'Cache'
	'cache'
)

warn() { printf '!! %s\n' "$*" >&2; }
info() { printf ':: %s\n' "$*"; }
ok() { printf 'ok %s\n' "$*"; }

# Files that were deliberately made portable by hand (no hard-coded $HOME,
# no optional homebrew/pyenv calls). A blind capture would undo that, so they
# are only refreshed with --force.
is_protected() {
	case $1 in
	.zshrc | .config/yay/config.json | .config/fish/config.fish | .config/starship.toml) return 0 ;;
	*) return 1 ;;
	esac
}

copy_file() {
	local rel=$1 src=$HOME/$1 dest=$REPO/config/$1
	if [[ ! -e $src ]]; then
		warn "not present, skipping: $rel"
		return 0
	fi
	if is_protected "$rel" && ((!FORCE)) && [[ -e $dest ]]; then
		info "curated file kept: $rel (use --force to overwrite)"
		return 0
	fi
	if ((DRY_RUN)); then
		printf '+ copy %s\n' "$rel"
		return 0
	fi
	mkdir -p "$(dirname "$dest")"
	cp -a "$src" "$dest"
	ok "captured $rel"
}

copy_dir() {
	local rel=$1 src=$HOME/$1 dest=$REPO/config/$1
	if [[ ! -d $src ]]; then
		warn "not present, skipping: $rel"
		return 0
	fi
	if is_protected "$rel" && ((!FORCE)) && [[ -e $dest ]]; then
		info "curated dir kept: $rel (use --force to overwrite)"
		return 0
	fi
	if ((DRY_RUN)); then
		printf '+ copy dir %s\n' "$rel"
		return 0
	fi
	[[ $dest == "$REPO/config/"* ]] || {
		echo "refusing to write outside config/: $dest" >&2
		exit 1
	}
	if ((!KEEP)); then
		rm -rf "$dest"
	fi
	mkdir -p "$dest"
	local -a exclude_args=()
	local e
	for e in "${EXCLUDES[@]}"; do
		exclude_args+=(--exclude="$e")
	done
	tar -C "$src" -cf - "${exclude_args[@]}" . | tar -C "$dest" -xf -
	ok "captured dir $rel"
}

render_home_back() {
	local rel=$1
	((DRY_RUN)) && return 0
	[[ -f $REPO/config/$rel ]] || return 0
	[[ $HOME == "$REPO_HOME" ]] && return 0
	sed -i "s|$HOME|$REPO_HOME|g" "$REPO/config/$rel"
	ok "rewrote $HOME -> $REPO_HOME in $rel"
}

while read -r kind a b; do
	case $kind in
	submodule) : ;; # submodules are captured by their own git repos
	link-dir) copy_dir "$a" ;;
	link-file | copy-file) copy_file "$a" ;;
	render-file)
		copy_file "$a"
		render_home_back "$a"
		;;
	render-tmpl) info "template kept as-is: $a" ;;
	*) warn "bad manifest line: $kind $a $b" ;;
	esac
done < <(grep -vE '^[[:space:]]*(#|$)' "$MANIFEST")

# A cheap safety net: flag obvious credentials that slipped in.
if ((!DRY_RUN)); then
	matches=$(grep -rIlE 'BEGIN (OPENSSH|RSA|EC|PGP) PRIVATE KEY|"?(api[_-]?key|auth[_-]?token|password)"?[[:space:]]*[:=][[:space:]]*"[^"]{12,}"' \
		"$REPO/config" 2>/dev/null || true)
	if [[ -n $matches ]]; then
		warn "possible secrets captured - review these files before committing:"
		printf '   %s\n' $matches
	else
		info "secret scan: clean"
	fi
fi

echo
echo "Captured manifest entries into $REPO/config/"
echo "Next: ./install.sh --dry-run --stage configs"
