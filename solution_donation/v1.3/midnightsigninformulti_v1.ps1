<#
midnightsigninformulti.ps1
Auto multi-address generator with Internal/External paths (MAINNET)
Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\midnightsigninformulti.ps1 -External 40 -Internal 20
#>

param(
    [Parameter(Mandatory=$false)]
    [int]$External = 0,
    
    [Parameter(Mandatory=$false)]
    [int]$Internal = 0
)

if ($External -lt 0 -or $Internal -lt 0) {
    Write-Error "Số lượng không hợp lệ! (External: $External, Internal: $Internal)"
    exit 3
}

if ($External -eq 0 -and $Internal -eq 0) {
    Write-Error "Ít nhất một trong hai (External hoặc Internal) phải lớn hơn 0!"
    exit 3
}

# ensure script runs from its folder
try {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
    if ($scriptPath) { Set-Location -Path $scriptPath }
} catch {}

Write-Output "=== AUTO MULTI ADDRESS FLOW (MAINNET) ==="
Write-Output "External addresses (0/$i): $External"
Write-Output "Internal addresses (1/$i): $Internal"

# -----------------------------------------------------
# Required executables
# -----------------------------------------------------
$possibleCardanoAddress = @(".\cardano-address.exe", ".\cardano-address")
$cardanoExeRel = $possibleCardanoAddress | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $cardanoExeRel) {
    Write-Error "cardano-address executable not found in script folder."
    exit 1
}
try {
    $cardanoAddressFull = (Resolve-Path $cardanoExeRel).Path
} catch {
    Write-Error "Không thể resolve cardano-address path: $_"
    exit 1
}

$cardanoCliRel = ".\cardano-cli-win64\cardano-cli.exe"
if (-not (Test-Path $cardanoCliRel)) {
    Write-Error "cardano-cli not found at $cardanoCliRel"
    exit 1
}
try {
    $cardanoCliFull = (Resolve-Path $cardanoCliRel).Path
} catch {
    Write-Error "Không thể resolve cardano-cli path: $_"
    exit 1
}

Write-Output "Found cardano-address: $cardanoAddressFull"
Write-Output "Found cardano-cli: $cardanoCliFull"

# -----------------------------------------------------
# Find latest phrase folder
# -----------------------------------------------------
$phraseFolders = Get-ChildItem -Path $PSScriptRoot -Directory | Where-Object { $_.Name -match '^phrase\d+$' }
if (-not $phraseFolders) {
    Write-Error "Không tìm thấy thư mục phraseX (phrase1, phrase2, ...)"
    exit 2
}
$latestPhraseFolder = $phraseFolders | Sort-Object { [int]($_.Name -replace 'phrase','') } -Descending | Select-Object -First 1
$phraseFile = Join-Path $latestPhraseFolder.FullName "phrase.prv"
if (-not (Test-Path $phraseFile)) {
    Write-Error "Không tìm thấy phrase.prv trong: $($latestPhraseFolder.FullName)"
    exit 3
}
Write-Output "Using phrase.prv from: $($latestPhraseFolder.FullName)"

Set-Location -Path $latestPhraseFolder.FullName

# -----------------------------------------------------
# Prepare output folder
# -----------------------------------------------------
$outputFolder = Join-Path $latestPhraseFolder.FullName "generated_keys"
if (-not (Test-Path $outputFolder)) {
    New-Item -Path $outputFolder -ItemType Directory -Force | Out-Null
    Write-Output "Created output folder: $outputFolder"
}

$networkTag = "mainnet"

# -----------------------------------------------------
# Read & normalize mnemonic
# -----------------------------------------------------
Write-Output "Generating root.xsk..."

$rawBytes = [System.IO.File]::ReadAllBytes($phraseFile)

if ($rawBytes.Length -ge 3 -and $rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF) {
    Write-Output "Detected UTF-8 BOM → stripping..."
    $rawBytes = $rawBytes[3..($rawBytes.Length-1)]
}

if ($rawBytes.Length -ge 2 -and $rawBytes[0] -eq 0xFF -and $rawBytes[1] -eq 0xFE) {
    $textUTF16 = [System.Text.Encoding]::Unicode.GetString($rawBytes)
    $rawBytes = [System.Text.Encoding]::UTF8.GetBytes($textUTF16)
}

$mnemonic = [System.Text.Encoding]::UTF8.GetString($rawBytes)
$mnemonic = $mnemonic -replace "[\r`n]+", " "
$mnemonic = ($mnemonic -split '\s+') -join ' '
$mnemonic = $mnemonic.Trim()

