#!/usr/bin/env bash
# =============================================================================
#  install.sh — Dependency installer
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'; BOLD='\033[1m'
ok()   { echo -e "${GREEN}✔${NC} $1"; }
warn() { echo -e "${YELLOW}~${NC} $1"; }
fail() { echo -e "${RED}✘${NC} $1"; }
sep()  { echo -e "${BOLD}── $1 ─────────────────────────────────${NC}"; }

GOBIN="${GOPATH:-$HOME/go}/bin"
export PATH="$PATH:$GOBIN"

install_go_tool() {
    local NAME="$1"; local PKG="$2"
    if command -v "$NAME" &>/dev/null; then
        ok "$NAME already installed"
    else
        echo -n "  Installing $NAME... "
        go install "$PKG" &>/dev/null && ok "done" || fail "failed"
    fi
}

sep "System packages"
if command -v apt-get &>/dev/null; then
    sudo apt-get install -y -q \
        curl wget git jq nmap dnsutils \
        python3 python3-pip dialog \
        2>/dev/null && ok "apt packages installed"
fi

sep "Go tools"
if ! command -v go &>/dev/null; then
    warn "Go not found — skipping Go tool installation"
    warn "Install Go from https://go.dev/dl/ then re-run this script"
else
    install_go_tool subfinder  "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    install_go_tool amass      "github.com/owasp-amass/amass/v4/...@master"
    install_go_tool assetfinder "github.com/tomnomnom/assetfinder@latest"
    install_go_tool dnsx       "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
    install_go_tool naabu      "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
    install_go_tool httpx      "github.com/projectdiscovery/httpx/cmd/httpx@latest"
    install_go_tool katana     "github.com/projectdiscovery/katana/cmd/katana@latest"
    install_go_tool nuclei     "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    install_go_tool gau        "github.com/lc/gau/v2/cmd/gau@latest"
    install_go_tool dalfox     "github.com/hahwul/dalfox/v2@latest"
    install_go_tool subzy      "github.com/LukaSikic/subzy@latest"
    install_go_tool wafw00f    "github.com/EnableSecurity/wafw00f@latest" 2>/dev/null || true
    install_go_tool gf         "github.com/tomnomnom/gf@latest"
    install_go_tool gowitness  "github.com/sensepost/gowitness@latest"
    install_go_tool findomain  "github.com/Findomain/Findomain@latest" 2>/dev/null || true
fi

sep "Python tools"
if command -v pip3 &>/dev/null; then
    pip3 install -q theHarvester paramspider arjun 2>/dev/null && ok "Python tools installed" || warn "Some Python tools failed"
fi

sep "Nuclei templates"
if command -v nuclei &>/dev/null; then
    nuclei -update-templates -silent 2>/dev/null && ok "Nuclei templates updated" || warn "Could not update nuclei templates"
fi

sep "Done"
echo ""
echo "Run ./recon.sh -h to get started."
