# Recon Framework

A modular, professional-grade reconnaissance pipeline for bug bounty and penetration testing.

## Quick Start

```bash
# Install dependencies
./install.sh

# Run against a single domain (interactive menu)
./recon.sh -d example.com

# Run from a scope file
./recon.sh -s scope.txt

# Resume an interrupted run
./recon.sh -d example.com -r

# Skip menu, run defaults from config.conf
./recon.sh -d example.com --no-menu

# Passive only (no active scanning)
./recon.sh -d example.com -p
```

## Architecture

```
recon-framework/
├── recon.sh          # Main orchestrator
├── config.conf       # All settings + API keys
├── scope.txt         # Multi-target input
├── install.sh        # Dependency installer
├── modules/          # 12 independent recon stages
├── utils/            # helpers, menu, notify, dedupe, report
├── wordlists/        # Custom wordlist storage
└── recon/            # Output per target (gitignored)
```

## Modules

| # | Module | Tools |
|---|--------|-------|
| 01 | Subdomain Enumeration | subfinder, amass, assetfinder, crt.sh |
| 02 | DNS Resolution | dnsx, zone transfers |
| 03 | Port Scanning | naabu, nmap |
| 04 | HTTP Probing | httpx, gowitness, wafw00f |
| 05 | Crawling | katana, gau |
| 06 | JS Analysis | trufflehog, custom extraction |
| 07 | Parameter Discovery | arjun, paramspider |
| 08 | Content Discovery | ffuf, kiterunner |
| 09 | Vulnerability Scan | nuclei, gf, dalfox |
| 10 | Cloud Assets | s3scanner, cloud_enum |
| 11 | OSINT | theHarvester, h8mail |
| 12 | Subdomain Takeover | subzy, nuclei |

## Configuration

Edit `config.conf` to set:
- API keys (Shodan, SecurityTrails, Chaos, etc.)
- Wordlist paths
- Performance: threads, rate limits, timeouts
- Module toggles
- Notification webhooks (Slack/Discord)

## Output

All results are written to `recon/<domain>/`:

```
recon/example.com/
├── enum/         # Subdomain lists
├── dns/          # Resolved hosts, DNS records
├── ports/        # Naabu + nmap output
├── http/         # httpx JSON, alive hosts, tech stack
├── crawl/        # All URLs
├── js/           # JS files, endpoints, secrets
├── params/       # Parameterized URLs
├── content/      # ffuf, kiterunner results
├── vuln/         # Nuclei, gf, dalfox findings
├── cloud/        # Bucket findings
├── osint/        # Emails, breaches
├── screenshots/  # gowitness captures
├── logs/         # Run logs
└── report.html   # Auto-generated report
```

## Adding a Module

1. Create `modules/13_yourmodule.sh`
2. Implement `run_module()` — return 0=success, 1=skipped, 2=failed
3. Use `safe_run`, `stage`, `info`, `success`, `warn` from helpers
4. Add your module's tools to `utils/validate.sh`

## Legal

Use only against targets you have explicit permission to test.
