<#
===========================================
AUTO Cardano Address + Delegated Address
- No prompts
- Always MAINNET
- Uses phrase.prv provided by GUI
- No CIP-30 signing
===========================================
#>

try {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
    if ($scriptPath) { Set-Location -Path $scriptPath }
} catch {}

Write-Host "=== AUTO Cardano Address Flow (MAINNET) ===" -ForegroundColor Cyan

# -----------------------------------------------------
# REQUIRED EXECUTABLES
# -----------------------------------------------------
$exePaths = @(".\cardano-address.exe", ".\cardano-address")
$cardanoExe = $exePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $cardanoExe) { Write-Error "cardano-address.exe missing!"; exit 1 }

# -----------------------------------------------------
# INPUT: phrase.prv MUST BE PROVIDED BY GUI
# -----------------------------------------------------
$phraseFile = ".\phrase.prv"

if (-not (Test-Path $phraseFile)) {
    Write-Error "phrase.prv not found! GUI must create it before running this script."
    exit 2
}

Write-Host "Using mainnet..."
$networkTag = "mainnet"

# -----------------------------------------------------
# ROOT KEY
# -----------------------------------------------------
Write-Host "Generating root.xsk..."
$inputForRoot = (Get-Content $phraseFile -Raw) + "`n" + $passPlain

$rootKey = ($inputForRoot | & $cardanoExe key from-recovery-phrase Shelley).Trim()
[System.IO.File]::WriteAllText("$PWD\root.xsk", $rootKey, [System.Text.Encoding]::ASCII)

if ($LASTEXITCODE -ne 0) { Write-Error "Failed to create root.xsk"; exit 3 }

# -----------------------------------------------------
# PAYMENT KEY
# -----------------------------------------------------
$payPath = "1852H/1815H/0H/0/0"
Write-Host "Deriving payment key path: $payPath"

$paymentKey = (Get-Content root.xsk -Raw | & $cardanoExe key child $payPath).Trim()
[System.IO.File]::WriteAllText("$PWD\addr.xsk", $paymentKey, [System.Text.Encoding]::ASCII)

$paymentPub = (Get-Content addr.xsk -Raw | & $cardanoExe key public --without-chain-code).Trim()
[System.IO.File]::WriteAllText("$PWD\addr.xvk", $paymentPub, [System.Text.Encoding]::ASCII)

$paymentAddr = (Get-Content addr.xvk -Raw | & $cardanoExe address payment --network-tag $networkTag).Trim()
[System.IO.File]::WriteAllText("$PWD\payment.addr", $paymentAddr, [System.Text.Encoding]::ASCII)

# -----------------------------------------------------
# STAKE KEY
# -----------------------------------------------------
$stakePath = "1852H/1815H/0H/2/0"
Write-Host "Deriving stake key path: $stakePath"

$stakeKey = (Get-Content root.xsk -Raw | & $cardanoExe key child $stakePath).Trim()
[System.IO.File]::WriteAllText("$PWD\stake.xsk", $stakeKey, [System.Text.Encoding]::ASCII)

$stakePub = (Get-Content stake.xsk -Raw | & $cardanoExe key public --without-chain-code).Trim()
[System.IO.File]::WriteAllText("$PWD\stake.xvk", $stakePub, [System.Text.Encoding]::ASCII)

$stakeAddr = (Get-Content stake.xvk -Raw | & $cardanoExe address stake --network-tag $networkTag).Trim()
[System.IO.File]::WriteAllText("$PWD\stake.addr", $stakeAddr, [System.Text.Encoding]::ASCII)

# -----------------------------------------------------
# DELEGATED ADDRESS
# -----------------------------------------------------
Write-Host "Generating delegated address -> addr.delegated"

$delegatedAddr = (Get-Content payment.addr -Raw | & $cardanoExe address delegation $stakePub).Trim()
[System.IO.File]::WriteAllText("$PWD\addr.delegated", $delegatedAddr, [System.Text.Encoding]::ASCII)

# -----------------------------------------------------
# CONVERT PRIVATE KEY → .skey FOR GUI
# -----------------------------------------------------
Write-Host "Converting private key → addr.skey..."

$addrXsk = (Get-Content addr.xsk -Raw).Trim()
[System.IO.File]::WriteAllText("$PWD\addr_clean.xsk", $addrXsk, [System.Text.Encoding]::ASCII)

.\cardano-cli-win64\cardano-cli.exe key convert-cardano-address-key `
  --shelley-payment-key `
  --signing-key-file addr_clean.xsk `
  --out-file addr.skey

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to convert XSK to .skey"
    exit 4
}

Remove-Item -Path "addr_clean.xsk" -ErrorAction SilentlyContinue

# -----------------------------------------------------
# FINAL OUTPUT FOR GUI
# -----------------------------------------------------
Write-Host "`n=== AUTO DONE ===" -ForegroundColor Green
Write-Host "payment.addr → origin address"
Write-Host "addr.skey → private key file"
Write-Host "addr.delegated → full delegated address"
Write-Host "=====================================`n"

exit 0
