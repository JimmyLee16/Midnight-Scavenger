<#
midnightsigninformulti.ps1
Auto multi-address generator (MAINNET) - Windows PowerShell
Usage (example):
  powershell -NoProfile -ExecutionPolicy Bypass -File .\midnightsigninformulti.ps1 -N 40
#>

param(
    [Parameter(Mandatory=$true)]
    [int]$N
)

# Basic validation
if (-not $N -or $N -lt 1) {
    Write-Host "Số lượng không hợp lệ! ($N)" -ForegroundColor Red
    exit 3
}

try {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
    if ($scriptPath) { Set-Location -Path $scriptPath }
} catch {}

Write-Host "=== AUTO MULTI ADDRESS FLOW (MAINNET) ===" -ForegroundColor Cyan
Write-Host "Will create $N addresses (0 .. $($N - 1))" -ForegroundColor Yellow

# -----------------------------------------------------
# Required executables
# -----------------------------------------------------
$possibleCardanoAddress = @(".\cardano-address.exe", ".\cardano-address")
$cardanoExe = $possibleCardanoAddress | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $cardanoExe) {
    Write-Host "cardano-address executable not found in script folder." -ForegroundColor Red
    exit 1
}
$cardanoCliPath = ".\cardano-cli-win64\cardano-cli.exe"
if (-not (Test-Path $cardanoCliPath)) {
    Write-Host "cardano-cli not found at $cardanoCliPath" -ForegroundColor Red
    exit 1
}
Write-Host "Found cardano-address: $cardanoExe" -ForegroundColor Green
Write-Host "Found cardano-cli: $cardanoCliPath" -ForegroundColor Green

# -----------------------------------------------------
# Helper: run exe reading stdin via temp file + cmd.exe type (Windows-safe)
# Returns stdout string (trimmed)
# -----------------------------------------------------
function Run-WithStdin {
    param(
        [string]$ExePath,
        [string[]]$Args,
        [string]$StdinContent,
        [switch]$ThrowOnNonZeroExit
    )

    $tmpIn = [System.IO.Path]::GetTempFileName()
    $tmpOut = [System.IO.Path]::GetTempFileName()
    try {
        if ($StdinContent -notlike "*`n") { $StdinContent = $StdinContent + "`n" }
        Set-Content -Path $tmpIn -Value $StdinContent -Encoding ASCII

        $argsEscaped = $Args -join " "
        $cmd = "type `"$tmpIn`" | `"$ExePath`" $argsEscaped > `"$tmpOut`" 2>&1"
        $proc = Start-Process -FilePath cmd.exe -ArgumentList "/c", $cmd -NoNewWindow -Wait -PassThru
        $out = ""
        if (Test-Path $tmpOut) {
            $out = Get-Content -Raw -Path $tmpOut -ErrorAction SilentlyContinue
        }
        if ($proc.ExitCode -ne 0) {
            Write-Host "External command [$ExePath $argsEscaped] exited $($proc.ExitCode)" -ForegroundColor Yellow
            if ($out) { Write-Host $out }
            if ($ThrowOnNonZeroExit) { throw "External command failed with exit code $($proc.ExitCode)" }
        }
        return $out.Trim()
    } finally {
        Remove-Item -Path $tmpIn -ErrorAction SilentlyContinue
        Remove-Item -Path $tmpOut -ErrorAction SilentlyContinue
    }
}

# -----------------------------------------------------
# Auto-detect phrase.prv from latest phraseX folder
# -----------------------------------------------------
$phraseFolders = Get-ChildItem -Path $PSScriptRoot -Directory | Where-Object { $_.Name -match '^phrase\d+$' }
if (-not $phraseFolders) {
    Write-Host "Không tìm thấy thư mục phraseX (phrase1, phrase2, ...)" -ForegroundColor Red
    exit 2
}
$latestPhraseFolder = $phraseFolders | Sort-Object { [int]($_.Name -replace 'phrase','') } -Descending | Select-Object -First 1
$phraseFile = Join-Path $latestPhraseFolder.FullName "phrase.prv"
if (-not (Test-Path $phraseFile)) {
    Write-Host "Không tìm thấy phrase.prv trong: $($latestPhraseFolder.FullName)" -ForegroundColor Red
    exit 3
}
Write-Host "Using phrase.prv from: $($latestPhraseFolder.FullName)" -ForegroundColor Green

# -----------------------------------------------------
# Output folder
# -----------------------------------------------------
$outputFolder = ".\generated_keys"
if (-not (Test-Path $outputFolder)) {
    New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
    Write-Host "Created output folder: $outputFolder" -ForegroundColor Green
}

$networkTag = "mainnet"

# -----------------------------------------------------
# Create root.xsk once (safe stdin)
# -----------------------------------------------------
Write-Host "Generating root.xsk..."
$mnemonic = Get-Content -Raw -Path $phraseFile
$passPlain = ""
$inputForRoot = $mnemonic + "`n" + $passPlain

try {
    $rootKey = Run-WithStdin -ExePath $cardanoExe -Args @("key","from-recovery-phrase","Shelley") -StdinContent $inputForRoot -ThrowOnNonZeroExit
    if (-not $rootKey) { throw "rootKey empty" }
    Set-Content -Path "$PWD\root.xsk" -Value $rootKey -Encoding ASCII
} catch {
    Write-Host "Tạo root.xsk thất bại: $_" -ForegroundColor Red
    exit 4
}

