#!/usr/bin/env bash
# =============================================================================
#  recon.sh — Main orchestrator
#  Usage: ./recon.sh [-d domain] [-s scope.txt] [-r] [-p] [--no-menu]
# =============================================================================
set -uo pipefail

FRAMEWORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------------
# SOURCE UTILITIES
# -----------------------------------------------------------------------------
source "$FRAMEWORK_DIR/utils/helpers.sh"
source "$FRAMEWORK_DIR/utils/menu.sh"
source "$FRAMEWORK_DIR/utils/notify.sh"
source "$FRAMEWORK_DIR/utils/dedupe.sh"
source "$FRAMEWORK_DIR/utils/validate.sh"
source "$FRAMEWORK_DIR/utils/report.sh"

# Load config — local override takes priority
if [[ -f "$FRAMEWORK_DIR/config.local.conf" ]]; then
    source "$FRAMEWORK_DIR/config.local.conf"
elif [[ -f "$FRAMEWORK_DIR/config.conf" ]]; then
    source "$FRAMEWORK_DIR/config.conf"
fi

# -----------------------------------------------------------------------------
# DEFAULTS
# -----------------------------------------------------------------------------
DOMAIN=""
SCOPE_FILE=""
RESUME=false
PASSIVE_ONLY="${PASSIVE_ONLY:-false}"
NO_MENU=false
CONFIG_FILE=""
RUN_ID="$(date '+%Y-%m-%d_%H-%M-%S')"

declare -a SELECTED_MODULES=()
declare -a SKIPPED_STAGES=()
declare -a FAILED_STAGES=()

TOTAL_SUBS=0
TOTAL_RESOLVED=0
TOTAL_ALIVE=0
TOTAL_URLS=0

# -----------------------------------------------------------------------------
# ARGUMENT PARSING
# -----------------------------------------------------------------------------
usage() {
    cat << USAGE
${BOLD}Usage:${NC}
  $(basename "$0") -d <domain>            Single domain
  $(basename "$0") -s <scope.txt>         Multiple targets from scope file
  $(basename "$0") -d <domain> -r         Resume interrupted run
  $(basename "$0") -d <domain> --no-menu  Skip menu, use config.conf defaults

${BOLD}Options:${NC}
  -d  DOMAIN       Target domain
  -s  FILE         Scope file (one target per line)
  -r               Resume from last checkpoint
  -p               Passive only (no active scanning)
  --no-menu        Skip interactive stage selection
  --config FILE    Use alternate config file
  -h               Show this help
USAGE
}

parse_args() {
    [[ $# -eq 0 ]] && { print_banner; usage; exit 0; }

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d)          DOMAIN="$(clean_target "${2:-}")"; shift 2 ;;
            -s)          SCOPE_FILE="${2:-}"; shift 2 ;;
            -r)          RESUME=true; shift ;;
            -p)          PASSIVE_ONLY=true; shift ;;
            --no-menu)   NO_MENU=true; shift ;;
            --config)    CONFIG_FILE="${2:-}"; shift 2 ;;
            -h|--help)   print_banner; usage; exit 0 ;;
            *)           error "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    # Load alternate config if provided
    if [[ -n "$CONFIG_FILE" ]]; then
        [[ -f "$CONFIG_FILE" ]] || { error "Config file not found: $CONFIG_FILE"; exit 1; }
        source "$CONFIG_FILE"
    fi

    # Build target list
    if [[ -z "$DOMAIN" && -z "$SCOPE_FILE" ]]; then
        error "Provide a domain (-d) or scope file (-s)"
        usage; exit 1
    fi
}

