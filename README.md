# Educational SSH Brute-Force Simulation (PowerShell)

**VERY IMPORTANT – LEGAL WARNING**

> This repository exists **exclusively for educational purposes**, red team / blue team training, cybersecurity courses, CTF challenges and **authorized penetration testing only**.
>
> **Using this script (or any similar tool) against systems you do NOT own or have explicit written permission to test is illegal** in almost every country.
> I do **not** condone, encourage or support unauthorized access in any form.

## What this is for

Very **slow, noisy, deliberately inefficient** PowerShell demonstration showing how password guessing against SSH looks from the attacker's side.
**Features:**

- Exponential backoff + random jitter (mimics real cautious attackers)
- Progress bar
- --WhatIf safety switch
- Mandatory confirmation prompt
- Clear logging to console
- Uses `plink.exe` (PuTTY link) – easy to swap for native `ssh` if preferred

**This script is extremely easy to detect** (fail2ban, CrowdSec, AWS GuardDuty, simple log analysis catch it in seconds).

Real tools (hydra, medusa, patator, crowbar, ...) are 100–1000× faster and much stealthier.

## Requirements

- Windows (or PowerShell 7+ on Linux/macOS)
- `plink.exe` in PATH (from PuTTY package) – or replace with native `ssh` call
- Small wordlist (example: first 1000 lines of rockyou.txt)

## Usage example

```powershell
.\SSH-Brute-Demo.ps1 -Target 192.168.56.101 -Port 22 -User testuser `
                     -Wordlist .\rockyou-1000.txt `
                     -DelayMinMs 1200 -DelayMaxMs 8000 `
                     -BackoffFactor 1.6 `
                     -MaxAttempts 1000
