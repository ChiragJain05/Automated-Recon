#!/usr/bin/env bash
# =============================================================================
#  menu.sh — Interactive stage selection
#  Sourced by recon.sh. Sets SELECTED_MODULES array.
# =============================================================================

# Preset mode definitions — which modules each mode enables
_preset_passive()  { SELECTED_MODULES=(01_subdomain 02_dns 11_osint); }
_preset_full()     { SELECTED_MODULES=(01_subdomain 02_dns 03_ports 04_http 05_crawl 06_js 07_params 08_content 09_vuln 10_cloud 11_osint 12_takeover); }
_preset_vuln()     { SELECTED_MODULES=(04_http 05_crawl 07_params 08_content 09_vuln 12_takeover); }
_preset_quick()    { SELECTED_MODULES=(01_subdomain 02_dns 04_http 05_crawl 09_vuln); }

# Module metadata: "id|label|description|default"
_MODULE_DEFS=(
    "01_subdomain|Subdomain Enumeration |subfinder, amass, assetfinder, crt.sh    |on"
    "02_dns       |DNS Resolution       |dnsx, record types, permutations          |on"
    "03_ports     |Port Scanning        |naabu, nmap service detection             |on"
    "04_http      |HTTP Probing         |httpx, screenshots, WAF detection         |on"
    "05_crawl     |Crawling             |katana, gau, URL merge                    |on"
    "06_js        |JS Analysis          |download, secrets, endpoints, trufflehog  |on"
    "07_params    |Parameter Discovery  |arjun, paramspider, x8                    |on"
    "08_content   |Content Discovery    |ffuf, kiterunner, API endpoints           |on"
    "09_vuln      |Vulnerability Scan   |nuclei, gf patterns, dalfox, sqlmap       |on"
    "10_cloud     |Cloud Assets         |S3, Azure blob, GCP bucket enum           |off"
    "11_osint     |OSINT                |theHarvester, emails, employee enum       |off"
    "12_takeover  |Subdomain Takeover   |subzy, nuclei takeover templates          |on"
)

# Apply config.conf toggles to defaults
_apply_config_defaults() {
    local -A TOGGLES=(
        [01_subdomain]="${ENABLE_SUBDOMAIN:-true}"
        [02_dns]="${ENABLE_DNS:-true}"
        [03_ports]="${ENABLE_PORTS:-true}"
        [04_http]="${ENABLE_HTTP:-true}"
        [05_crawl]="${ENABLE_CRAWL:-true}"
        [06_js]="${ENABLE_JS:-true}"
        [07_params]="${ENABLE_PARAMS:-true}"
        [08_content]="${ENABLE_CONTENT:-true}"
        [09_vuln]="${ENABLE_VULN:-true}"
        [10_cloud]="${ENABLE_CLOUD:-false}"
        [11_osint]="${ENABLE_OSINT:-false}"
        [12_takeover]="${ENABLE_TAKEOVER:-true}"
    )

    for i in "${!_MODULE_DEFS[@]}"; do
        local ID
        ID=$(echo "${_MODULE_DEFS[$i]}" | cut -d'|' -f1 | tr -d ' ')
        local TOGGLE="${TOGGLES[$ID]}"
        if [[ "$TOGGLE" == "false" ]]; then
            _MODULE_DEFS[$i]=$(echo "${_MODULE_DEFS[$i]}" | sed 's/|on$/|off/')
        elif [[ "$TOGGLE" == "true" ]]; then
            _MODULE_DEFS[$i]=$(echo "${_MODULE_DEFS[$i]}" | sed 's/|off$/|on/')
        fi
    done
}

# dialog-based menu (preferred)
_menu_dialog() {
    local ITEMS=()
    for def in "${_MODULE_DEFS[@]}"; do
        local ID LABEL DESC STATE
        IFS='|' read -r ID LABEL DESC STATE <<< "$def"
        ID=$(echo "$ID" | tr -d ' ')
        ITEMS+=("$ID" "$LABEL — $DESC" "$STATE")
    done

    local CHOICES
    CHOICES=$(dialog \
        --title " RECON FRAMEWORK " \
        --backtitle "Target: $DOMAIN" \
        --checklist "\nSelect modules to run:\n\n  Presets: (p)assive  (f)ull  (v)uln  (q)uick\n" \
        22 72 14 \
        "${ITEMS[@]}" \
        2>&1 >/dev/tty)

    local EXIT=$?
    clear
    [[ $EXIT -ne 0 ]] && { error "Aborted."; exit 1; }

    # shellcheck disable=SC2206
    SELECTED_MODULES=($CHOICES)
}

# Fallback plain bash menu
_menu_plain() {
    echo ""
    echo -e "${BOLD}${CYAN}  Select modules to run (space-separated numbers, or preset):${NC}"
    echo -e "${DIM}  Presets: [p]assive  [f]ull  [v]uln  [q]uick  [a]ll${NC}"
    echo ""

    local i=1
    local IDS=()
    for def in "${_MODULE_DEFS[@]}"; do
        local ID LABEL DESC STATE
        IFS='|' read -r ID LABEL DESC STATE <<< "$def"
        ID=$(echo "$ID" | tr -d ' ')
        IDS+=("$ID")
        local MARKER="${DIM}[ ]${NC}"
        [[ "$STATE" == "on" ]] && MARKER="${GREEN}[x]${NC}"
        printf "  %s ${BOLD}%2d.${NC} %-26s %s\n" \
            "$(echo -e "$MARKER")" "$i" \
            "$(echo "$LABEL" | tr -d ' ')" \
            "$(echo -e "${DIM}$DESC${NC}")"
        ((i++))
    done

    echo ""
    echo -ne "${BOLD}  Choice: ${NC}"
    read -r INPUT

    SELECTED_MODULES=()

    case "$INPUT" in
        p|passive)  _preset_passive;  return ;;
        f|full)     _preset_full;     return ;;
        v|vuln)     _preset_vuln;     return ;;
        q|quick)    _preset_quick;    return ;;
        a|all)      _preset_full;     return ;;
    esac

    for NUM in $INPUT; do
        local IDX=$(( NUM - 1 ))
        [[ $IDX -ge 0 && $IDX -lt ${#IDS[@]} ]] && SELECTED_MODULES+=("${IDS[$IDX]}")
    done

    if [[ ${#SELECTED_MODULES[@]} -eq 0 ]]; then
        warn "No modules selected — applying default configuration"
        for def in "${_MODULE_DEFS[@]}"; do
            local ID STATE
            IFS='|' read -r ID _ _ STATE <<< "$def"
            ID=$(echo "$ID" | tr -d ' ')
            [[ "$STATE" == "on" ]] && SELECTED_MODULES+=("$ID")
        done
    fi
}

# Public entry point — called from recon.sh
show_menu() {
    _apply_config_defaults

    if [[ "${NO_MENU:-false}" == "true" ]]; then
        # --no-menu flag: run whatever config.conf says
        SELECTED_MODULES=()
        for def in "${_MODULE_DEFS[@]}"; do
            local ID STATE
            IFS='|' read -r ID _ _ STATE <<< "$def"
            ID=$(echo "$ID" | tr -d ' ')
            [[ "$STATE" == "on" ]] && SELECTED_MODULES+=("$ID")
        done
        info "Skipping menu — running ${#SELECTED_MODULES[@]} enabled modules"
        return
    fi

    if tool_exists dialog; then
        _menu_dialog
    else
        _menu_plain
    fi

    echo ""
    info "Selected ${#SELECTED_MODULES[@]} module(s): ${SELECTED_MODULES[*]}"
}
