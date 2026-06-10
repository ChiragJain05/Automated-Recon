#!/usr/bin/env bash
# =============================================================================
#  03_ports.sh — Port Scanning
# =============================================================================
MODULE_NAME="03_ports"

run_module() {
    stage "PORT SCANNING"

    if ! safe_file_exists "$DNS_DIR/resolved.txt"; then
        warn "No resolved hosts — skipping port scan"
        return 1
    fi

    safe_run naabu "Naabu Port Scan" \
        naabu -l "$DNS_DIR/resolved.txt" \
        -top-ports "$NMAP_TOP_PORTS" \
        -scan-type "$PORT_SCAN_TYPE" \
        -rate "$RATE" -silent \
        -o "$PORTS_DIR/ports.txt"

    if safe_file_exists "$PORTS_DIR/ports.txt"; then
        sed 's/:[0-9]\+$//' "$PORTS_DIR/ports.txt" | sort -u > "$PORTS_DIR/nmap_hosts.txt"
        awk -F: '{print $NF}' "$PORTS_DIR/ports.txt" | sort -n -u | paste -sd, - > "$PORTS_DIR/nmap_ports.txt"
        local PORT_LIST
        PORT_LIST=$(cat "$PORTS_DIR/nmap_ports.txt")

        if [[ -n "$PORT_LIST" ]]; then
            safe_run nmap "Nmap Service Detection" \
                nmap -sV -Pn \
                -iL "$PORTS_DIR/nmap_hosts.txt" \
                -p "$PORT_LIST" \
                -oN "$PORTS_DIR/nmap_services.txt" \
                -oX "$PORTS_DIR/nmap_services.xml"
        fi
    fi

    success "Open ports: $(count_lines "$PORTS_DIR/ports.txt")"
    return 0
}
