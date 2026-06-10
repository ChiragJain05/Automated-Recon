#!/usr/bin/env bash
# =============================================================================
#  01_subdomain.sh — Subdomain Enumeration
# =============================================================================
MODULE_NAME="01_subdomain"

run_module() {
    stage "SUBDOMAIN ENUMERATION"

    safe_run subfinder "Subfinder"  subfinder -d "$DOMAIN" -silent -o "$ENUM_DIR/subfinder.txt"
    safe_run amass     "Amass"      amass enum -passive -d "$DOMAIN" -silent -o "$ENUM_DIR/amass.txt"
    safe_run assetfinder "Assetfinder" bash -c "assetfinder --subs-only $DOMAIN > $ENUM_DIR/assetfinder.txt"
    safe_run findomain "Findomain"  bash -c "findomain -t $DOMAIN -q > $ENUM_DIR/findomain.txt"

    # crt.sh via curl — no tool needed
    info "Querying crt.sh"
    curl -s "https://crt.sh/?q=%25.$DOMAIN&output=json" \
        | grep -oP '"name_value":"\K[^"]+' \
        | sed 's/\*\.//g' \
        | sort -u > "$ENUM_DIR/crtsh.txt" 2>/dev/null || true

    # Merge everything
    {
        printf '%s\n' "$DOMAIN"
        find "$ENUM_DIR" -type f -name "*.txt" -exec cat {} + 2>/dev/null
    } | sed '/^[[:space:]]*$/d' | sort -u > "$ENUM_DIR/all_subdomains.txt"

    TOTAL_SUBS=$(count_lines "$ENUM_DIR/all_subdomains.txt")
    success "Total subdomains: $TOTAL_SUBS"
    return 0
}
