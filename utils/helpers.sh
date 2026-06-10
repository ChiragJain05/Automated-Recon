#!/usr/bin/env bash
# =============================================================================
#  helpers.sh — Shared utility functions
#  Sourced by recon.sh and all modules. Never executed directly.
# =============================================================================

# -----------------------------------------------------------------------------
# COLOURS
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# -----------------------------------------------------------------------------
# LOGGING
# -----------------------------------------------------------------------------
_log() {
    local LEVEL="$1"
    local COLOR="$2"
    local MSG="$3"
    local TS
    TS="$(date '+%H:%M:%S')"
    echo -e "${DIM}[$TS]${NC} ${COLOR}${BOLD}[${LEVEL}]${NC} $MSG"
}

info()    { _log "INFO"    "$BLUE"    "$1"; }
success() { _log "OK"      "$GREEN"   "$1"; }
warn()    { _log "WARN"    "$YELLOW"  "$1"; }
error()   { _log "ERROR"   "$RED"     "$1"; }
debug()   { [[ "${LOG_LEVEL:-info}" == "debug" ]] && _log "DEBUG" "$MAGENTA" "$1"; }
stage()   {
    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  ▶  $1${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# -----------------------------------------------------------------------------
# TOOL CHECKS
# -----------------------------------------------------------------------------
tool_exists() {
    command -v "$1" &>/dev/null
}

require_tool() {
    local TOOL="$1"
    if ! tool_exists "$TOOL"; then
        error "Required tool '$TOOL' not found. Run ./install.sh to install dependencies."
        return 1
    fi
}

check_tools() {
    local TOOLS=("$@")
    local MISSING=()
    for t in "${TOOLS[@]}"; do
        tool_exists "$t" || MISSING+=("$t")
    done
    if [[ ${#MISSING[@]} -gt 0 ]]; then
        warn "Missing tools for this module: ${MISSING[*]}"
        return 1
    fi
    return 0
}

# -----------------------------------------------------------------------------
# SAFE RUNNER
# Runs a command only if its primary tool exists.
# Usage: safe_run <tool> <stage_label> <cmd...>
# -----------------------------------------------------------------------------
safe_run() {
    local TOOL="$1"
    local STAGE="$2"
    shift 2

    if ! tool_exists "$TOOL"; then
        warn "$TOOL not found — skipping: $STAGE"
        SKIPPED_STAGES+=("$STAGE ($TOOL missing)")
        return 1
    fi

    debug "Running: $*"

    if "$@"; then
        success "$STAGE completed"
        return 0
    else
        error "$STAGE failed (exit $?)"
        FAILED_STAGES+=("$STAGE")
        return 2
    fi
}

# -----------------------------------------------------------------------------
# STATE / CHECKPOINTING
# -----------------------------------------------------------------------------
state_file() {
    echo "${BASE_DIR}/.recon_state"
}

stage_done() {
    local STAGE="$1"
    local SF
    SF="$(state_file)"
    grep -qxF "$STAGE" "$SF" 2>/dev/null
}

mark_stage_done() {
    local STAGE="$1"
    local SF
    SF="$(state_file)"
    echo "$STAGE" >> "$SF"
    debug "Checkpoint: $STAGE"
}

init_state() {
    local SF
    SF="$(state_file)"
    if [[ ! -f "$SF" ]]; then
        cat > "$SF" << SEOF
# Recon Framework — State File
# DO NOT EDIT MANUALLY
DOMAIN="${DOMAIN}"
RUN_ID="${RUN_ID}"
STARTED="$(date '+%Y-%m-%d %H:%M:%S')"
SEOF
    fi
}

# -----------------------------------------------------------------------------
# FILE HELPERS
# -----------------------------------------------------------------------------
safe_file_exists() {
    [[ -f "$1" && -s "$1" ]]
}

count_lines() {
    safe_file_exists "$1" && wc -l < "$1" || echo 0
}

merge_and_dedup() {
    # merge_and_dedup <output_file> <input_files...>
    local OUT="$1"; shift
    cat "$@" 2>/dev/null | sed '/^[[:space:]]*$/d' | sort -u > "$OUT"
}

extract_httpx_urls() {
    local INPUT="$1"
    local OUTPUT="$2"
    if tool_exists jq; then
        jq -r 'select(.url != null) | .url' "$INPUT" 2>/dev/null | sort -u > "$OUTPUT"
    else
        warn "jq missing — using fallback parser for httpx JSON"
        sed -n 's/.*"url":"\([^"]*\)".*/\1/p' "$INPUT" 2>/dev/null | sort -u > "$OUTPUT"
    fi
}

# -----------------------------------------------------------------------------
# SCOPE VALIDATION
# Strip protocol and path, return clean domain/IP
# -----------------------------------------------------------------------------
clean_target() {
    local T="$1"
    T="${T#http://}"
    T="${T#https://}"
    T="${T%%/*}"
    echo "$T"
}

in_scope() {
    # Basic scope check — target must end with one of the scope entries
    local TARGET="$1"
    local SCOPE_FILE="${2:-scope.txt}"
    if [[ ! -f "$SCOPE_FILE" ]]; then return 0; fi
    while IFS= read -r line; do
        [[ "$line" =~ ^# || -z "$line" ]] && continue
        local CLEAN="${line#\*.}"
        [[ "$TARGET" == *"$CLEAN" ]] && return 0
    done < "$SCOPE_FILE"
    return 1
}

# -----------------------------------------------------------------------------
# PROGRESS BANNER
# -----------------------------------------------------------------------------
print_banner() {
    local VERSION
    VERSION="$(cat "$(dirname "${BASH_SOURCE[0]}")/../.version" 2>/dev/null || echo '1.0.0')"
    echo -e "${BOLD}${BLUE}"
    cat << 'BANNER'
  ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗
  ██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║
  ██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║
  ██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║
  ██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║
  ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝
BANNER
    echo -e "${NC}${DIM}  Recon Framework v${VERSION} — Modular Reconnaissance Pipeline${NC}"
    echo -e "${DIM}  ─────────────────────────────────────────────────────────${NC}"
    echo ""
}

print_summary() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  SUMMARY — $DOMAIN${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${CYAN}Subdomains found:${NC}   ${TOTAL_SUBS:-0}"
    echo -e "  ${CYAN}Hosts resolved:${NC}     ${TOTAL_RESOLVED:-0}"
    echo -e "  ${CYAN}Alive hosts:${NC}        ${TOTAL_ALIVE:-0}"
    echo -e "  ${CYAN}URLs collected:${NC}     ${TOTAL_URLS:-0}"
    echo -e "  ${CYAN}Output directory:${NC}   $BASE_DIR"
    echo -e "  ${CYAN}Report:${NC}             $BASE_DIR/report.html"
    echo ""

    if [[ ${#SKIPPED_STAGES[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}Skipped stages:${NC}"
        for s in "${SKIPPED_STAGES[@]}"; do echo -e "    ${DIM}• $s${NC}"; done
        echo ""
    fi

    if [[ ${#FAILED_STAGES[@]} -gt 0 ]]; then
        echo -e "  ${RED}Failed stages:${NC}"
        for s in "${FAILED_STAGES[@]}"; do echo -e "    ${DIM}• $s${NC}"; done
        echo ""
    fi

    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}
