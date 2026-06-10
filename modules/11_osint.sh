#!/usr/bin/env bash
# =============================================================================
#  11_osint.sh — OSINT: Emails, Employees, Breach Data
# =============================================================================
MODULE_NAME="11_osint"

run_module() {
    stage "OSINT"

    # theHarvester
    safe_run theHarvester "theHarvester" \
        theHarvester -d "$DOMAIN" -b all \
        -f "$OSINT_DIR/harvester" 2>/dev/null

    # Extract emails from harvester output
    if safe_file_exists "$OSINT_DIR/harvester.json"; then
        jq -r '.emails[]? // empty' "$OSINT_DIR/harvester.json" 2>/dev/null \
            | sort -u > "$OSINT_DIR/emails.txt" || true
    fi

    # h8mail breach check (if configured)
    if tool_exists h8mail && safe_file_exists "$OSINT_DIR/emails.txt"; then
        safe_run h8mail "h8mail Breach Check" \
            h8mail -t "$OSINT_DIR/emails.txt" \
            -o "$OSINT_DIR/breaches.txt" 2>/dev/null
    fi

    success "OSINT completed — emails: $(count_lines "$OSINT_DIR/emails.txt")"
    return 0
}
