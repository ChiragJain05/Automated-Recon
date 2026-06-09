#!/usr/bin/env bash

# =========================================================
# Fault-Tolerant Recon Automation Framework
# =========================================================
# Author: Chirag Jain
# Purpose:
#   Full recon + crawling + vuln scanning automation
#
# Usage:
#   chmod +x recon.sh
#   ./recon.sh example.com
#
# =========================================================

set -uo pipefail

# =========================
# CONFIGURATION
# =========================

DOMAIN="${1:-}"

if [[ -z "$DOMAIN" ]]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

DOMAIN="${DOMAIN#http://}"
DOMAIN="${DOMAIN#https://}"
DOMAIN="${DOMAIN%%/*}"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

BASE_DIR="recon/$DOMAIN"

ENUM_DIR="$BASE_DIR/enum"
DNS_DIR="$BASE_DIR/dns"
HTTP_DIR="$BASE_DIR/http"
PORTS_DIR="$BASE_DIR/ports"
CRAWL_DIR="$BASE_DIR/crawl"
PARAMS_DIR="$BASE_DIR/params"
JS_DIR="$BASE_DIR/js"
CONTENT_DIR="$BASE_DIR/content"
VULN_DIR="$BASE_DIR/vuln"
SCREENSHOT_DIR="$BASE_DIR/screenshots"
LOG_DIR="$BASE_DIR/logs"

THREADS=25
RATE=50

WORDLIST="/usr/share/seclists/Discovery/Web-Content/common.txt"

# =========================
# CREATE STRUCTURE
# =========================

mkdir -p \
"$ENUM_DIR" \
"$DNS_DIR" \
"$HTTP_DIR" \
"$PORTS_DIR" \
"$CRAWL_DIR" \
"$PARAMS_DIR" \
"$JS_DIR" \
"$CONTENT_DIR" \
"$VULN_DIR" \
"$SCREENSHOT_DIR" \
"$LOG_DIR"

LOG_FILE="$LOG_DIR/recon_$TIMESTAMP.log"

exec > >(tee -a "$LOG_FILE") 2>&1

# =========================
# COLORS
# =========================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[1;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# =========================
# TRACKING
# =========================

declare -a MISSING_TOOLS
declare -a SKIPPED_STAGES
declare -a FAILED_STAGES

# =========================
# HELPERS
# =========================

tool_exists() {
    command -v "$1" &>/dev/null
}

mark_missing() {

    local TOOL="$1"
    local STAGE="$2"

    MISSING_TOOLS+=("$TOOL")
    SKIPPED_STAGES+=("$STAGE")

    warn "$TOOL missing — skipping $STAGE"
}

mark_failed() {

    local STAGE="$1"

    FAILED_STAGES+=("$STAGE")

    error "$STAGE failed"
}

safe_run() {

    local TOOL="$1"
    local STAGE="$2"

    shift 2

    if tool_exists "$TOOL"; then

        info "Starting $STAGE"

        if "$@"; then
            success "$STAGE completed"
        else
            mark_failed "$STAGE"
        fi

    else

        mark_missing "$TOOL" "$STAGE"

    fi
}

safe_file_exists() {

    local FILE="$1"

    [[ -f "$FILE" && -s "$FILE" ]]
}

count_lines() {

    local FILE="$1"

    if safe_file_exists "$FILE"; then
        wc -l < "$FILE"
    else
        echo 0
    fi
}

extract_httpx_urls() {

    local INPUT="$1"
    local OUTPUT="$2"

    if tool_exists jq; then
        jq -r 'select(.url != null) | .url' "$INPUT" 2>/dev/null \
        | sort -u \
        > "$OUTPUT"
    else
        warn "jq missing - using fallback parser for httpx JSON"

        sed -n 's/.*"url":"\([^"]*\)".*/\1/p' "$INPUT" 2>/dev/null \
        | sort -u \
        > "$OUTPUT"
    fi
}

# =========================
# SUBDOMAIN ENUMERATION
# =========================


