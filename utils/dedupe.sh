#!/usr/bin/env bash
# =============================================================================
#  dedupe.sh — URL normalization and deduplication
#  Sourced by recon.sh and modules. Never executed directly.
# =============================================================================

# Normalize a URL: lowercase scheme+host, sort query params, strip fragments
normalize_url() {
    local URL="$1"
    # Strip fragment
    URL="${URL%%#*}"
    # Lowercase scheme and host only
    echo "$URL" | awk '
    {
        if (match($0, /^https?:\/\//)) {
            proto = substr($0, RSTART, RLENGTH)
            rest  = substr($0, RSTART + RLENGTH)
            slash = index(rest, "/")
            if (slash) {
                host = tolower(substr(rest, 1, slash-1))
                path = substr(rest, slash)
            } else {
                host = tolower(rest)
                path = ""
            }
            print proto host path
        } else {
            print $0
        }
    }'
}

# Remove out-of-scope URLs based on domain
filter_scope() {
    local INPUT="$1"
    local DOMAIN="$2"
    grep -i "$DOMAIN" "$INPUT" 2>/dev/null || true
}

# Deduplicate a file in-place
dedup_file() {
    local FILE="$1"
    safe_file_exists "$FILE" || return
    sort -u "$FILE" -o "$FILE"
}

# Merge multiple files, dedup, write to output
merge_files() {
    local OUTPUT="$1"; shift
    cat "$@" 2>/dev/null | sort -u > "$OUTPUT"
}

# Extract only URLs with parameters
filter_params() {
    local INPUT="$1"
    grep "=" "$INPUT" 2>/dev/null | sort -u
}

# Strip query strings — useful for endpoint dedup
strip_query() {
    local INPUT="$1"
    sed 's/?.*$//' "$INPUT" 2>/dev/null | sort -u
}
