#!/usr/bin/env bash
# =============================================================================
#  validate.sh — Pre-flight checks
#  Sourced by recon.sh before any module runs.
# =============================================================================

# Tools grouped by module — warn but don't abort on optional tools
_CORE_TOOLS=(bash curl sort grep sed awk)

_MODULE_TOOLS=(
    "01_subdomain:subfinder amass assetfinder findomain"
    "02_dns:dnsx"
    "03_ports:naabu nmap"
    "04_http:httpx gowitness wafw00f"
    "05_crawl:katana gau"
    "06_js:trufflehog jq"
    "07_params:arjun"
    "08_content:ffuf kiterunner"
    "09_vuln:nuclei gf dalfox"
    "10_cloud:cloud_enum s3scanner"
    "11_osint:theHarvester"
    "12_takeover:subzy"
)

check_core_tools() {
    local MISSING=()
    for t in "${_CORE_TOOLS[@]}"; do
        tool_exists "$t" || MISSING+=("$t")
    done
    if [[ ${#MISSING[@]} -gt 0 ]]; then
        error "Missing core tools: ${MISSING[*]}"
        error "These are required for the framework to run at all."
        exit 1
    fi
    success "Core tools OK"
}

check_module_tools() {
    echo ""
    info "Tool availability check:"
    for entry in "${_MODULE_TOOLS[@]}"; do
        local MODULE="${entry%%:*}"
        local TOOLS="${entry##*:}"
        local PRESENT=() ABSENT=()
        for t in $TOOLS; do
            tool_exists "$t" && PRESENT+=("$t") || ABSENT+=("$t")
        done
        if [[ ${#ABSENT[@]} -eq 0 ]]; then
            echo -e "  ${GREEN}✔${NC} ${BOLD}$MODULE${NC}: all tools present"
        elif [[ ${#PRESENT[@]} -eq 0 ]]; then
            echo -e "  ${RED}✘${NC} ${BOLD}$MODULE${NC}: ${DIM}no tools found (${ABSENT[*]})${NC}"
        else
            echo -e "  ${YELLOW}~${NC} ${BOLD}$MODULE${NC}: ${DIM}missing: ${ABSENT[*]}${NC}"
        fi
    done
    echo ""
}

check_wordlists() {
    local MISSING_WL=()
    [[ -n "${WORDLIST_CONTENT:-}" && ! -f "$WORDLIST_CONTENT" ]] && MISSING_WL+=("WORDLIST_CONTENT: $WORDLIST_CONTENT")
    [[ -n "${WORDLIST_SUBS:-}"    && ! -f "$WORDLIST_SUBS"    ]] && MISSING_WL+=("WORDLIST_SUBS: $WORDLIST_SUBS")

    if [[ ${#MISSING_WL[@]} -gt 0 ]]; then
        warn "Missing wordlists (some modules will be limited):"
        for w in "${MISSING_WL[@]}"; do echo -e "  ${DIM}• $w${NC}"; done
    fi
}

preflight() {
    check_core_tools
    check_module_tools
    check_wordlists
}