# -----------------------------------------------------------------------------
# DIRECTORY SETUP
# -----------------------------------------------------------------------------
setup_dirs() {
    local TARGET="$1"
    BASE_DIR="${OUTPUT_DIR:-recon}/$TARGET"

    ENUM_DIR="$BASE_DIR/enum"
    DNS_DIR="$BASE_DIR/dns"
    HTTP_DIR="$BASE_DIR/http"
    PORTS_DIR="$BASE_DIR/ports"
    CRAWL_DIR="$BASE_DIR/crawl"
    PARAMS_DIR="$BASE_DIR/params"
    JS_DIR="$BASE_DIR/js"
    JS_DOWNLOAD_DIR="$JS_DIR/downloads"
    JS_SECRET_DIR="$JS_DIR/secrets"
    CONTENT_DIR="$BASE_DIR/content"
    VULN_DIR="$BASE_DIR/vuln"
    SCREENSHOT_DIR="$BASE_DIR/screenshots"
    CLOUD_DIR="$BASE_DIR/cloud"
    OSINT_DIR="$BASE_DIR/osint"
    LOG_DIR="$BASE_DIR/logs"

    mkdir -p \
        "$ENUM_DIR" "$DNS_DIR" "$HTTP_DIR" "$PORTS_DIR" \
        "$CRAWL_DIR" "$PARAMS_DIR" "$JS_DIR" "$JS_DOWNLOAD_DIR" \
        "$JS_SECRET_DIR" "$CONTENT_DIR" "$VULN_DIR" \
        "$SCREENSHOT_DIR" "$CLOUD_DIR" "$OSINT_DIR" "$LOG_DIR"

    LOG_FILE="$LOG_DIR/recon_${RUN_ID}.log"
    exec > >(tee -a "$LOG_FILE") 2>&1
}

# -----------------------------------------------------------------------------
# MODULE RUNNER
# -----------------------------------------------------------------------------
run_modules() {
    for MODULE in "${SELECTED_MODULES[@]}"; do
        local MODULE_FILE="$FRAMEWORK_DIR/modules/${MODULE}.sh"

        if [[ ! -f "$MODULE_FILE" ]]; then
            warn "Module file not found: $MODULE_FILE — skipping"
            continue
        fi

        # Resume: skip completed stages
        if [[ "$RESUME" == "true" ]] && stage_done "$MODULE"; then
            info "Resuming — skipping already completed: $MODULE"
            continue
        fi

        # Source and run the module
        (
            source "$MODULE_FILE"
            run_module
        )

        local EXIT=$?
        if [[ $EXIT -eq 0 ]]; then
            mark_stage_done "$MODULE"
        elif [[ $EXIT -eq 1 ]]; then
            SKIPPED_STAGES+=("$MODULE")
        else
            FAILED_STAGES+=("$MODULE")
        fi
    done
}

# -----------------------------------------------------------------------------
# SINGLE TARGET RUNNER
# -----------------------------------------------------------------------------
run_target() {
    DOMAIN="$(clean_target "$1")"

    setup_dirs "$DOMAIN"
    init_state

    stage "Target: $DOMAIN"
    info "Run ID: $RUN_ID"
    info "Output: $BASE_DIR"
    info "Log:    $LOG_FILE"

    [[ "${NOTIFY_ON_COMPLETION:-false}" == "true" ]] && notify_start

    run_modules

    generate_report

    [[ "${NOTIFY_ON_COMPLETION:-false}" == "true" ]] && notify_complete

    print_summary
}

# -----------------------------------------------------------------------------
# MAIN
# -----------------------------------------------------------------------------
main() {
    parse_args "$@"
    print_banner
    preflight

    # Show menu once — applies to all targets
    show_menu

    if [[ -n "$SCOPE_FILE" ]]; then
        [[ -f "$SCOPE_FILE" ]] || { error "Scope file not found: $SCOPE_FILE"; exit 1; }
        while IFS= read -r TARGET; do
            [[ "$TARGET" =~ ^# || -z "$TARGET" ]] && continue
            run_target "$TARGET"
        done < "$SCOPE_FILE"
    else
        run_target "$DOMAIN"
    fi
}

main "$@"