$words = ($mnemonic -split '\s+')
Write-Output "=== DEBUG MNEMONIC ==="
Write-Output ("Length: {0} chars" -f $mnemonic.Length)
Write-Output ("Words count: {0}" -f $words.Length)
Write-Output "======================"

if ($words.Length -lt 12) {
    Write-Error "Mnemonic seems too short ({0} words)." -f $words.Length
    exit 4
}

# -----------------------------------------------------
# Generate root.xsk
# -----------------------------------------------------
try {
    $rootKey = ($mnemonic | & $cardanoAddressFull key from-recovery-phrase Shelley).Trim()
    if (-not $rootKey) { throw "rootKey empty" }
    Set-Content -Path (Join-Path (Get-Location) "root.xsk") -Value $rootKey -Encoding ASCII
} catch {
    Write-Error "Tạo root.xsk thất bại: $($_)"
    exit 5
}

$rootKeyPath = (Join-Path (Get-Location) "root.xsk")

# -----------------------------------------------------
# Prepare job control
# -----------------------------------------------------
$maxParallel = 6

$logFile = Join-Path (Get-Location) "generation.log"
"=== Start generation: $(Get-Date -Format u) ===" | Out-File -FilePath $logFile -Encoding utf8

# Job script - now accepts pathType parameter
$jobScript = {
    param(
        $i,
        $pathType,
        $rootKeyPath,
        $outputFolder,
        $cardanoAddressFull,
        $cardanoCliFull,
        $networkTag,
        $logFile
    )

    try {
        Add-Content -Path $logFile -Value ("[{0}] Starting {1} index {2}" -f (Get-Date -Format o), $pathType, $i)

        $walletFolder = Join-Path $outputFolder "wallet_${pathType}_$i"
        if (-not (Test-Path $walletFolder)) {
            New-Item -Path $walletFolder -ItemType Directory -Force | Out-Null
        }

        $rootContent = (Get-Content -Raw -Path $rootKeyPath).Trim()

        # PAYMENT PATH - different based on pathType
        if ($pathType -eq "external") {
            $payPath = "1852H/1815H/0H/0/$i"
        } else {
            $payPath = "1852H/1815H/0H/1/$i"
        }
        
        $paymentKey = ($rootContent | & $cardanoAddressFull key child $payPath).Trim()
        Set-Content -Path (Join-Path $walletFolder ("addr_$i.xsk")) -Value $paymentKey -Encoding ASCII

        $paymentPub = ($paymentKey | & $cardanoAddressFull key public --without-chain-code).Trim()
        Set-Content -Path (Join-Path $walletFolder ("addr_$i.xvk")) -Value $paymentPub -Encoding ASCII

        $paymentAddr = ($paymentPub | & $cardanoAddressFull address payment --network-tag $networkTag).Trim()
        Set-Content -Path (Join-Path $walletFolder ("payment_$i.addr")) -Value $paymentAddr -Encoding ASCII

        # STAKE PATH
        $stakePath = "1852H/1815H/0H/2/$i"
        $stakeKey = ($rootContent | & $cardanoAddressFull key child $stakePath).Trim()
        Set-Content -Path (Join-Path $walletFolder ("stake_$i.xsk")) -Value $stakeKey -Encoding ASCII

        $stakePub = ($stakeKey | & $cardanoAddressFull key public --without-chain-code).Trim()
        Set-Content -Path (Join-Path $walletFolder ("stake_$i.xvk")) -Value $stakePub -Encoding ASCII

        $stakeAddr = ($stakePub | & $cardanoAddressFull address stake --network-tag $networkTag).Trim()
        Set-Content -Path (Join-Path $walletFolder ("stake_$i.addr")) -Value $stakeAddr -Encoding ASCII

        # DELEGATED ADDRESS
        $delegatedAddr = ($paymentAddr | & $cardanoAddressFull address delegation $stakePub).Trim()
        Set-Content -Path (Join-Path $walletFolder "delegated.addr") -Value $delegatedAddr -Encoding ASCII

        # CONVERT PRIVATE KEY TO .SKEY
        $addrXsk = (Get-Content -Raw -Path (Join-Path $walletFolder ("addr_$i.xsk"))).Trim()
        $cleanPath = (Join-Path $walletFolder ("addr_${i}_clean.xsk"))
        Set-Content -Path $cleanPath -Value $addrXsk -Encoding ASCII

        $outSkey = (Join-Path $walletFolder "addr.skey")
        $proc = Start-Process -FilePath $cardanoCliFull -ArgumentList @(
            "key", "convert-cardano-address-key",
            "--shelley-payment-key",
            "--signing-key-file", $cleanPath,
            "--out-file", $outSkey
        ) -NoNewWindow -Wait -PassThru

        if ($proc -and $proc.ExitCode -ne 0) {
            Add-Content -Path $logFile -Value ("[{0}] ⚠ Failed to convert skey for wallet_{1}_{2} (exit {3})" -f (Get-Date -Format o), $pathType, $i, $proc.ExitCode)
        } else {
            Add-Content -Path $logFile -Value ("[{0}] Converted addr.skey for wallet_{1}_{2}" -f (Get-Date -Format o), $pathType, $i)
        }

        Remove-Item -Path $cleanPath -ErrorAction SilentlyContinue

        $status = if (Test-Path $outSkey) { 'OK' } else { 'MISSING' }
        Add-Content -Path $logFile -Value ("[{0}] ✓ Created wallet_{1}_{2}/ (delegated: {3}, skey: {4})" -f (Get-Date -Format o), $pathType, $i, $delegatedAddr, $status)

        # Append summary
        try {
            $phraseFolder = Split-Path -Parent $outputFolder
            $summaryFile = Join-Path $phraseFolder 'delegated_summary.txt'
            $skeyFull = ''
            if (Test-Path $outSkey) {
                try { $skeyFull = (Resolve-Path $outSkey -ErrorAction Stop).Path } catch { $skeyFull = $outSkey }
            }
            $summaryLine = "wallet_${pathType}_$i|$delegatedAddr|$skeyFull"
            [System.IO.File]::AppendAllText($summaryFile, $summaryLine + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
        } catch {
            Add-Content -Path $logFile -Value ("[{0}] ⚠ Failed to append summary for wallet_{1}_{2}: {3}" -f (Get-Date -Format o), $pathType, $i, $_.Exception.Message)
        }

    } catch {
        $err = $_
        Add-Content -Path $logFile -Value ("[{0}] ERROR {1} index {2}: {3}" -f (Get-Date -Format o), $pathType, $i, $err.ToString())
    }
}

# -----------------------------------------------------
# Launch jobs for External addresses (0/$i)
# -----------------------------------------------------
$jobs = @()

if ($External -gt 0) {
    Write-Output "Creating $External external addresses..."
    for ($i = 0; $i -lt $External; $i++) {
        while ((Get-Job -State Running).Count -ge $maxParallel) {
            Start-Sleep -Milliseconds 200
        }

        $job = Start-Job -ScriptBlock $jobScript -ArgumentList @(
            $i,
            "external",
            $rootKeyPath,
            $outputFolder,
            $cardanoAddressFull,
            $cardanoCliFull,
            $networkTag,
            $logFile
        )
        $jobs += $job
        Write-Output ("Started job for external index {0} (Id {1})" -f $i, $job.Id)
    }
}

# -----------------------------------------------------
# Launch jobs for Internal addresses (1/$i)
# -----------------------------------------------------
if ($Internal -gt 0) {
    Write-Output "Creating $Internal internal addresses..."
    for ($i = 0; $i -lt $Internal; $i++) {
        while ((Get-Job -State Running).Count -ge $maxParallel) {
            Start-Sleep -Milliseconds 200
        }

        $job = Start-Job -ScriptBlock $jobScript -ArgumentList @(
            $i,
            "internal",
            $rootKeyPath,
            $outputFolder,
            $cardanoAddressFull,
            $cardanoCliFull,
            $networkTag,
            $logFile
        )
        $jobs += $job
        Write-Output ("Started job for internal index {0} (Id {1})" -f $i, $job.Id)
    }
}

# -----------------------------------------------------
# Wait for all jobs
# -----------------------------------------------------
Write-Output "Waiting for jobs to complete..."
while ((Get-Job -State Running).Count -gt 0) {
    Start-Sleep -Seconds 1
}

foreach ($j in $jobs) {
    try {
        Receive-Job -Job $j -ErrorAction SilentlyContinue | Out-Null
    } catch {}
    try { Remove-Job -Job $j -Force -ErrorAction SilentlyContinue } catch {}
}

Add-Content -Path $logFile -Value ("=== End generation: $(Get-Date -Format u) ===")

try {
    Remove-Item -Path $rootKeyPath -ErrorAction SilentlyContinue
} catch {}

Write-Output ""
Write-Output "=== MULTI ADDRESS GENERATION DONE ==="
Write-Output "Created $External external + $Internal internal addresses under: $outputFolder"
Write-Output "Log: $logFile"
exit 0