# Changelog

All notable changes to Recon Framework are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [1.0.0] — Initial Release

### Added
- Modular architecture with 12 independent stages
- Interactive menu with preset modes (passive, full, vuln, quick)
- Resume/checkpointing via `.recon_state`
- Scope file support for multi-target runs
- `config.conf` with full API key, toggle, and performance settings
- HTML + Markdown report generation
- Discord and Slack webhook notifications
- Pre-flight tool validation with per-module status
- `install.sh` for automated dependency setup
- Subdomain enumeration: subfinder, amass, assetfinder, findomain, crt.sh
- DNS: dnsx full record types, zone transfer attempts
- Ports: naabu + nmap service detection
- HTTP: httpx, gowitness screenshots, wafw00f WAF detection
- Crawling: katana + gau with URL merge
- JS analysis: download, endpoint extraction, trufflehog, AWS key detection
- Parameter discovery: arjun, paramspider, grep-based extraction
- Content discovery: ffuf, kiterunner, robots.txt/sitemap collection
- Vuln scanning: nuclei, gf patterns (xss/sqli/ssrf/lfi/rce), dalfox
- Cloud assets: s3scanner, cloud_enum
- OSINT: theHarvester, h8mail breach check
- Subdomain takeover: subzy + nuclei takeover templates
