#!/usr/bin/env bash
# =============================================================================
#  07_params.sh — Parameter Discovery
# =============================================================================
MODULE_NAME="07_params"

run_module() {
    stage "PARAMETER DISCOVERY"

    # Grep-based extraction from crawled URLs
    if safe_file_exists "$CRAWL_DIR/all_urls.txt"; then
        filter_params "$CRAWL_DIR/all_urls.txt" > "$PARAMS_DIR/params_crawl.txt" || true
    fi

    # Arjun — active param discovery
    if safe_file_exists "$HTTP_DIR/alive.txt" && tool_exists arjun; then
        info "Running Arjun on alive hosts"
        while IFS= read -r HOST; do
            [[ -z "$HOST" ]] && continue
            local CLEAN
            CLEAN=$(echo "$HOST" | sed 's#https\?://##g' | tr '/' '_')
            arjun -u "$HOST" -oT "$PARAMS_DIR/arjun_${CLEAN}.txt" \
                --silent 2>/dev/null || true
        done < "$HTTP_DIR/alive.txt"
        # Merge arjun output
        cat "$PARAMS_DIR"/arjun_*.txt 2>/dev/null | sort -u >> "$PARAMS_DIR/params_crawl.txt" || true
    fi

    # ParamSpider
    safe_run paramspider "ParamSpider" \
        bash -c "paramspider -d $DOMAIN --quiet 2>/dev/null \
        | sort -u > $PARAMS_DIR/paramspider.txt"

    # Merge all params
    merge_files "$PARAMS_DIR/params.txt" \
        "$PARAMS_DIR/params_crawl.txt" \
        "$PARAMS_DIR/paramspider.txt" 2>/dev/null || true

    success "Parameters found: $(count_lines "$PARAMS_DIR/params.txt")"
    return 0
}
