#!/usr/bin/env bash
# =============================================================================
#  12_takeover.sh — Subdomain Takeover Detection
# =============================================================================
MODULE_NAME="12_takeover"

run_module() {
    stage "SUBDOMAIN TAKEOVER"

    if ! safe_file_exists "$DNS_DIR/resolved.txt"; then
        warn "No resolved hosts — skipping takeover checks"
        return 1
    fi

    # Subzy
    safe_run subzy "Subzy Takeover Check" \
        subzy run --targets "$DNS_DIR/resolved.txt" \
        --output "$VULN_DIR/subzy.txt" 2>/dev/null

    # Nuclei takeover templates
    if tool_exists nuclei; then
        safe_run nuclei "Nuclei Takeover Templates" \
            nuclei -l "$DNS_DIR/resolved.txt" \
            -t "dns,http/takeovers" \
            -silent -json \
            -o "$VULN_DIR/nuclei_takeovers.json" 2>/dev/null
    fi

    success "Takeover checks completed"
    return 0
}
