#!/usr/bin/env bash
# =============================================================================
#  06_js.sh — JavaScript Analysis, Secret Scanning
# =============================================================================
MODULE_NAME="06_js"

run_module() {
    stage "JS ANALYSIS"

    if ! safe_file_exists "$CRAWL_DIR/all_urls.txt"; then
        warn "No URLs collected — skipping JS analysis"
        return 1
    fi

    # Extract JS file URLs
    grep -Ei '\.js(\?|$)' "$CRAWL_DIR/all_urls.txt" | sort -u > "$JS_DIR/js_files.txt" || true
    info "JS files found: $(count_lines "$JS_DIR/js_files.txt")"

    # Download JS files
    local COUNTER=0
    while IFS= read -r URL; do
        [[ -z "$URL" ]] && continue
        local OUT
        OUT=$(printf "%s/%05d.js" "$JS_DOWNLOAD_DIR" "$COUNTER")
        curl -Lsk --max-time 20 "$URL" -o "$OUT" 2>/dev/null || true
        ((COUNTER++))
    done < "$JS_DIR/js_files.txt"

    # Endpoint extraction
    grep -RhoE '(https?:\/\/[^"'"'"' ]+|\/[A-Za-z0-9_\/\-\?\=\&\.]+)' \
        "$JS_DOWNLOAD_DIR" 2>/dev/null | sort -u > "$JS_DIR/endpoints.txt" || true

    # Pattern detection
    grep -RHiE 'graphql|apollo|gql'   "$JS_DOWNLOAD_DIR" > "$JS_DIR/graphql.txt"   2>/dev/null || true
    grep -RHoE '[A-Za-z0-9_-]+\.firebaseio\.com' "$JS_DOWNLOAD_DIR" | sort -u > "$JS_DIR/firebase.txt" 2>/dev/null || true
    grep -RHoE 'AKIA[0-9A-Z]{16}'    "$JS_DOWNLOAD_DIR" | sort -u > "$JS_DIR/aws_keys.txt"   2>/dev/null || true

    # TruffleHog
    if tool_exists trufflehog; then
        trufflehog filesystem "$JS_DOWNLOAD_DIR" --no-update \
            > "$JS_SECRET_DIR/trufflehog.txt" 2>/dev/null || true
    fi

    # Merge secrets
    cat "$JS_SECRET_DIR"/*.txt 2>/dev/null | sort -u > "$JS_SECRET_DIR/merged_secrets.txt" || true

    success "Endpoints extracted: $(count_lines "$JS_DIR/endpoints.txt")"
    return 0
}