# -----------------------------------------------------
# Generate addresses loop (uses $N from param)
# -----------------------------------------------------
for ($i = 0; $i -lt $N; $i++) {
    Write-Host "`n--- Generating address index $i ---" -ForegroundColor Cyan

    $walletFolder = Join-Path $outputFolder "wallet_$i"
    if (-not (Test-Path $walletFolder)) {
        New-Item -Path $walletFolder -ItemType Directory -Force | Out-Null
    }

    $rootContent = Get-Content -Raw -Path "$PWD\root.xsk"

    # Payment key child
    $payPath = "1852H/1815H/0H/0/$i"
    try {
        $paymentKey = Run-WithStdin -ExePath $cardanoExe -Args @("key","child",$payPath) -StdinContent $rootContent -ThrowOnNonZeroExit
        Set-Content -Path "$walletFolder\addr_$i.xsk" -Value $paymentKey -Encoding ASCII
    } catch {
        Write-Host "Lỗi tạo payment key index $i: $_" -ForegroundColor Yellow
        continue
    }

    # Payment public
    try {
        $paymentPub = Run-WithStdin -ExePath $cardanoExe -Args @("key","public","--without-chain-code") -StdinContent $paymentKey
        Set-Content -Path "$walletFolder\addr_$i.xvk" -Value $paymentPub -Encoding ASCII
    } catch {
        Write-Host "Lỗi tạo payment pub index $i: $_" -ForegroundColor Yellow
    }

    # Payment address
    try {
        $paymentAddr = Run-WithStdin -ExePath $cardanoExe -Args @("address","payment","--network-tag",$networkTag) -StdinContent $paymentPub -ThrowOnNonZeroExit
        Set-Content -Path "$walletFolder\payment_$i.addr" -Value $paymentAddr -Encoding ASCII
    } catch {
        Write-Host "Lỗi tạo payment address index $i: $_" -ForegroundColor Yellow
    }

    # Stake key child
    $stakePath = "1852H/1815H/0H/2/$i"
    try {
        $stakeKey = Run-WithStdin -ExePath $cardanoExe -Args @("key","child",$stakePath) -StdinContent $rootContent -ThrowOnNonZeroExit
        Set-Content -Path "$walletFolder\stake_$i.xsk" -Value $stakeKey -Encoding ASCII
    } catch {
        Write-Host "Lỗi tạo stake key index $i: $_" -ForegroundColor Yellow
    }

    try {
        $stakePub = Run-WithStdin -ExePath $cardanoExe -Args @("key","public","--without-chain-code") -StdinContent $stakeKey
        Set-Content -Path "$walletFolder\stake_$i.xvk" -Value $stakePub -Encoding ASCII
    } catch {
        Write-Host "Lỗi tạo stake pub index $i: $_" -ForegroundColor Yellow
    }

    try {
        $stakeAddr = Run-WithStdin -ExePath $cardanoExe -Args @("address","stake","--network-tag",$networkTag) -StdinContent $stakePub -ThrowOnNonZeroExit
        Set-Content -Path "$walletFolder\stake_$i.addr" -Value $stakeAddr -Encoding ASCII
    } catch {
        Write-Host "Lỗi tạo stake address index $i: $_" -ForegroundColor Yellow
    }

    # Delegated address (payment + stake)
    try {
        # cardano-address address delegation <stakePub> expects payment address on stdin (some versions differ)
        $delegatedAddr = Run-WithStdin -ExePath $cardanoExe -Args @("address","delegation",$stakePub) -StdinContent $paymentAddr -ThrowOnNonZeroExit
        Set-Content -Path "$walletFolder\delegated.addr" -Value $delegatedAddr -Encoding ASCII
    } catch {
        Write-Host "Lỗi tạo delegated address index $i: $_" -ForegroundColor Yellow
    }

    # Convert private key to .skey using cardano-cli
    try {
        $addrXsk = (Get-Content "$walletFolder\addr_$i.xsk" -Raw).Trim()
        Set-Content -Path "$walletFolder\addr_$i_clean.xsk" -Value $addrXsk -Encoding ASCII

        $convertCmd = "`"$cardanoCliPath`" key convert-cardano-address-key --shelley-payment-key --signing-key-file `"$walletFolder\addr_$i_clean.xsk`" --out-file `"$walletFolder\addr.skey`""
        $proc = Start-Process -FilePath cmd.exe -ArgumentList "/c", $convertCmd -NoNewWindow -Wait -PassThru
        if ($proc.ExitCode -ne 0) {
            Write-Host "⚠ Failed to convert skey for wallet_$i (exit $($proc.ExitCode))" -ForegroundColor Yellow
        } else {
            Write-Host "Converted addr.skey for wallet_$i" -ForegroundColor Green
        }

        Remove-Item -Path "$walletFolder\addr_$i_clean.xsk" -ErrorAction SilentlyContinue
    } catch {
        Write-Host "Exception converting skey for wallet_$i: $_" -ForegroundColor Yellow
    }

    Write-Host "✓ Created wallet_$i/ (delegated: $delegatedAddr, skey: $(if (Test-Path "$walletFolder\addr.skey") {'OK'} else {'MISSING'}))" -ForegroundColor Green
}

# Cleanup
Remove-Item -Path "root.xsk" -ErrorAction SilentlyContinue

Write-Host "`n=== MULTI ADDRESS GENERATION DONE ===" -ForegroundColor Green
Write-Host "Created $N addresses under: $outputFolder" -ForegroundColor Cyan

exit 0
