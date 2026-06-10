#!/usr/bin/env bash
# =============================================================================
#  08_content.sh — Content Discovery
# =============================================================================
MODULE_NAME="08_content"

run_module() {
    stage "CONTENT DISCOVERY"

    if ! safe_file_exists "$HTTP_DIR/alive.txt"; then
        warn "No alive hosts — skipping content discovery"
        return 1
    fi

    local WL="${WORDLIST_CONTENT:-/usr/share/seclists/Discovery/Web-Content/common.txt}"
    if [[ ! -f "$WL" ]]; then
        warn "Wordlist not found: $WL — skipping ffuf"
    else
        while IFS= read -r HOST; do
            [[ -z "$HOST" ]] && continue
            local CLEAN
            CLEAN=$(echo "$HOST" | sed 's#https\?://##g' | tr '/' '_')
            safe_run ffuf "ffuf: $HOST" \
                ffuf -u "$HOST/FUZZ" -w "$WL" \
                -mc 200,204,301,302,307,401,403 \
                -t 20 -s \
                -o "$CONTENT_DIR/${CLEAN}.json" -of json 2>/dev/null
        done < "$HTTP_DIR/alive.txt"
    fi

    # Kiterunner — API endpoint discovery
    if tool_exists kr && safe_file_exists "$HTTP_DIR/alive.txt"; then
        info "Running Kiterunner for API discovery"
        kr scan "$HTTP_DIR/alive.txt" \
            -w /usr/share/kiterunner/routes-large.kite \
            --output-file "$CONTENT_DIR/kiterunner.txt" \
            2>/dev/null || true
    fi

    # robots.txt + sitemap collection
    info "Collecting robots.txt and sitemaps"
    while IFS= read -r HOST; do
        curl -sk --max-time 10 "$HOST/robots.txt"  >> "$CONTENT_DIR/robots.txt"  2>/dev/null || true
        curl -sk --max-time 10 "$HOST/sitemap.xml" >> "$CONTENT_DIR/sitemaps.xml" 2>/dev/null || true
    done < "$HTTP_DIR/alive.txt"

    success "Content discovery completed"
    return 0
}
