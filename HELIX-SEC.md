# HELIX-SEC — Autonomous Web Penetration Testing Engine

HELIX-SEC transforms the `claw` CLI into a multi-phase autonomous web vulnerability scanner. It combines a built-in Rust scanner (zero dependencies) with intelligent orchestration of industry-standard security tools when available.

## Architecture

```
Phase 1   Rust WebSecScan     Always runs. Crawls target, discovers forms/params,
                              injects payload suite, checks security headers.
Phase 2   wafw00f             WAF detection — informs tamper strategy for later phases.
Phase 3   Recon & OSINT       subfinder/amass, dnsx, httpx, gau/waybackurls
Phase 4   Network             nmap -sV -sC + vuln/ssl NSE scripts
Phase 5   Discovery           feroxbuster/ffuf/gobuster (dir+vhost), arjun (hidden params)
Phase 6   Exploitation        nuclei, nikto, sqlmap, dalfox, wfuzz
Phase 7   Secrets             trufflehog, gitleaks
Final     VulnReport          HTML report with severity dashboard, CVSS, CWE, evidence
```

Each phase only activates if the tool is detected on the machine at scan time. The LLM never receives instructions for tools that aren't present.

---

## Quick Start

```bash
# 1. Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# 2. Build (release for production — 10x faster than debug)
cd rust/
cargo build --release

# 3. Set API key (Nvidia NIM recommended — free tier available)
export NVIDIA_API_KEY=your_key_here
# Or Anthropic:
export ANTHROPIC_API_KEY=your_key_here

# 4. Run
./target/release/claw --model meta/llama-3.3-70b-instruct

# 5. Scan a target
> /vulnscan https://target.example.com
```

---

## Kali Linux — Full Tool Setup

Kali ships with many tools pre-installed. Install the rest for full Phase 2–7 coverage:

### Already on Kali (no action needed)
```bash
nmap sqlmap nikto gobuster wfuzz wafw00f subfinder amass
```

### Install via apt
```bash
sudo apt update
sudo apt install -y ffuf feroxbuster gitleaks
```

### Install via Go (requires Go 1.21+)
```bash
# Install Go if needed
sudo apt install -y golang-go

# ProjectDiscovery toolkit
go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/projectdiscovery/dnsx/cmd/dnsx@latest

# URL harvesting
go install github.com/lc/gau/v2/cmd/gau@latest
go install github.com/tomnomnom/waybackurls@latest

# XSS scanner
go install github.com/hahwul/dalfox/v2@latest

# Add Go bin to PATH
echo 'export PATH=$PATH:$(go env GOPATH)/bin' >> ~/.bashrc
source ~/.bashrc

# Download nuclei templates (required before first nuclei scan)
nuclei -update-templates
```

### Install via pip
```bash
pip3 install arjun
```

### Install trufflehog
```bash
curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sudo sh -s -- -b /usr/local/bin
```

### Verify everything is available
```bash
for tool in nmap sqlmap nuclei nikto dalfox wfuzz gobuster ffuf feroxbuster arjun \
            subfinder amass dnsx httpx gau waybackurls wafw00f trufflehog gitleaks; do
    which $tool &>/dev/null && echo "✓ $tool" || echo "✗ $tool (missing)"
done
```

---

## Usage

```bash
# Full autonomous scan (detects available tools automatically)
> /vulnscan https://target.example.com

# Recon only (passive, no payload injection)
> /recon https://target.example.com
```

The scan purges `helix-sec-findings.json` at the start of each run and accumulates all findings across phases. The final `VulnReport` call reads this file and produces `helix-sec-report.html`.

---

## Report

The HTML report includes:
- Severity dashboard (Critical / High / Medium / Low / Informational counts)
- Finding cards with CVSS score, CWE ID, description, impact, remediation
- Collapsible evidence log per finding
- Raw JSON dump at the bottom

---

## Windows

All phases work on Windows. Tools detected via `where.exe`. For Linux tools on Windows, install WSL — the scanner detects `wsl --status` and can prefix commands with `wsl`.

Tools available via Windows package managers:
```powershell
# Scoop
scoop install nmap ffuf gobuster nuclei

# Chocolatey  
choco install nmap sqlmap
```

---

## API Key Configuration

| Provider | Env Var | Notes |
|---|---|---|
| Nvidia NIM | `NVIDIA_API_KEY` | Free tier, llama-3.3-70b-instruct |
| Anthropic | `ANTHROPIC_API_KEY` | claude-* models |
| OpenAI | `OPENAI_API_KEY` | gpt-* models |

Models with `meta/`, `nvidia/`, `mistralai/`, `google/`, `microsoft/`, `deepseek/` prefix route automatically to NIM.
