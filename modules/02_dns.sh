#!/usr/bin/env bash
# =============================================================================
#  02_dns.sh — DNS Resolution + Record Enumeration
# =============================================================================
MODULE_NAME="02_dns"

run_module() {
    stage "DNS RESOLUTION"

    if ! safe_file_exists "$ENUM_DIR/all_subdomains.txt"; then
        warn "No subdomains found — skipping DNS"
        return 1
    fi

    safe_run dnsx "DNS Resolution" \
        dnsx -l "$ENUM_DIR/all_subdomains.txt" \
        -silent -retry "$RETRIES" -threads "$THREADS" \
        -o "$DNS_DIR/resolved.txt"

    # Full record types
    if tool_exists dnsx; then
        info "Extracting DNS records"
        dnsx -l "$ENUM_DIR/all_subdomains.txt" \
            -a -aaaa -cname -mx -ns -txt -silent \
            -o "$DNS_DIR/all_records.txt" 2>/dev/null || true
    fi

    # Zone transfer attempts
    info "Attempting zone transfers"
    while IFS= read -r NS; do
        dig axfr "@$NS" "$DOMAIN" 2>/dev/null \
            | grep -v '^;' >> "$DNS_DIR/zone_transfer.txt" || true
    done < <(dig ns "$DOMAIN" +short 2>/dev/null)

    TOTAL_RESOLVED=$(count_lines "$DNS_DIR/resolved.txt")
    success "Resolved: $TOTAL_RESOLVED hosts"
    return 0
}