safe_run subfinder \
"Subfinder Enumeration" \
subfinder -d "$DOMAIN" -silent \
> "$ENUM_DIR/subfinder.txt"

safe_run amass \
"Amass Enumeration" \
amass enum -passive -d "$DOMAIN" -silent \
> "$ENUM_DIR/amass.txt"

safe_run assetfinder \
"Assetfinder Enumeration" \
assetfinder --subs-only "$DOMAIN" \
> "$ENUM_DIR/assetfinder.txt"

safe_run findomain \
"Findomain Enumeration" \
findomain -t "$DOMAIN" -q \
> "$ENUM_DIR/findomain.txt"

{
    printf '%s\n' "$DOMAIN"
    find "$ENUM_DIR" -type f -name "*.txt" -exec cat {} + 2>/dev/null
} \
| sed '/^[[:space:]]*$/d' \
| sort -u \
> "$ENUM_DIR/all_subdomains.txt"

TOTAL_SUBS=0

if safe_file_exists "$ENUM_DIR/all_subdomains.txt"; then
    TOTAL_SUBS=$(wc -l < "$ENUM_DIR/all_subdomains.txt")
fi

success "Collected $TOTAL_SUBS subdomains"

# =========================
# DNS RESOLUTION
# =========================

if safe_file_exists "$ENUM_DIR/all_subdomains.txt"; then

    safe_run dnsx \
    "DNS Resolution" \
    dnsx \
    -l "$ENUM_DIR/all_subdomains.txt" \
    -silent \
    -retry 2 \
    -threads "$THREADS" \
    > "$DNS_DIR/resolved.txt"

else

    warn "No subdomains available — skipping DNS resolution"

fi

TOTAL_RESOLVED=0

if safe_file_exists "$DNS_DIR/resolved.txt"; then
    TOTAL_RESOLVED=$(wc -l < "$DNS_DIR/resolved.txt")
fi

success "Resolved $TOTAL_RESOLVED hosts"

# =========================
# PORT SCANNING
# =========================

if safe_file_exists "$DNS_DIR/resolved.txt"; then

    safe_run naabu \
    "Port Scanning" \
    naabu \
    -l "$DNS_DIR/resolved.txt" \
    -top-ports 100 \
    -scan-type c \
    -rate "$RATE" \
    -silent \
    -o "$PORTS_DIR/ports.txt"

    TOTAL_PORTS=$(count_lines "$PORTS_DIR/ports.txt")

    if [[ "$TOTAL_PORTS" -eq 0 ]]; then
        warn "Port scan produced no results. This can mean no ports were found in the top 100, naabu was rate-limited, or packets were blocked."
        warn "Input hosts: $(count_lines "$DNS_DIR/resolved.txt")"
    else
        success "Found $TOTAL_PORTS open ports"

        sed 's/:[0-9]\+$//' "$PORTS_DIR/ports.txt" \
        | sort -u \
        > "$PORTS_DIR/nmap_hosts.txt"

        awk -F: '{print $NF}' "$PORTS_DIR/ports.txt" \
        | sort -n -u \
        | paste -sd, - \
        > "$PORTS_DIR/nmap_ports.txt"

        NMAP_PORT_LIST=$(cat "$PORTS_DIR/nmap_ports.txt")

        if [[ -n "$NMAP_PORT_LIST" ]]; then

            safe_run nmap \
            "Nmap Service Detection" \
            nmap \
            -sV \
            -Pn \
            -iL "$PORTS_DIR/nmap_hosts.txt" \
            -p "$NMAP_PORT_LIST" \
            -oN "$PORTS_DIR/nmap_services.txt" \
            -oX "$PORTS_DIR/nmap_services.xml"

        else

            warn "Could not build an nmap port list from naabu output"

        fi
    fi

else

    warn "No resolved hosts — skipping port scan"

fi

# =========================
# HTTP PROBING
# =========================

