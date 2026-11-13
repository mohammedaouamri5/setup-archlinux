# shellcheck shell=bash
# Config deployment driven by config/manifest.txt. Sourced by install.sh.

[[ -n "${_LIB_CONFIGS_SH:-}" ]] && return 0
_LIB_CONFIGS_SH=1

: "${REPO:?REPO must be set before sourcing lib/configs.sh}"

MANIFEST=${MANIFEST:-$REPO/config/manifest.txt}

manifest_entries() {
	[[ -f $MANIFEST ]] || die "missing manifest: $MANIFEST"
	grep -vE '^[[:space:]]*(#|$)' "$MANIFEST"
}

update_submodules() {
	if ((UPDATE_SUBMODULES)); then
		log_info "updating submodules to latest upstream commits"
		run git submodule update --init --recursive --remote
	else
		run git submodule update --init --recursive
	fi
}

# The real collection lives in ~/wallpapers; ~/Wallpapers is a symlink kept
# because the Quickshell config stores the capitalised path.
ensure_wallpaper_dir() {
	if [[ -d $HOME/Wallpapers && ! -L $HOME/Wallpapers && ! -e $HOME/wallpapers ]]; then
		run mv "$HOME/Wallpapers" "$HOME/wallpapers"
	elif [[ -d $HOME/Wallpapers && ! -L $HOME/Wallpapers ]]; then
		log_warn "$HOME/Wallpapers is a real directory (expected a symlink to ~/wallpapers)"
	fi
	run mkdir -p "$HOME/wallpapers"
	if [[ ! -e $HOME/Wallpapers ]]; then
		run ln -s wallpapers "$HOME/Wallpapers"
	fi
	run mkdir -p "$HOME/.local/bin" "$HOME/.local/opt"
}

# Deploy every manifest entry. Missing sources only warn: the repo is allowed to
# be a partial snapshot (for example on a fresh clone without the live configs).
deploy_configs() {
	local kind a b src dst

	while read -r kind a b; do
		case $kind in
		submodule)
			src="$REPO/submodules/$a"
			dst="$HOME/$b"
			if [[ -d $src ]]; then
				link_dir "$src" "$dst"
			else
				log_warn "submodule not checked out, skipping: $a (run git submodule update --init)"
			fi
			;;
		link-dir)
			src="$REPO/config/$a"
			dst="$HOME/$a"
			[[ -d $src ]] || {
				log_warn "not captured, skipping dir: $a"
				continue
			}
			link_dir "$src" "$dst"
			;;
		link-file)
			src="$REPO/config/$a"
			dst="$HOME/$a"
			[[ -e $src ]] || {
				log_warn "not captured, skipping file: $a"
				continue
			}
			link_file "$src" "$dst"
			;;
		copy-file)
			src="$REPO/config/$a"
			dst="$HOME/$a"
			[[ -e $src ]] || {
				log_warn "not captured, skipping copy: $a"
				continue
			}
			copy_file "$src" "$dst"
			;;
		render-file)
			src="$REPO/config/$a"
			dst="$HOME/$a"
			[[ -e $src ]] || {
				log_warn "not captured, skipping render: $a"
				continue
			}
			render_copy "$src" "$dst"
			;;
		render-tmpl)
			src="$REPO/config/$a"
			dst="$HOME/$b"
			[[ -e $src ]] || {
				log_warn "not captured, skipping template: $a"
				continue
			}
			local tmp
			tmp=$(mktemp)
			sed "s|@HOME@|$HOME|g" "$src" >"$tmp"
			copy_file "$tmp" "$dst"
			rm -f "$tmp"
			;;
		*)
			die "bad manifest line: $kind $a $b"
			;;
		esac
	done < <(manifest_entries)
}

# end4-pC stores its runtime settings in ~/.config/illogical-impulse, not in
# ~/.config/quickshell. If an old `ii` install is still around, fold its user
# data into end4-pC's config directory and move the old tree out of the way.
migrate_legacy_ii() {
	local legacy=$HOME/.config/quickshell/ii
	local cfg=$HOME/.config/illogical-impulse
	[[ -d $legacy ]] || return 0

	log_info "legacy Quickshell 'ii' config found - migrating user data to end4-pC"
	run mkdir -p "$cfg"

	# Directories end4-pC reads from its config folder.
	local sub
	for sub in actions presets ai schemes; do
		[[ -d $legacy/$sub ]] || continue
		if ((DRY_RUN)); then
			log_cmd "cp -an '$legacy/$sub/.' '$cfg/$sub/'"
		else
			mkdir -p "$cfg/$sub"
			cp -an "$legacy/$sub/." "$cfg/$sub/" 2>/dev/null || true
			log_ok "merged $sub/ from legacy ii"
		fi
	done

	# Never overwrite the freshly deployed end4-pC config.json.
	if [[ -f $legacy/config.json ]]; then
		copy_file "$legacy/config.json" "$cfg/config.json.ii-migrated-$STAMP"
	fi

	# Keep the old tree as a timestamped backup instead of deleting it.
	backup_path "$legacy"
}
