#!/usr/bin/env bash
# Download the wallpapers listed in config/wallpapers/urls.txt into ~/Wallpapers.
#
#   ./scripts/fetch-wallpapers.sh
#   WALLPAPER_DIR=/mnt/data/walls ./scripts/fetch-wallpapers.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
URLS="$REPO/config/wallpapers/urls.txt"
DEST="${WALLPAPER_DIR:-$HOME/Wallpapers}"

if [[ ! -f $URLS ]]; then
	echo "missing $URLS" >&2
	exit 1
fi

mapfile -t urls < <(grep -vE '^[[:space:]]*(#|$)' "$URLS")
if ((${#urls[@]} == 0)); then
	echo "no wallpapers configured in $URLS"
	exit 0
fi

if printf '%s\n' "${urls[@]}" | grep -q 'example\.com'; then
	echo "!! urls.txt still contains example.com placeholders - edit it first"
fi

mkdir -p "$DEST"
echo "downloading ${#urls[@]} wallpaper(s) into $DEST"

if command -v aria2c >/dev/null 2>&1; then
	aria2c --input-file="$URLS" --dir="$DEST" \
		--continue=true --auto-file-renaming=false --allow-overwrite=false \
		--max-concurrent-downloads=4 --console-log-level=warn
else
	echo "aria2c not found, falling back to curl"
	for url in "${urls[@]}"; do
		case $url in
		*example.com*) echo "skip placeholder: $url"; continue ;;
		esac
		curl -fL --retry 3 --continue-at - -O --output-dir "$DEST" "$url" ||
			echo "!! failed: $url"
	done
fi

echo "done - files in $DEST"
