#!/usr/bin/env bash
# =============================================================================
#  04_http.sh — HTTP Probing, Screenshots, WAF Detection
# =============================================================================
MODULE_NAME="04_http"

run_module() {
    stage "HTTP PROBING"

    if ! safe_file_exists "$DNS_DIR/resolved.txt"; then
        warn "No resolved hosts — skipping HTTP probing"
        return 1
    fi

    safe_run httpx "HTTP Probing" \
        httpx -l "$DNS_DIR/resolved.txt" \
        -title -tech-detect -status-code \
        -follow-redirects -random-agent \
        -json -silent -threads "$THREADS" \
        -o "$HTTP_DIR/httpx.json"

    if safe_file_exists "$HTTP_DIR/httpx.json"; then
        extract_httpx_urls "$HTTP_DIR/httpx.json" "$HTTP_DIR/alive.txt"
        # Extract tech stack summary
        jq -r 'select(.technologies != null) | "\(.url) \(.technologies[])"' \
            "$HTTP_DIR/httpx.json" 2>/dev/null | sort -u > "$HTTP_DIR/tech_stack.txt" || true
    fi

    # WAF detection
    safe_run wafw00f "WAF Detection" \
        bash -c "cat $HTTP_DIR/alive.txt | xargs -I{} wafw00f {} 2>/dev/null >> $HTTP_DIR/waf.txt"

    # Screenshots
    if [[ "${SCREENSHOT:-true}" == "true" ]]; then
        safe_run gowitness "Screenshots" \
            gowitness scan file -f "$HTTP_DIR/alive.txt" \
            --write-db --screenshot-path "$SCREENSHOT_DIR"
    fi

    TOTAL_ALIVE=$(count_lines "$HTTP_DIR/alive.txt")
    success "Alive hosts: $TOTAL_ALIVE"
    return 0
}
