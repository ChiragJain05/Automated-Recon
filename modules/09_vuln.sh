#!/usr/bin/env bash
# =============================================================================
#  09_vuln.sh — Vulnerability Scanning
# =============================================================================
MODULE_NAME="09_vuln"

run_module() {
    stage "VULNERABILITY SCANNING"

    # Nuclei on hosts
    if safe_file_exists "$HTTP_DIR/alive.txt" && tool_exists nuclei; then
        safe_run nuclei "Nuclei Host Scan" \
            nuclei -l "$HTTP_DIR/alive.txt" \
            -severity "$NUCLEI_SEVERITY" \
            -rate-limit "$RATE" \
            -json -o "$VULN_DIR/nuclei_hosts.json"
    fi

    # Nuclei on URLs
    if safe_file_exists "$CRAWL_DIR/all_urls.txt" && tool_exists nuclei; then
        safe_run nuclei "Nuclei URL Scan" \
            nuclei -l "$CRAWL_DIR/all_urls.txt" \
            -severity "$NUCLEI_SEVERITY" \
            -rate-limit "$RATE" \
            -json -o "$VULN_DIR/nuclei_urls.json"
    fi

    # GF pattern analysis
    if tool_exists gf && safe_file_exists "$PARAMS_DIR/params.txt"; then
        info "Running GF patterns"
        for PATTERN in xss sqli ssrf lfi rce redirect; do
            gf "$PATTERN" "$PARAMS_DIR/params.txt" \
                > "$VULN_DIR/gf_${PATTERN}.txt" 2>/dev/null || true
        done
        success "GF patterns applied"
    fi

    # Dalfox XSS
    if tool_exists dalfox && safe_file_exists "$VULN_DIR/gf_xss.txt"; then
        safe_run dalfox "Dalfox XSS Scan" \
            dalfox file "$VULN_DIR/gf_xss.txt" \
            --skip-bav --silence \
            --output "$VULN_DIR/dalfox.txt"
    fi

    # Notify on critical findings
    if safe_file_exists "$VULN_DIR/nuclei_hosts.json"; then
        local CRITS
        CRITS=$(grep -c '"severity":"critical"' "$VULN_DIR/nuclei_hosts.json" 2>/dev/null || echo 0)
        if [[ "$CRITS" -gt 0 && "${NOTIFY_ON_CRITICAL:-false}" == "true" ]]; then
            notify_critical "$CRITS critical findings on $DOMAIN"
        fi
    fi

    success "Vulnerability scanning completed"
    return 0
}
