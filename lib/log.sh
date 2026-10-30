# shellcheck shell=bash
# Logging, colors and dry-run helpers. Sourced by install.sh.

[[ -n "${_LIB_LOG_SH:-}" ]] && return 0
_LIB_LOG_SH=1

if [[ -t 1 ]]; then
	C_RESET=$'\e[0m'
	C_RED=$'\e[31m'
	C_GREEN=$'\e[32m'
	C_YELLOW=$'\e[33m'
	C_BLUE=$'\e[36m'
	C_DIM=$'\e[2m'
else
	C_RESET='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_DIM=''
fi

DRY_RUN=${DRY_RUN:-0}
FORCE=${FORCE:-0}
LOG_FILE=${LOG_FILE:-}
STAMP=${STAMP:-$(date +%Y%m%d-%H%M%S)}
WARNINGS=${WARNINGS:-0}
ERRORS=${ERRORS:-0}

_log() {
	local level=$1 color=$2
	shift 2
	printf '%s%s%s %s\n' "$color" "$level" "$C_RESET" "$*"
	if [[ -n $LOG_FILE ]]; then
		printf '%s [%s] %s\n' "$(date '+%F %T')" "$level" "$*" >>"$LOG_FILE"
	fi
}

log_info() { _log '::' "$C_BLUE" "$*"; }
log_ok() { _log 'ok' "$C_GREEN" "$*"; }
log_warn() {
	WARNINGS=$((WARNINGS + 1))
	_log '!!' "$C_YELLOW" "$*"
}
log_err() {
	ERRORS=$((ERRORS + 1))
	_log 'xx' "$C_RED" "$*" >&2
}
log_cmd() { printf '%s+ %s%s\n' "$C_DIM" "$*" "$C_RESET"; }
die() {
	log_err "$*"
	exit 1
}

# run <cmd...> - execute, or print it in dry-run mode.
run() {
	if ((DRY_RUN)); then
		log_cmd "$*"
		return 0
	fi
	"$@"
}

# run_sh <shell string> - for pipelines and redirections.
run_sh() {
	if ((DRY_RUN)); then
		log_cmd "$1"
		return 0
	fi
	bash -c "$1"
}

sudo_run() {
	if ((DRY_RUN)); then
		log_cmd "sudo $*"
		return 0
	fi
	sudo "$@"
}

summary() {
	echo
	if ((WARNINGS == 0 && ERRORS == 0)); then
		log_ok "finished with no warnings"
	elif ((ERRORS == 0)); then
		log_warn "finished with $WARNINGS warning(s)"
	else
		log_err "finished with $ERRORS error(s) and $WARNINGS warning(s)"
	fi
}
