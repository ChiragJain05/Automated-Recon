#!/usr/bin/env bash
# =============================================================================
#  05_crawl.sh — Web Crawling + Historical URL Collection
# =============================================================================
MODULE_NAME="05_crawl"

run_module() {
    stage "CRAWLING"

    if safe_file_exists "$HTTP_DIR/alive.txt"; then
        safe_run katana "Katana Crawling" \
            katana -list "$HTTP_DIR/alive.txt" \
            -silent -js-crawl -known-files all \
            -depth 3 -rate-limit "$RATE" \
            -o "$CRAWL_DIR/katana.txt"
    fi

    safe_run gau "Historical URLs (gau)" \
        bash -c "gau $DOMAIN > $CRAWL_DIR/gau.txt 2>/dev/null"

    merge_files "$CRAWL_DIR/all_urls.txt" \
        "$CRAWL_DIR/katana.txt" \
        "$CRAWL_DIR/gau.txt" 2>/dev/null || true

    TOTAL_URLS=$(count_lines "$CRAWL_DIR/all_urls.txt")
    success "Total URLs: $TOTAL_URLS"
    return 0
}
