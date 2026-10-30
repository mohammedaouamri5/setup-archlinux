#!/usr/bin/env bash
# Compare packages/*.txt with what is actually installed on this machine.
#
#   ./scripts/check-packages.sh            # report drift, exit 1 if any
#   ./scripts/check-packages.sh --write-raw # also dump the raw lists into packages/
#
# Expected differences (AUR helper + debug splits) are whitelisted below.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

NATIVE_FILES=(packages/0*.txt packages/1*.txt packages/2*.txt packages/3*.txt packages/4*.txt packages/5*.txt)
AUR_FILE=packages/90-aur.txt

# Packages that intentionally differ from the snapshot.
EXPECTED_MISSING_AUR=(paru paru-bin yay-bin-debug illogical-impulse-microtex-git-debug)
EXPECTED_EXTRA_AUR=(paru-bin)

red=$'\e[31m'; green=$'\e[32m'; yellow=$'\e[33m'; reset=$'\e[0m'

list_pkgs() {
	grep -vhE '^[[:space:]]*(#|$)' "$@" | awk '{print $1}' | sort -u
}

report() { # report <label> <installed> <listed> <expected-missing...> -- <expected-extra...>
	local label=$1 installed=$2 listed=$3
	shift 3
	local expected_missing=() expected_extra=() in_extra=0 a
	for a in "$@"; do
		if [[ "$a" == "--" ]]; then in_extra=1; continue; fi
		if ((in_extra)); then expected_extra+=("$a"); else expected_missing+=("$a"); fi
	done
	local missing extra
	missing=$(comm -23 <(printf '%s\n' "$installed") \
		<(printf '%s\n' "$listed" ${expected_missing[@]+"${expected_missing[@]}"} | sort -u))
	local listed_eff=$listed
	if ((${#expected_extra[@]})); then
		for a in "${expected_extra[@]}"; do
			listed_eff=$(grep -vxF -- "$a" <<<"$listed_eff" || true)
		done
	fi
	extra=$(comm -13 <(printf '%s\n' "$installed") <(printf '%s\n' "$listed_eff" | sort -u))
	local rc=0
	if [[ -n "$missing" ]]; then
		printf '%s[%s] installed but not in packages/ lists%s\n' "$red" "$label" "$reset"
		printf '  %s\n' $missing
		rc=1
	fi
	if [[ -n "$extra" ]]; then
		printf '%s[%s] listed but not installed%s\n' "$yellow" "$label" "$reset"
		printf '  %s\n' $extra
		rc=1
	fi
	return $rc
}

native_listed=$(list_pkgs "${NATIVE_FILES[@]}")
aur_listed=$(list_pkgs "$AUR_FILE")
native_installed=$(pacman -Qqen | sort -u)
aur_installed=$(pacman -Qqem | sort -u)

rc=0
report native "$native_installed" "$native_listed" || rc=1
report aur "$aur_installed" "$aur_listed" "${EXPECTED_MISSING_AUR[@]}" -- "${EXPECTED_EXTRA_AUR[@]}" || rc=1

# duplicates across group files
dups=$(list_pkgs "${NATIVE_FILES[@]}" "$AUR_FILE" | uniq -d)
if [[ -n "$dups" ]]; then
	printf '%s[dup] listed more than once: %s%s\n' "$red" "$(echo $dups)" "$reset"
	rc=1
fi

if [[ "${1:-}" == "--write-raw" ]]; then
	pacman -Qqen | sort > packages/raw-native.txt
	pacman -Qqem | sort > packages/raw-aur.txt
	echo "wrote packages/raw-native.txt and packages/raw-aur.txt"
fi

if ((rc == 0)); then
	printf '%spackage lists match this machine%s\n' "$green" "$reset"
else
	printf '%sdrift found - fix the lists above%s\n' "$red" "$reset"
fi
exit $rc