if safe_file_exists "$DNS_DIR/resolved.txt"; then

    safe_run httpx \
    "HTTP Probing" \
    httpx \
    -l "$DNS_DIR/resolved.txt" \
    -title \
    -tech-detect \
    -status-code \
    -follow-redirects \
    -random-agent \
    -json \
    -silent \
    -threads "$THREADS" \
    -o "$HTTP_DIR/httpx.json"

    if safe_file_exists "$HTTP_DIR/httpx.json"; then

        extract_httpx_urls "$HTTP_DIR/httpx.json" "$HTTP_DIR/alive.txt"

        if ! safe_file_exists "$HTTP_DIR/alive.txt"; then
            warn "HTTP probing produced JSON, but no URLs were extracted into alive.txt"
            warn "First httpx output line:"
            head -n 1 "$HTTP_DIR/httpx.json" || true
        fi

    else

        warn "HTTP probing produced no httpx.json output"

    fi

else

    warn "No resolved hosts — skipping HTTP probing"

fi

TOTAL_ALIVE=0

if safe_file_exists "$HTTP_DIR/alive.txt"; then
    TOTAL_ALIVE=$(wc -l < "$HTTP_DIR/alive.txt")
fi

success "Found $TOTAL_ALIVE alive hosts"

# =========================
# SCREENSHOTS
# =========================

if safe_file_exists "$HTTP_DIR/alive.txt"; then

    safe_run gowitness \
    "Screenshots" \
    gowitness scan file \
    -f "$HTTP_DIR/alive.txt" \
    --write-db \
    --screenshot-path "$SCREENSHOT_DIR" \
    >/dev/null 2>&1

fi

# =========================
# CRAWLING
# =========================

if safe_file_exists "$HTTP_DIR/alive.txt"; then

    safe_run katana \
    "Katana Crawling" \
    katana \
    -list "$HTTP_DIR/alive.txt" \
    -silent \
    -js-crawl \
    -known-files all \
    -depth 3 \
    -rate-limit "$RATE" \
    -o "$CRAWL_DIR/katana.txt"

else

    warn "No alive hosts — skipping crawling"

fi

# =========================
# GAU URL COLLECTION
# =========================

safe_run gau \
"Historical URL Collection" \
gau "$DOMAIN" \
> "$CRAWL_DIR/gau.txt"

find "$CRAWL_DIR" -type f -name "*.txt" \
-exec cat {} + 2>/dev/null \
| sort -u \
> "$CRAWL_DIR/all_urls.txt"

TOTAL_URLS=0

if safe_file_exists "$CRAWL_DIR/all_urls.txt"; then
    TOTAL_URLS=$(wc -l < "$CRAWL_DIR/all_urls.txt")
fi

success "Collected $TOTAL_URLS URLs"
# =========================
# JS EXTRACTION + ANALYSIS
# =========================

if safe_file_exists "$CRAWL_DIR/all_urls.txt"; then

    info "Extracting JavaScript files"

    grep -Ei '\.js(\?|$)' "$CRAWL_DIR/all_urls.txt" \
    | sort -u \
    > "$JS_DIR/js_files.txt" || true

    if safe_file_exists "$JS_DIR/js_files.txt"; then

        success "JS extraction completed"

        JS_COUNT=$(wc -l < "$JS_DIR/js_files.txt")

        info "Found $JS_COUNT JavaScript files"

    else

        warn "No JavaScript files extracted"

    fi

fi

# =========================
# DOWNLOAD JS FILES
# =========================

if safe_file_exists "$JS_DIR/js_files.txt"; then

    info "Downloading JavaScript files"

    COUNTER=0

    while read -r JS_URL; do

        [[ -z "$JS_URL" ]] && continue

        FILENAME=$(printf "%05d.js" "$COUNTER")

        curl -Lsk \
        --max-time 20 \
        "$JS_URL" \
        -o "$JS_DOWNLOAD_DIR/$FILENAME" \
        2>/dev/null || true

        ((COUNTER++))

    done < "$JS_DIR/js_files.txt"

    success "JavaScript download completed"

fi

# =========================
# ENDPOINT EXTRACTION
# =========================

