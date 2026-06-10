#!/usr/bin/env bash
# =============================================================================
#  report.sh — HTML + Markdown report generator
#  Sourced by recon.sh after all modules complete.
# =============================================================================

_count()  { count_lines "${1:-/dev/null}"; }
_exists() { safe_file_exists "$1" && echo "✔" || echo "—"; }

generate_html_report() {
    local OUT="$BASE_DIR/report.html"
    local TS
    TS="$(date '+%Y-%m-%d %H:%M:%S')"

    local SUBS_COUNT;    SUBS_COUNT=$(_count    "$ENUM_DIR/all_subdomains.txt")
    local RESOLVED;      RESOLVED=$(_count      "$DNS_DIR/resolved.txt")
    local ALIVE;         ALIVE=$(_count         "$HTTP_DIR/alive.txt")
    local URLS;          URLS=$(_count          "$CRAWL_DIR/all_urls.txt")
    local JS_FILES;      JS_FILES=$(_count      "$JS_DIR/js_files.txt")
    local PARAMS;        PARAMS=$(_count        "$PARAMS_DIR/params.txt")
    local NUCLEI_HITS;   NUCLEI_HITS=$(_count   "$VULN_DIR/nuclei_hosts.json")
    local PORTS_OPEN;    PORTS_OPEN=$(_count    "$PORTS_DIR/ports.txt")

    cat > "$OUT" << HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Recon Report — $DOMAIN</title>
<style>
  :root {
    --bg: #0d1117; --surface: #161b22; --border: #30363d;
    --text: #c9d1d9; --muted: #8b949e; --accent: #58a6ff;
    --green: #3fb950; --yellow: #d29922; --red: #f85149;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: var(--bg); color: var(--text); font-family: 'Segoe UI', system-ui, sans-serif; padding: 2rem; }
  h1 { font-size: 1.6rem; color: var(--accent); margin-bottom: .25rem; }
  h2 { font-size: 1.1rem; color: var(--accent); margin: 1.5rem 0 .75rem; border-bottom: 1px solid var(--border); padding-bottom: .4rem; }
  .meta { color: var(--muted); font-size: .85rem; margin-bottom: 2rem; }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: 1rem; margin-bottom: 2rem; }
  .card { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; padding: 1rem; text-align: center; }
  .card .num { font-size: 2rem; font-weight: 700; color: var(--accent); }
  .card .lbl { font-size: .75rem; color: var(--muted); margin-top: .25rem; text-transform: uppercase; letter-spacing: .05em; }
  table { width: 100%; border-collapse: collapse; font-size: .85rem; }
  th { background: var(--surface); color: var(--muted); font-weight: 600; text-align: left; padding: .5rem .75rem; border: 1px solid var(--border); }
  td { padding: .5rem .75rem; border: 1px solid var(--border); vertical-align: top; word-break: break-all; }
  tr:nth-child(even) td { background: #0d111799; }
  .tag { display: inline-block; padding: .15rem .5rem; border-radius: 4px; font-size: .75rem; font-weight: 600; }
  .tag-ok  { background: #1a3a2a; color: var(--green); }
  .tag-warn{ background: #332900; color: var(--yellow); }
  .tag-err { background: #3a1a1a; color: var(--red); }
  pre { background: var(--surface); border: 1px solid var(--border); border-radius: 6px; padding: 1rem; overflow-x: auto; font-size: .8rem; color: var(--muted); max-height: 300px; }
  .section { margin-bottom: 2rem; }
</style>
</head>
<body>

<h1>🔍 Recon Report — $DOMAIN</h1>
<p class="meta">Generated: $TS &nbsp;|&nbsp; Run ID: $RUN_ID &nbsp;|&nbsp; Framework v$(cat "$(dirname "${BASH_SOURCE[0]}")/../.version" 2>/dev/null)</p>

<div class="grid">
  <div class="card"><div class="num">$SUBS_COUNT</div><div class="lbl">Subdomains</div></div>
  <div class="card"><div class="num">$RESOLVED</div><div class="lbl">Resolved</div></div>
  <div class="card"><div class="num">$ALIVE</div><div class="lbl">Alive Hosts</div></div>
  <div class="card"><div class="num">$URLS</div><div class="lbl">URLs</div></div>
  <div class="card"><div class="num">$JS_FILES</div><div class="lbl">JS Files</div></div>
  <div class="card"><div class="num">$PARAMS</div><div class="lbl">Parameters</div></div>
  <div class="card"><div class="num">$PORTS_OPEN</div><div class="lbl">Open Ports</div></div>
  <div class="card"><div class="num">$NUCLEI_HITS</div><div class="lbl">Nuclei Hits</div></div>
</div>

<div class="section">
<h2>Subdomains</h2>
<pre>$(head -50 "$ENUM_DIR/all_subdomains.txt" 2>/dev/null || echo "No data")</pre>
</div>

<div class="section">
<h2>Alive Hosts</h2>
<pre>$(cat "$HTTP_DIR/alive.txt" 2>/dev/null || echo "No data")</pre>
</div>

<div class="section">
<h2>Open Ports</h2>
<pre>$(cat "$PORTS_DIR/ports.txt" 2>/dev/null || echo "No data")</pre>
</div>

<div class="section">
<h2>Nuclei Findings</h2>
<pre>$(cat "$VULN_DIR/nuclei_hosts.json" 2>/dev/null | head -100 || echo "No findings")</pre>
</div>

<div class="section">
<h2>Stage Status</h2>
<table>
<tr><th>Stage</th><th>Status</th><th>Output</th></tr>
$(for stage in "${SELECTED_MODULES[@]:-}"; do
    if stage_done "$stage"; then
        echo "<tr><td>$stage</td><td><span class='tag tag-ok'>DONE</span></td><td>$(ls "$BASE_DIR" 2>/dev/null | head -3 | tr '\n' ' ')</td></tr>"
    else
        echo "<tr><td>$stage</td><td><span class='tag tag-warn'>SKIPPED</span></td><td>—</td></tr>"
    fi
done)
</table>
</div>

</body>
</html>
HTML

    success "HTML report written → $OUT"
}

generate_markdown_report() {
    local OUT="$BASE_DIR/report.md"
    local TS
    TS="$(date '+%Y-%m-%d %H:%M:%S')"

    cat > "$OUT" << MD
# Recon Report — $DOMAIN

**Generated:** $TS
**Run ID:** $RUN_ID

## Summary

| Metric | Count |
|--------|-------|
| Subdomains | $(_count "$ENUM_DIR/all_subdomains.txt") |
| Resolved Hosts | $(_count "$DNS_DIR/resolved.txt") |
| Alive Hosts | $(_count "$HTTP_DIR/alive.txt") |
| URLs Collected | $(_count "$CRAWL_DIR/all_urls.txt") |
| JS Files | $(_count "$JS_DIR/js_files.txt") |
| Parameters | $(_count "$PARAMS_DIR/params.txt") |
| Open Ports | $(_count "$PORTS_DIR/ports.txt") |
| Nuclei Findings | $(_count "$VULN_DIR/nuclei_hosts.json") |

## Alive Hosts

\`\`\`
$(cat "$HTTP_DIR/alive.txt" 2>/dev/null || echo "No data")
\`\`\`

## Nuclei Findings

\`\`\`
$(cat "$VULN_DIR/nuclei_hosts.json" 2>/dev/null | head -50 || echo "No findings")
\`\`\`
MD

    success "Markdown report written → $OUT"
}

generate_report() {
    stage "Generating Report"
    case "${REPORT_FORMAT:-html}" in
        html)     generate_html_report ;;
        markdown) generate_markdown_report ;;
        both)     generate_html_report; generate_markdown_report ;;
    esac
}
