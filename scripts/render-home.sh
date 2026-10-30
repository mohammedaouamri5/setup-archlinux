#!/usr/bin/env bash
# Rewrite the home directory the repo was captured from.
#
# The dotfiles in config/ contain absolute paths from /home/mohammedaouamri.
# install.sh already substitutes them for files it copies, but symlinked files
# cannot be rewritten at install time. Run this once after cloning if your
# username or home path is different:
#
#   ./scripts/render-home.sh                 # /home/mohammedaouamri -> $HOME
#   ./scripts/render-home.sh /home/old /home/new
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OLD="${1:-/home/mohammedaouamri}"
NEW="${2:-$HOME}"

if [[ $OLD == "$NEW" ]]; then
	echo "nothing to do ($OLD == $NEW)"
	exit 0
fi

count=0
while IFS= read -r file; do
	sed -i "s|$OLD|$NEW|g" "$file"
	echo "rewrote $file"
	count=$((count + 1))
done < <(grep -rlI -- "$OLD" "$REPO/config" "$REPO/system" 2>/dev/null || true)

echo "updated $count file(s): $OLD -> $NEW"