if [[ -d "$JS_DOWNLOAD_DIR" ]]; then

    info "Extracting endpoints from JS"

    grep -RhoE \
    '(https?:\/\/[^"'"'"' ]+|\/[A-Za-z0-9_\/\-\?\=\&\.]+)' \
    "$JS_DOWNLOAD_DIR" \
    2>/dev/null \
    | sort -u \
    > "$JS_DIR/endpoints.txt" || true

    success "Endpoint extraction completed"

fi

# =========================
# GRAPHQL DETECTION
# =========================

if [[ -d "$JS_DOWNLOAD_DIR" ]]; then

    grep -RHiE \
    'graphql|apollo|gql' \
    "$JS_DOWNLOAD_DIR" \
    > "$JS_DIR/graphql.txt" \
    2>/dev/null || true

fi

# =========================
# FIREBASE DETECTION
# =========================

if [[ -d "$JS_DOWNLOAD_DIR" ]]; then

    grep -RHoE \
    '[A-Za-z0-9_-]+\.firebaseio\.com' \
    "$JS_DOWNLOAD_DIR" \
    | sort -u \
    > "$JS_DIR/firebase.txt" || true

fi

# =========================
# AWS KEY DETECTION
# =========================

if [[ -d "$JS_DOWNLOAD_DIR" ]]; then

    grep -RHoE \
    'AKIA[0-9A-Z]{16}' \
    "$JS_DOWNLOAD_DIR" \
    | sort -u \
    > "$JS_DIR/aws_keys.txt" || true

fi

# =========================
# TRUFFLEHOG
# =========================

if tool_exists trufflehog && [[ -d "$JS_DOWNLOAD_DIR" ]]; then

    info "Running TruffleHog"

    trufflehog filesystem \
    "$JS_DOWNLOAD_DIR" \
    --no-update \
    > "$JS_SECRET_DIR/trufflehog.txt" \
    2>/dev/null || true

    success "TruffleHog completed"

else

    mark_missing "trufflehog" "JS Secret Scanning"

fi

# =========================
# SECRETFINDER
# =========================

if tool_exists python3 && tool_exists SecretFinder; then

    info "Running SecretFinder"

    while read -r JS_URL; do

        SecretFinder \
        -i "$JS_URL" \
        -o cli

    done < "$JS_DIR/js_files.txt" \
    > "$JS_SECRET_DIR/secretfinder.txt" \
    2>/dev/null || true

    success "SecretFinder completed"

fi

# =========================
# MERGE SECRETS
# =========================

