<#
===========================================
PowerShell One-Click Cardano-Address Flow
+ Auto CIP-30 Signature Output at End
===========================================
#>

param(
    [switch]$ForceGenerate,
    [switch]$UseTestnet
)

try {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
    if ($scriptPath) { Set-Location -Path $scriptPath }
} catch { }

function Prompt-YesNo($msg, $defaultYes=$true) {
    $choice = Read-Host "$msg [Y/N]"
    if ([string]::IsNullOrWhiteSpace($choice)) { return $defaultYes }
    return $choice.Trim().ToUpper().StartsWith('Y')
}

Write-Host "=== Cardano Mining Registration Full-Auto Flow ===" -ForegroundColor Cyan

# Locate cardano-address
$exePaths = @(".\cardano-address.exe", ".\cardano-address")
$cardanoExe = $exePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $cardanoExe) { Write-Error "cardano-address missing!"; exit 1 }

if ($UseTestnet) {
    $networkTag="testnet"
} else {
    $networkTag = if (Prompt-YesNo "Use testnet?" $false) { "testnet" } else { "mainnet" }
}

Write-Host "Network: $networkTag`n"

$phraseFile = ".\phrase.prv"

# Mnemonic handling
if (-not $ForceGenerate -and (Test-Path $phraseFile)) {
    if (-not (Prompt-YesNo "Use existing phrase.prv?" $true)) { $ForceGenerate=$true }
}
if ($ForceGenerate -or -not (Test-Path $phraseFile)) {
    & $cardanoExe recovery-phrase generate --size 15 > $phraseFile
    if ($LASTEXITCODE -ne 0) { Write-Error "Gen mnemonic failed"; exit 2 }
    Write-Host "Generated new mnemonic -> phrase.prv"
}

Write-Host "`nEnter passphrase (optional):"
$securePass = Read-Host "passphrase" -AsSecureString
$BSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePass)
$passPlain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

# root.xsk
Write-Host "`nCreating root.xsk..."
$inputForRoot = (Get-Content $phraseFile -Raw) + "`n" + $passPlain
$rootKey = ($inputForRoot | & $cardanoExe key from-recovery-phrase Shelley).Trim()
[System.IO.File]::WriteAllText("$PWD\root.xsk", $rootKey, [System.Text.Encoding]::ASCII)
if ($LASTEXITCODE -ne 0) { Write-Host "Fail root"; exit 3 }

# Payment Key
$payPath = "1852H/1815H/0H/0/0"
Write-Host "Deriving payment: $payPath"
$paymentKey = (Get-Content root.xsk -Raw | & $cardanoExe key child $payPath).Trim()
[System.IO.File]::WriteAllText("$PWD\addr.xsk", $paymentKey, [System.Text.Encoding]::ASCII)

$paymentPub = (Get-Content addr.xsk -Raw | & $cardanoExe key public --without-chain-code).Trim()
[System.IO.File]::WriteAllText("$PWD\addr.xvk", $paymentPub, [System.Text.Encoding]::ASCII)

$paymentAddr = (Get-Content addr.xvk -Raw | & $cardanoExe address payment --network-tag $networkTag).Trim()
[System.IO.File]::WriteAllText("$PWD\payment.addr", $paymentAddr, [System.Text.Encoding]::ASCII)

# Stake Key
$stakePath = "1852H/1815H/0H/2/0"
Write-Host "Deriving stake: $stakePath"
$stakeKey = (Get-Content root.xsk -Raw | & $cardanoExe key child $stakePath).Trim()
[System.IO.File]::WriteAllText("$PWD\stake.xsk", $stakeKey, [System.Text.Encoding]::ASCII)

$stakePub = (Get-Content stake.xsk -Raw | & $cardanoExe key public --without-chain-code).Trim()
[System.IO.File]::WriteAllText("$PWD\stake.xvk", $stakePub, [System.Text.Encoding]::ASCII)

$stakeAddr = (Get-Content stake.xvk -Raw | & $cardanoExe address stake --network-tag $networkTag).Trim()
[System.IO.File]::WriteAllText("$PWD\stake.addr", $stakeAddr, [System.Text.Encoding]::ASCII)

# Delegated address
Write-Host "Creating delegated address -> addr.delegated"
$delegatedAddr = (Get-Content payment.addr -Raw | & $cardanoExe address delegation $stakePub).Trim()
[System.IO.File]::WriteAllText("$PWD\addr.delegated", $delegatedAddr, [System.Text.Encoding]::ASCII)

Write-Host "`nAddress delegation done ✅"


### === CIP-30 SIGNATURE SECTION === ###
Write-Host "`n=== Signing CIP-30 Message ===" -ForegroundColor Yellow

# Đọc và ghi lại key với encoding chính xác
$addrXsk = (Get-Content addr.xsk -Raw).Trim()
[System.IO.File]::WriteAllText("$PWD\addr_clean.xsk", $addrXsk, [System.Text.Encoding]::ASCII)

# Convert to CLI .skey JSON
Write-Host "Converting key format..."
.\cardano-cli-win64\cardano-cli.exe key convert-cardano-address-key `
  --shelley-payment-key `
  --signing-key-file addr_clean.xsk `
  --out-file addr.skey

if ($LASTEXITCODE -ne 0) { 
    Write-Error "Failed to convert key"
    Write-Host "Key content length: $($addrXsk.Length) chars"
    Write-Host "Key preview: $($addrXsk.Substring(0, [Math]::Min(60, $addrXsk.Length)))..."
    exit 4 
}

# Sign message
Write-Host "Signing message with CIP-30..."
$message = "I agree to abide by the terms and conditions as described in version 1-0 of the Midnight scavenger mining process: 281ba5f69f4b943e3fb8a20390878a232787a04e4be22177f2472b63df01c200"

.\cardano-signer.exe sign --cip30 `
  --data "$message" `
  --secret-key addr.skey `
  --address "$delegatedAddr" `
  --json-extended > signature.json

if ($LASTEXITCODE -ne 0) { 
    Write-Error "Failed to sign message"
    exit 5
}

# Output formatted result
$sig = Get-Content signature.json | ConvertFrom-Json
$address = Get-Content addr.delegated -Raw
$skey = Get-Content addr.skey | ConvertFrom-Json
$recovervyPhrase = Get-Content phrase.prv -Raw

Write-Host "`n==== FINAL OUTPUT (COPY THIS) ====" -ForegroundColor Green
Write-Host " Your recovery phrase: $recovervyPhrase"

Write-Host "Your private key: $skey"

Write-Host "Mining Address: $address"

Write-Host "Scavenger raw Message: $message"
Write-Host "Signature: $($sig.output.COSE_Sign1_hex)"


Write-Host "Public Key: $($sig.publicKey)"
Write-Host "================================`n"

# Cleanup temporary file
Remove-Item -Path "addr_clean.xsk" -ErrorAction SilentlyContinue

Write-Host "Done! ✅" -ForegroundColor Cyan