cat \
"$JS_SECRET_DIR"/*.txt \
2>/dev/null \
| sort -u \
> "$JS_SECRET_DIR/merged_secrets.txt" || true


# =========================
# PARAM EXTRACTION
# =========================

if safe_file_exists "$CRAWL_DIR/all_urls.txt"; then

    info "Extracting parameterized URLs"

    grep "=" "$CRAWL_DIR/all_urls.txt" \
    | sort -u \
    > "$PARAMS_DIR/params.txt" || true

    if safe_file_exists "$PARAMS_DIR/params.txt"; then
        success "Parameter extraction completed"
    else
        warn "No parameterized URLs found"
    fi

fi

# =========================
# CONTENT DISCOVERY
# =========================

if safe_file_exists "$HTTP_DIR/alive.txt"; then

    if tool_exists ffuf; then

        info "Running content discovery"

        while read -r host; do

            [[ -z "$host" ]] && continue

            CLEAN_HOST=$(echo "$host" \
            | sed 's#https\?://##g' \
            | tr '/' '_')

            ffuf \
            -u "$host/FUZZ" \
            -w "$WORDLIST" \
            -mc 200,204,301,302,307,401,403 \
            -t 20 \
            -s \
            > "$CONTENT_DIR/$CLEAN_HOST.txt" \
            2>/dev/null || true

        done < "$HTTP_DIR/alive.txt"

        success "Content discovery completed"

    else

        mark_missing "ffuf" "Content Discovery"

    fi

fi

# =========================
# NUCLEI SCAN
# =========================

if tool_exists nuclei; then

    if safe_file_exists "$HTTP_DIR/alive.txt"; then

        safe_run nuclei \
        "Nuclei Host Scan" \
        nuclei \
        -l "$HTTP_DIR/alive.txt" \
        -severity critical,high,medium \
        -rate-limit "$RATE" \
        -json \
        -o "$VULN_DIR/nuclei_hosts.json"

    fi

    if safe_file_exists "$CRAWL_DIR/all_urls.txt"; then

        safe_run nuclei \
        "Nuclei URL Scan" \
        nuclei \
        -l "$CRAWL_DIR/all_urls.txt" \
        -severity critical,high,medium \
        -rate-limit "$RATE" \
        -json \
        -o "$VULN_DIR/nuclei_urls.json"

    fi

else

    mark_missing "nuclei" "Vulnerability Scanning"

fi

# =========================
# GF ANALYSIS
# =========================

if tool_exists gf && safe_file_exists "$PARAMS_DIR/params.txt"; then

    info "Running GF pattern analysis"

    gf xss "$PARAMS_DIR/params.txt" \
    > "$VULN_DIR/potential_xss.txt" \
    2>/dev/null || true

    gf sqli "$PARAMS_DIR/params.txt" \
    > "$VULN_DIR/potential_sqli.txt" \
    2>/dev/null || true

    gf ssrf "$PARAMS_DIR/params.txt" \
    > "$VULN_DIR/potential_ssrf.txt" \
    2>/dev/null || true

    success "GF pattern analysis completed"

else

    mark_missing "gf" "GF Pattern Analysis"

fi

# =========================
# DALFOX
# =========================

if tool_exists dalfox && safe_file_exists "$PARAMS_DIR/params.txt"; then

    info "Running Dalfox"

    dalfox file \
    "$PARAMS_DIR/params.txt" \
    --skip-bav \
    --silence \
    > "$VULN_DIR/dalfox.txt" \
    2>/dev/null || true

    success "Dalfox completed"

else

    mark_missing "dalfox" "Dalfox XSS Scan"

fi

# =========================
# SUBDOMAIN TAKEOVER
# =========================

if tool_exists subzy && safe_file_exists "$DNS_DIR/resolved.txt"; then

    info "Running subdomain takeover checks"

    subzy run \
    --targets "$DNS_DIR/resolved.txt" \
    > "$VULN_DIR/subzy.txt" \
    2>/dev/null || true

    success "Subdomain takeover scan completed"

else

    mark_missing "subzy" "Subdomain Takeover Scan"

fi

# =========================
# FINAL SUMMARY
# =========================

echo ""
echo "======================================="
echo "              SUMMARY"
echo "======================================="

echo "Domain: $DOMAIN"
echo "Subdomains: $TOTAL_SUBS"
echo "Resolved Hosts: $TOTAL_RESOLVED"
echo "Alive Hosts: $TOTAL_ALIVE"
echo "URLs Collected: $TOTAL_URLS"

echo ""
echo "Results Directory:"
echo "$BASE_DIR"

echo ""
echo "Log File:"
echo "$LOG_FILE"

echo ""
echo "======================================="
echo "          MISSING TOOLS"
echo "======================================="

if [[ ${#MISSING_TOOLS[@]} -eq 0 ]]; then

    echo "No missing tools"

else

    for i in "${!MISSING_TOOLS[@]}"; do

        echo "- ${MISSING_TOOLS[$i]}"
        echo "  Skipped: ${SKIPPED_STAGES[$i]}"
        echo ""

    done

fi

echo ""
echo "======================================="
echo "           FAILED STAGES"
echo "======================================="

if [[ -z "${FAILED_STAGES+x}" || ${#FAILED_STAGES[@]} -eq 0 ]]; then

    echo "No failed stages"

else

    for stage in "${FAILED_STAGES[@]}"; do
        echo "- $stage"
    done

fi

echo ""
echo "======================================="

success "Recon pipeline completed"
