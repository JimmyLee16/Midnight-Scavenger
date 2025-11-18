Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================
# GLOBAL VARIABLES
# ============================================
$script:apiBase = "https://scavenger.prod.gd.midnighttge.io"
$script:addressPanels = @()
$script:isExecuting = $false
$script:logBox = $null

# ============================================
# HELPER FUNCTIONS
# ============================================

function Write-Log {
    param([string]$Message, [string]$Color = "Black")

    if ($null -eq $script:logBox) { return }

    $timestamp = Get-Date -Format "HH:mm:ss"
    $logMessage = "[$timestamp] $Message`r`n"

    # Map logical color names to actual System.Drawing.Color
    switch ($Color.ToLower()) {
        'softred' { $col = [System.Drawing.Color]::FromArgb(255,107,107) }
        'red'     { $col = [System.Drawing.Color]::FromArgb(255,80,80) }
        'green'   { $col = [System.Drawing.Color]::FromArgb(126, 231, 135) }
        'blue'    { $col = [System.Drawing.Color]::FromArgb(154,209,255) }
        'yellow'  { $col = [System.Drawing.Color]::FromArgb(255,184,107) }
        'orange'  { $col = [System.Drawing.Color]::FromArgb(255,165,0) }
        'purple'  { $col = [System.Drawing.Color]::FromArgb(170,120,255) }
        'gray'    { $col = [System.Drawing.Color]::FromArgb(154,166,178) }
        default   { $col = [System.Drawing.Color]::FromArgb(230,238,240) }
    }

    try {
        # If logBox is a RichTextBox we can set selection color per append
        if ($script:logBox -is [System.Windows.Forms.RichTextBox]) {
            $start = $script:logBox.TextLength
            $script:logBox.SelectionStart = $start
            $script:logBox.SelectionColor = $col
            $script:logBox.AppendText($logMessage)
            $script:logBox.SelectionColor = $script:logBox.ForeColor
            $script:logBox.ScrollToCaret()
        } else {
            # Fallback to TextBox behavior
            $script:logBox.AppendText($logMessage)
            $script:logBox.Refresh()
        }
    } catch {
        # Ignore logging errors to avoid breaking UI flows
    }
}

function Get-Statistics {
    param([string]$Address)
    
    try {
        $statUrl = "$script:apiBase/statistics/$Address"
        $response = Invoke-RestMethod -Uri $statUrl -Method GET -TimeoutSec 10 -ErrorAction Stop
        
        if ($response.PSObject.Properties.Name -contains 'local' -and 
            $response.local.PSObject.Properties.Name -contains 'crypto_receipts') {
            return [int]$response.local.crypto_receipts
        }
        return 0
    } catch {
        Write-Log "⚠ Cannot get stats for ${Address}: $($_.Exception.Message)" "Orange"
        return 0
    }
}

function Create-Signature {
    param(
        [string]$OriginalAddress,
        [string]$DestinationAddress,
        [string]$SkeyPath
    )
    
    $message = "Assign accumulated Scavenger rights to: $DestinationAddress"
    $signatureFile = "signature_temp_$(Get-Date -Format 'yyyyMMddHHmmss').json"
    
    try {
        # Find cardano-signer
        $signerPath = ".\cardano-signer.exe"
        if (-not (Test-Path $signerPath)) {
            try {
                $null = Get-Command cardano-signer -ErrorAction Stop
                $signerPath = "cardano-signer"
            } catch {
                throw "Cannot find cardano-signer.exe"
            }
        }
        
        # Create signature
        & $signerPath sign --cip30 `
            --data "$message" `
            --secret-key "$SkeyPath" `
            --address "$OriginalAddress" `
            --json-extended > $signatureFile
        
        if ($LASTEXITCODE -ne 0) {
            throw "cardano-signer returned error"
        }
        
        $sigJson = Get-Content $signatureFile | ConvertFrom-Json
        $signature = $sigJson.output.COSE_Sign1_hex
        
        # Remove temp file
        Remove-Item $signatureFile -ErrorAction SilentlyContinue
        
        return $signature
    } catch {
        Write-Log "ERROR creating signature: $($_.Exception.Message)" "SoftRed"
        if (Test-Path $signatureFile) {
            Remove-Item $signatureFile -ErrorAction SilentlyContinue
        }
        return $null
    }
}

function Execute-Donation {
    param(
        [string]$OriginalAddress,
        [string]$DestinationAddress,
        [string]$Signature
    )
    
    try {
        $donateUrl = "$script:apiBase/donate_to/$DestinationAddress/$OriginalAddress/$Signature"
        $resp = Invoke-RestMethod -Uri $donateUrl -Method POST -ErrorAction Stop
        return $resp
    } catch {
        $errorMsg = $_.Exception.Message
        if ($_.Exception.Response) {
            try {
                $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
                $errorBody = $reader.ReadToEnd()
                $errorMsg += "`n$errorBody"
            } catch {}
        }
        Write-Log "ERROR API: $errorMsg" "SoftRed"
        return $null
    }
}

function Process-Response {
    param($Response, [string]$OriginalAddr, [string]$DestAddr)
    
    $logContent = @"
================================================
Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Original: $OriginalAddr
Destination: $DestAddr
================================================

"@
    
    if ($Response.status -eq "success") {
        $msg = $Response.message
        $solutionsMoved = if ($Response.PSObject.Properties.Name -contains "Solutions_consolidated") { 
            $Response.Solutions_consolidated 
        } else { 0 }
        
        Write-Log "SUCCESS: $msg" "Green"
        $logContent += "SUCCESS`n$msg`n"
        
        if ($solutionsMoved -gt 0) {
            Write-Log "Transferred: $solutionsMoved solutions" "Blue"
            $logContent += "Transferred: $solutionsMoved solutions`n"
        } else {
            Write-Log "No solutions to transfer (0)" "Orange"
            $logContent += "No solutions to transfer (0)`n"
        }
        
        if ($Response.original_address -eq $Response.destination_address) {
            Write-Log "UNDO operation (transfer back to original wallet)" "Purple"
            $logContent += "UNDO operation`n"
        }
        
    } elseif ($Response.statusCode -eq 409) {
        Write-Log "CONFLICT: Wallet already has active donation to this address" "Orange"
        Write-Log "-> $($Response.message)" "Orange"
        $logContent += "CONFLICT (409)`n$($Response.message)`n"
        
    } elseif ($Response.statusCode -eq 400) {
        Write-Log "SIGNATURE ERROR: Invalid" "SoftRed"
        Write-Log "-> $($Response.message)" "SoftRed"
        $logContent += "Bad Request (400)`n$($Response.message)`n"
        
    } elseif ($Response.statusCode -eq 404) {
        Write-Log "WALLET NOT FOUND: Not registered in system" "SoftRed"
        Write-Log "-> $($Response.message)" "SoftRed"
        $logContent += "Not Found (404)`n$($Response.message)`n"
        
    } else {
        Write-Log "Other result from server" "Blue"
        $logContent += "Other result`n"
    }
    
    $rawJson = $Response | ConvertTo-Json -Depth 10
    $logContent += "`n=== RAW JSON ===`n$rawJson`n`n"
    
    return $logContent
}

function Save-FullLog {
    param([string]$Content)
    
    $logFile = "donation_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $header = 'Timestamp,Origin,Destination,Result'
    $csvLines = @($header)
    $lines = $Content -split "`n"
    foreach ($line in $lines) {
        if ($line -match 'Time: (.+)') { $ts = $matches[1] }
        if ($line -match 'Original: (.+)') { $orig = $matches[1] }
        if ($line -match 'Destination: (.+)') { $dest = $matches[1] }
        if ($line -match 'SUCCESS') { $result = 'SUCCESS' }
        elseif ($line -match 'No solutions to transfer') { $result = 'NO_SOLUTIONS' }
        elseif ($line -match 'CONFLICT') { $result = 'CONFLICT' }
        elseif ($line -match 'SIGNATURE ERROR') { $result = 'SIGNATURE_ERROR' }
        elseif ($line -match 'WALLET NOT FOUND') { $result = 'NOT_FOUND' }
        elseif ($line -match 'Other result') { $result = 'OTHER' }
        if ($line -match '=== RAW JSON ===') {
            $csvLines += "$ts,$orig,$dest,$result"
            $ts = $orig = $dest = $result = ''
        }
    }
    $csvLines | Out-File -FilePath $logFile -Encoding UTF8
    Write-Log "Log saved: $logFile" "Blue"
    # Open log file
    Start-Process notepad.exe $logFile
}

# Auto-fill helper: load `addr.delegated` and `addr.skey` from the script folder
function Load-FromMidnightSigner {
    try {
        $addrFile = Join-Path $PSScriptRoot "addr.delegated"
        $skeyFile = Join-Path $PSScriptRoot "addr.skey"

        $needGenerate = -not (Test-Path $addrFile) -or -not (Test-Path $skeyFile)

        if ($needGenerate) {
            $scriptPath = Join-Path $PSScriptRoot "midnightsigninfo.ps1"
            if (-not (Test-Path $scriptPath)) {
                Write-Log "⚠ Signer files missing and midnightsigninfo.ps1 not found" "SoftRed"
                return $false
            }

            Write-Log "⏳ Running midnightsigninfo.ps1 to generate keys..." "Yellow"
            
            # Chạy và ĐỢI script hoàn tất
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "powershell.exe"
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
            $psi.UseShellExecute = $true
            $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
            
            $process = [System.Diagnostics.Process]::Start($psi)
            $process.WaitForExit()
            
            $exitCode = $process.ExitCode
            
            if ($exitCode -ne 0) {
                Write-Log "✗ midnightsigninfo.ps1 failed (exit code: $exitCode)" "SoftRed"
                return $false
            }

            Write-Log "✓ Signer script completed successfully" "Green"
            
            # Đợi file system sync (quan trọng!)
            Start-Sleep -Milliseconds 1000
        }

        # Kiểm tra file tồn tại
        if (-not (Test-Path $addrFile)) {
            Write-Log "✗ addr.delegated not found: $addrFile" "SoftRed"
            return $false
        }

        if (-not (Test-Path $skeyFile)) {
            Write-Log "✗ addr.skey not found: $skeyFile" "SoftRed"
            return $false
        }

        # Đọc địa chỉ từ file text
        $addr = (Get-Content $addrFile -Raw -ErrorAction Stop).Trim()
        
        if ([string]::IsNullOrWhiteSpace($addr)) {
            Write-Log "✗ addr.delegated is empty!" "SoftRed"
            return $false
        }

        # Validate địa chỉ Cardano (bắt đầu bằng addr1)
        if (-not $addr.StartsWith("addr1")) {
            Write-Log "⚠ Address format may be invalid: $addr" "Orange"
        }

        # Đảm bảo có ít nhất 1 panel
        if ($script:addressPanels.Count -eq 0) { 
            Add-AddressPanel 
        }

        $firstPanel = $script:addressPanels[0]
        
        if ($null -eq $firstPanel) {
            Write-Log "✗ Cannot access address panel" "SoftRed"
            return $false
        }

        # Fill dữ liệu vào panel
        $firstPanel.TextBoxOriginal.Text = $addr
        
        # Lấy đường dẫn đầy đủ cho skey
        try {
            $fullSkeyPath = (Resolve-Path $skeyFile -ErrorAction Stop).Path
            $firstPanel.TextBoxSkey.Text = $fullSkeyPath
            
            Write-Log "✓ Origin Address: $($addr.Substring(0,20))..." "Green"
            Write-Log "✓ Private Key: $(Split-Path $fullSkeyPath -Leaf)" "Green"
            
            return $true
            
        } catch {
            # Fallback: dùng relative path
            $firstPanel.TextBoxSkey.Text = $skeyFile
            Write-Log "✓ Origin Address: $($addr.Substring(0,20))..." "Green"
            Write-Log "⚠ Using relative path for skey" "Yellow"
            return $true
        }
        
    } catch {
        Write-Log "✗ Auto-fill error: $($_.Exception.Message)" "SoftRed"
        return $false
    }
}

# ============================================
# ADDRESS PANEL MANAGEMENT
# ============================================

function Add-AddressPanel {
    $panelHeight = 110
    $panelY = 10 + ($script:addressPanels.Count * ($panelHeight + 10))

    # Container Panel
    $addrPanel = New-Object System.Windows.Forms.Panel
    $addrPanel.Location = New-Object System.Drawing.Point(10, $panelY)
    $addrPanel.Size = New-Object System.Drawing.Size(760, $panelHeight)
    $addrPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $addrPanel.BackColor = [System.Drawing.Color]::WhiteSmoke

    # Label number
    $lblNum = New-Object System.Windows.Forms.Label
    $lblNum.Location = New-Object System.Drawing.Point(5, 8)
    $lblNum.Size = New-Object System.Drawing.Size(30, 20)
    $lblNum.Text = "#$($script:addressPanels.Count + 1)"
    $lblNum.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $addrPanel.Controls.Add($lblNum)

    # Original Address Label
    $lblOriginal = New-Object System.Windows.Forms.Label
    $lblOriginal.Location = New-Object System.Drawing.Point(40, 8)
    $lblOriginal.Size = New-Object System.Drawing.Size(100, 20)
    $lblOriginal.Text = "Original Address:"
    $lblOriginal.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $addrPanel.Controls.Add($lblOriginal)

    # Original Address TextBox
    $txtOriginal = New-Object System.Windows.Forms.TextBox
    $txtOriginal.Location = New-Object System.Drawing.Point(145, 8)
    $txtOriginal.Size = New-Object System.Drawing.Size(390, 20)
    $txtOriginal.Text = ""
    $addrPanel.Controls.Add($txtOriginal)

    # Check Button (same row as Original Address)
    $btnCheck = New-Object System.Windows.Forms.Button
    $btnCheck.Location = New-Object System.Drawing.Point(550, 5)
    $btnCheck.Size = New-Object System.Drawing.Size(80, 50)
    $btnCheck.Text = "Check"
    $btnCheck.BackColor = [System.Drawing.Color]::LightBlue
    $btnCheck.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

    $btnCheck.Add_Click({
        $btnCheck.Enabled = $false
        $btnCheck.Text = 'Wait...'
        $solutions = Get-Statistics -Address $txtOriginal.Text.Trim()
        $lblSolutions.Text = "Solutions: $solutions"
        $lblSolutions.ForeColor = if ($solutions -gt 0) { [System.Drawing.Color]::Green } else { [System.Drawing.Color]::Red }
        Write-Log "Checked: $($txtOriginal.Text.Trim()) - $solutions solutions" "Blue"
        $btnCheck.Text = 'Check'
        $btnCheck.Enabled = $true
    }.GetNewClosure())

    $addrPanel.Controls.Add($btnCheck)

    # Execute Button (same row as Original Address)
    $btnExecute = New-Object System.Windows.Forms.Button
    $btnExecute.Location = New-Object System.Drawing.Point(640, 5)
    $btnExecute.Size = New-Object System.Drawing.Size(80, 50)
    $btnExecute.Text = "Execute"
    $btnExecute.BackColor = [System.Drawing.Color]::LightGreen
    $btnExecute.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $btnExecute.Add_Click({
        if ($script:isExecuting) {
            [System.Windows.Forms.MessageBox]::Show('Execution in progress, please wait!', 'Info', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }
        Execute-SingleAddress -Panel $addrPanel
    }.GetNewClosure())
    $addrPanel.Controls.Add($btnExecute)

    # Remove Button (same row as Original Address)
    $btnRemove = New-Object System.Windows.Forms.Button
    $btnRemove.Location = New-Object System.Drawing.Point(730, 5)
    $btnRemove.Size = New-Object System.Drawing.Size(25, 50)
    $btnRemove.Text = "X"
    $btnRemove.BackColor = [System.Drawing.Color]::LightCoral
    $btnRemove.ForeColor = [System.Drawing.Color]::White
    $btnRemove.Font = New-Object System.Drawing.Font("Arial", 10, [System.Drawing.FontStyle]::Bold)
    $btnRemove.Add_Click({ Remove-AddressPanel -Panel $addrPanel }.GetNewClosure())
    $addrPanel.Controls.Add($btnRemove)

    # Private Key Label
    $lblSkey = New-Object System.Windows.Forms.Label
    $lblSkey.Location = New-Object System.Drawing.Point(40, 35)
    $lblSkey.Size = New-Object System.Drawing.Size(100, 20)
    $lblSkey.Text = "Private Key (.skey):"
    $lblSkey.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $addrPanel.Controls.Add($lblSkey)

    # Per-panel SKey TextBox (readonly) and Load button
    $txtPanelSkey = New-Object System.Windows.Forms.TextBox
    $txtPanelSkey.Location = New-Object System.Drawing.Point(145, 35)
    $txtPanelSkey.Size = New-Object System.Drawing.Size(365, 20)
    $txtPanelSkey.ReadOnly = $true
    $txtPanelSkey.Font = New-Object System.Drawing.Font("Consolas", 8)
    $txtPanelSkey.BackColor = [System.Drawing.Color]::White
    $txtPanelSkey.Multiline = $false
    $addrPanel.Controls.Add($txtPanelSkey)

    $btnLoadSkey = New-Object System.Windows.Forms.Button
    $btnLoadSkey.Location = New-Object System.Drawing.Point(515, 35)
    $btnLoadSkey.Size = New-Object System.Drawing.Size(30, 20)
    $btnLoadSkey.Text = "..."
    $btnLoadSkey.Font = New-Object System.Drawing.Font("Segoe UI", 8)
    $btnLoadSkey.Add_Click({
        $fd = New-Object System.Windows.Forms.OpenFileDialog
        $fd.Filter = "Key Files (*.skey;*.json)|*.skey;*.json|All Files (*.*)|*.*"
        if ($fd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $file = $fd.FileName
            $txtPanelSkey.Text = $file
            Write-Log "✓ Selected key: $(Split-Path $file -Leaf)" "Green"
        }
    }.GetNewClosure())
    $addrPanel.Controls.Add($btnLoadSkey)

    # Recovery Label
    $lblRecovery = New-Object System.Windows.Forms.Label
    $lblRecovery.Location = New-Object System.Drawing.Point(40, 60)
    $lblRecovery.Size = New-Object System.Drawing.Size(100, 20)
    $lblRecovery.Text = "Recovery:"
    $addrPanel.Controls.Add($lblRecovery)

    # Recovery TextBox
    $txtRecovery = New-Object System.Windows.Forms.TextBox
    $txtRecovery.Location = New-Object System.Drawing.Point(145, 60)
    $txtRecovery.Size = New-Object System.Drawing.Size(365, 20)
    $addrPanel.Controls.Add($txtRecovery)

    # Recovery Enter Button
    $btnEnterRecovery = New-Object System.Windows.Forms.Button
    $btnEnterRecovery.Location = New-Object System.Drawing.Point(515, 58)
    $btnEnterRecovery.Size = New-Object System.Drawing.Size(60, 24)
    $btnEnterRecovery.Text = "Auto"
    $btnEnterRecovery.Add_Click({
        $recoveryText = $txtRecovery.Text.Trim()
        
        if ([string]::IsNullOrWhiteSpace($recoveryText)) { 
            [System.Windows.Forms.MessageBox]::Show(
                "Please enter your recovery phrase!",
                "Warning",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return 
        }
        
        # Validate recovery phrase (15 hoặc 24 từ)
        $words = $recoveryText.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
        if ($words.Count -ne 12 -and $words.Count -ne 15 -and $words.Count -ne 24) {
            $result = [System.Windows.Forms.MessageBox]::Show(
                "Recovery phrase should be 12,15,24 words. You entered $($words.Count) words.`n`nContinue anyway?",
                "Warning",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
                return
            }
        }
        
        Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Blue"
        Write-Log "🔑 Processing recovery phrase..." "Yellow"
        
        # Lưu phrase vào file
        $phraseFile = Join-Path $PSScriptRoot "phrase.prv"
        try {
            Set-Content -Path $phraseFile -Value $recoveryText -Force -Encoding UTF8
            Write-Log "✓ Recovery phrase saved to phrase.prv" "Green"
        } catch {
            Write-Log "✗ Failed to save phrase: $($_.Exception.Message)" "SoftRed"
            return
        }
        
        # Kiểm tra script tồn tại
        $scriptPath = Join-Path $PSScriptRoot "midnightsigninfo.ps1"
        if (-not (Test-Path $scriptPath)) {
            Write-Log "✗ midnightsigninfo.ps1 not found!" "SoftRed"
            [System.Windows.Forms.MessageBox]::Show(
                "midnightsigninfo.ps1 not found in script folder!",
                "Error",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return
        }
        
        # Disable button
        $btnEnterRecovery.Enabled = $false
        $originalText = $btnEnterRecovery.Text
        $btnEnterRecovery.Text = "⏳"
        
        Write-Log "⏳ Generating keys from recovery phrase..." "Yellow"
        Write-Log "   (This may take 10-30 seconds, please wait)" "Gray"
        
        try {
            # Chạy script và đợi
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "powershell.exe"
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
            $psi.UseShellExecute = $true
            $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
            
            $process = [System.Diagnostics.Process]::Start($psi)
            $process.WaitForExit()
            
            $exitCode = $process.ExitCode
            
            # Restore button
            $btnEnterRecovery.Text = $originalText
            $btnEnterRecovery.Enabled = $true
            
            if ($exitCode -eq 0) {
                Write-Log "✓ Key generation completed!" "Green"
                
                # Đợi file system sync
                Start-Sleep -Milliseconds 1500
                
                # Auto-load vào panel
                Write-Log "⏳ Loading generated keys into form..." "Yellow"
                $success = Load-FromMidnightSigner
                
                if ($success) {
                    Write-Log "✓ Keys loaded successfully!" "Green"
                    Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Blue"
                    
                    [System.Windows.Forms.MessageBox]::Show(
                        "Keys generated and loaded successfully!",
                        "Success",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Information
                    )
                } else {
                    Write-Log "⚠ Keys generated but failed to load into form" "Orange"
                    Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Blue"
                }
                
            } else {
                Write-Log "✗ Key generation failed (exit code: $exitCode)" "SoftRed"
                Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Blue"
                
                [System.Windows.Forms.MessageBox]::Show(
                    "Key generation failed!`nPlease check the recovery phrase.",
                    "Error",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
            
        } catch {
            $btnEnterRecovery.Text = $originalText
            $btnEnterRecovery.Enabled = $true
            
            Write-Log "✗ Error running signer: $($_.Exception.Message)" "SoftRed"
            Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Blue"
        }
        
    }.GetNewClosure())
    $addrPanel.Controls.Add($btnEnterRecovery)

# Manual Button (bên cạnh Auto button)
$btnManualRecovery = New-Object System.Windows.Forms.Button
$btnManualRecovery.Location = New-Object System.Drawing.Point(580, 58)
$btnManualRecovery.Size = New-Object System.Drawing.Size(60, 24)
$btnManualRecovery.Text = "Manual"
$btnManualRecovery.BackColor = [System.Drawing.Color]::LightBlue
$btnManualRecovery.Add_Click({
    $recoveryText = $txtRecovery.Text.Trim()
    
    if ([string]::IsNullOrWhiteSpace($recoveryText)) { 
        [System.Windows.Forms.MessageBox]::Show(
            "Please enter your recovery phrase!",
            "Warning",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return 
    }
    
    # Validate recovery phrase (12, 15 hoặc 24 từ)
    $words = $recoveryText.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($words.Count -ne 12 -and $words.Count -ne 15 -and $words.Count -ne 24) {
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Recovery phrase should be 12, 15, or 24 words. You entered $($words.Count) words`n`nContinue anyway?",
            "Warning",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
            return
        }
    }
    
    Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Blue"
    Write-Log "🔧 Preparing Manual GUI..." "Yellow"
    
    # Tìm folder phraseX tiếp theo
    $phraseIndex = 1
    while (Test-Path (Join-Path $PSScriptRoot "phrase$phraseIndex")) {
        $phraseIndex++
    }
    
    $phraseFolder = Join-Path $PSScriptRoot "phrase$phraseIndex"
    
    try {
        # Tạo thư mục phraseX
        New-Item -Path $phraseFolder -ItemType Directory -Force | Out-Null
        Write-Log "✓ Created folder: phrase$phraseIndex" "Green"
        
        # Lưu phrase.prv vào thư mục phraseX
        $phraseFile = Join-Path $phraseFolder "phrase.prv"
        Set-Content -Path $phraseFile -Value $recoveryText -Force -Encoding UTF8
        Write-Log "✓ Saved phrase.prv to phrase$phraseIndex/" "Green"
        
    } catch {
        Write-Log "✗ Failed to create phrase folder: $($_.Exception.Message)" "SoftRed"
        return
    }
    
    # Kiểm tra script GUI tồn tại
    $guiScriptPath = Join-Path $PSScriptRoot "midnightsign_gui.ps1"
    if (-not (Test-Path $guiScriptPath)) {
        Write-Log "✗ midnightsign_gui.ps1 not found!" "SoftRed"
        [System.Windows.Forms.MessageBox]::Show(
            "midnightsign_gui.ps1 not found in script folder!",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return
    }
    
    Write-Log "⏳ Launching Manual GUI for phrase$phraseIndex..." "Yellow"
    
    try {
        # Chạy GUI script với working directory = phraseFolder
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$guiScriptPath`""
        $psi.WorkingDirectory = $phraseFolder  # Set working directory
        $psi.UseShellExecute = $true
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
        
        $process = [System.Diagnostics.Process]::Start($psi)
        
        Write-Log "✓ Manual GUI launched for phrase$phraseIndex" "Green"
        Write-Log "   (Waiting for user to complete operations...)" "Gray"
        
        # Đợi GUI window đóng
        $process.WaitForExit()
        
        Write-Log "✓ Manual GUI closed" "Green"
        Write-Log "⏳ Scanning for generated keys in phrase$phraseIndex/generated_keys..." "Yellow"
        
        # Đợi file system sync
        Start-Sleep -Milliseconds 1000
        
        # Tìm tất cả file delegated.addr trong generated_keys của phraseX
        $generatedKeysPath = Join-Path $phraseFolder "generated_keys"
        
        if (-not (Test-Path $generatedKeysPath)) {
            Write-Log "ℹ No generated_keys folder found in phrase$phraseIndex" "Gray"
            Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Blue"
            [System.Windows.Forms.MessageBox]::Show(
                "No keys were generated in phrase$phraseIndex folder.",
                "Info",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            return
        }
        
        $addrFiles = Get-ChildItem -Path $generatedKeysPath -Filter "delegated.addr" -File -Recurse | Sort-Object FullName
        
        if ($addrFiles.Count -eq 0) {
            Write-Log "ℹ No delegated.addr files found in phrase$phraseIndex/generated_keys" "Gray"
            Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Blue"
            [System.Windows.Forms.MessageBox]::Show(
                "No delegated.addr files found in phrase$phraseIndex/generated_keys.",
                "Info",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            return
        }
        
        Write-Log "✓ Found $($addrFiles.Count) address(es) in phrase$phraseIndex" "Green"
        
        # Tạo Selection Form
        $selectForm = New-Object System.Windows.Forms.Form
        $selectForm.Text = "Select Addresses from phrase$phraseIndex"
        $selectForm.Size = New-Object System.Drawing.Size(700, 500)
        $selectForm.StartPosition = "CenterScreen"
        $selectForm.FormBorderStyle = "FixedDialog"
        $selectForm.MaximizeBox = $false
        $selectForm.MinimizeBox = $false
        
        # Label hướng dẫn
        $lblInstruction = New-Object System.Windows.Forms.Label
        $lblInstruction.Location = New-Object System.Drawing.Point(10, 10)
        $lblInstruction.Size = New-Object System.Drawing.Size(670, 30)
        $lblInstruction.Text = "Select one or multiple addresses (Ctrl+Click or Shift+Click):"
        $lblInstruction.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $selectForm.Controls.Add($lblInstruction)
        
        # ListBox để hiển thị danh sách - CHO PHÉP CHỌN NHIỀU
        $listBox = New-Object System.Windows.Forms.ListBox
        $listBox.Location = New-Object System.Drawing.Point(10, 50)
        $listBox.Size = New-Object System.Drawing.Size(670, 350)
        $listBox.Font = New-Object System.Drawing.Font("Consolas", 9)
        $listBox.SelectionMode = [System.Windows.Forms.SelectionMode]::MultiExtended
        $selectForm.Controls.Add($listBox)
        
        # Thêm items vào ListBox
        $itemData = @()
        foreach ($addrFile in $addrFiles) {
            try {
                $addr = (Get-Content $addrFile.FullName -Raw -ErrorAction Stop).Trim()
                
                # Tìm file addr.skey trong cùng thư mục với delegated.addr
                $addrFolder = Split-Path $addrFile.FullName -Parent
                $skeyFile = Join-Path $addrFolder "addr.skey"
                $skeyExists = Test-Path $skeyFile
                
                # Lấy tên thư mục wallet (ví dụ: wallet_0)
                $walletName = Split-Path $addrFolder -Leaf
                
                # Hiển thị: [wallet_0] addr1q9...
                $displayText = "[$walletName] $addr"
                if (-not $skeyExists) {
                    $displayText += " [⚠ NO SKEY]"
                }
                
                $listBox.Items.Add($displayText) | Out-Null
                
                $itemData += @{
                    AddrFile = $addrFile.FullName
                    SkeyFile = $skeyFile
                    Address = $addr
                    HasSkey = $skeyExists
                    WalletName = $walletName
                }
            } catch {
                Write-Log "⚠ Failed to read $($addrFile.FullName): $($_.Exception.Message)" "Orange"
            }
        }
        
        if ($listBox.Items.Count -eq 0) {
            Write-Log "⚠ No valid addresses found" "Orange"
            Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Blue"
            $selectForm.Close()
            return
        }
        
        # Nút Load
        $btnLoad = New-Object System.Windows.Forms.Button
        $btnLoad.Location = New-Object System.Drawing.Point(10, 415)
        $btnLoad.Size = New-Object System.Drawing.Size(330, 40)
        $btnLoad.Text = "Load Selected"
        $btnLoad.BackColor = [System.Drawing.Color]::LightGreen
        $btnLoad.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $btnLoad.Add_Click({
            if ($listBox.SelectedIndices.Count -eq 0) {
                [System.Windows.Forms.MessageBox]::Show(
                    "Please select at least one address from the list.",
                    "Info",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
                return
            }
            
            # Lấy danh sách các item đã chọn
            $selectedItems = @()
            foreach ($index in $listBox.SelectedIndices) {
                $selectedItems += $itemData[$index]
            }
            
            # Kiểm tra nếu có item nào không có skey
            $itemsWithoutSkey = $selectedItems | Where-Object { -not $_.HasSkey }
            if ($itemsWithoutSkey.Count -gt 0) {
                $result = [System.Windows.Forms.MessageBox]::Show(
                    "$($itemsWithoutSkey.Count) address(es) do not have corresponding .skey file(s).`n`nContinue loading anyway?",
                    "Warning",
                    [System.Windows.Forms.MessageBoxButtons]::YesNo,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )
                if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
                    return
                }
            }
            
            Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Green"
            Write-Log "📥 Loading $($selectedItems.Count) address(es) from phrase$phraseIndex..." "Yellow"
            
            # Đảm bảo có đủ panels
            $neededPanels = $selectedItems.Count
            $currentPanels = $script:addressPanels.Count
            
            # Thêm panel nếu cần
            for ($i = $currentPanels; $i -lt $neededPanels; $i++) {
                Add-AddressPanel
                Write-Log "  ✓ Created panel #$($i + 1)" "Gray"
            }
            
            # Load từng address vào từng panel
            for ($i = 0; $i -lt $selectedItems.Count; $i++) {
                $item = $selectedItems[$i]
                $panel = $script:addressPanels[$i]
                
                $panel.TextBoxOriginal.Text = $item.Address
                
                if ($item.HasSkey) {
                    $panel.TextBoxSkey.Text = $item.SkeyFile
                    Write-Log "  ✓ Panel #$($i + 1): [$($item.WalletName)] $($item.Address.Substring(0,20))... + skey" "Green"
                } else {
                    $panel.TextBoxSkey.Text = ""
                    Write-Log "  ⚠ Panel #$($i + 1): [$($item.WalletName)] $($item.Address.Substring(0,20))... (no skey)" "Orange"
                }
            }
            
            Write-Log "✓ Loaded $($selectedItems.Count) address(es) successfully from phrase$phraseIndex!" "Green"
            Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Green"
            
            $selectForm.DialogResult = [System.Windows.Forms.DialogResult]::OK
            $selectForm.Close()
            
        }.GetNewClosure())
        $selectForm.Controls.Add($btnLoad)
        
        # Nút Cancel
        $btnCancel = New-Object System.Windows.Forms.Button
        $btnCancel.Location = New-Object System.Drawing.Point(350, 415)
        $btnCancel.Size = New-Object System.Drawing.Size(330, 40)
        $btnCancel.Text = "Cancel"
        $btnCancel.BackColor = [System.Drawing.Color]::LightGray
        $btnCancel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $btnCancel.Add_Click({
            $selectForm.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
            $selectForm.Close()
        })
        $selectForm.Controls.Add($btnCancel)
        
        # Double-click để load nhanh (nếu chỉ chọn 1)
        $listBox.Add_DoubleClick({
            if ($listBox.SelectedIndices.Count -eq 1) {
                $btnLoad.PerformClick()
            }
        }.GetNewClosure())
        
        # Hiển thị form
        $dialogResult = $selectForm.ShowDialog()
        
        if ($dialogResult -eq [System.Windows.Forms.DialogResult]::Cancel) {
            Write-Log "ℹ User cancelled selection" "Gray"
        }
        
        Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Blue"
        
    } catch {
        Write-Log "✗ Error: $($_.Exception.Message)" "SoftRed"
        Write-Log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" "Blue"
    }
    
}.GetNewClosure())
$addrPanel.Controls.Add($btnManualRecovery)

    # Solutions Label
    $lblSolutions = New-Object System.Windows.Forms.Label
    $lblSolutions.Location = New-Object System.Drawing.Point(40, 85)
    $lblSolutions.Size = New-Object System.Drawing.Size(500, 20)
    $lblSolutions.Text = "Solutions: Not checked"
    $lblSolutions.ForeColor = [System.Drawing.Color]::Gray
    $lblSolutions.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $addrPanel.Controls.Add($lblSolutions)

    # Drag & Drop for panel skey
    $txtPanelSkey.AllowDrop = $true
    $txtPanelSkey.Add_DragEnter({ param($s,$e) if ($e.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) { $e.Effect = [Windows.Forms.DragDropEffects]::Copy } })
    $txtPanelSkey.Add_DragDrop({
        param($s,$e)
        $files = $e.Data.GetData([Windows.Forms.DataFormats]::FileDrop)
        if ($files.Count -gt 0) {
            $f = $files[0]
            if (Test-Path $f -PathType Leaf) {
                $txtPanelSkey.Text = $f
                Write-Log "✓ Dropped key: $(Split-Path $f -Leaf)" "Green"
            }
        }
    }.GetNewClosure())

    # Add to tracking array
    $panelObj = @{
        Panel = $addrPanel
        TextBoxOriginal = $txtOriginal
        TextBoxSkey = $txtPanelSkey
        LabelSolutions = $lblSolutions
        ButtonCheck = $btnCheck
        ButtonExecute = $btnExecute
        ButtonRemove = $btnRemove
    }
    $script:addressPanels += $panelObj

    # Add to scrollable panel
    $addressContainer.Controls.Add($addrPanel)

    # Update add button position
    Update-AddButtonPosition
}

function Remove-AddressPanel {
    param($Panel)
    
    if ($null -eq $Panel) { return }

    if ($script:addressPanels -eq $null -or $script:addressPanels.Count -le 1) {
        [System.Windows.Forms.MessageBox]::Show("Must have at least 1 address!", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }

    try {
        if ($addressContainer.Controls.Contains($Panel)) { $addressContainer.Controls.Remove($Panel) }
    } catch {}

    # Rebuild the panels array excluding the removed panel and any invalid entries
    $script:addressPanels = @($script:addressPanels | Where-Object { $_ -and $_.Panel -and $_.Panel -ne $Panel })

    # Re-position remaining panels safely
    for ($i = 0; $i -lt $script:addressPanels.Count; $i++) {
        $entry = $script:addressPanels[$i]
        if ($null -eq $entry -or $null -eq $entry.Panel) { continue }
        try { $entry.Panel.Location = New-Object System.Drawing.Point(10, (10 + ($i * 120))) } catch {}
        if ($entry.Panel.Controls -and $entry.Panel.Controls.Count -gt 0) {
            try { $entry.Panel.Controls[0].Text = "#$($i + 1)" } catch {}
        }
    }

    Update-AddButtonPosition
}

function Update-AddButtonPosition {
    $lastY = 10
    if ($script:addressPanels.Count -gt 0) {
        $lastEntry = $script:addressPanels[-1]
        if ($null -ne $lastEntry -and $null -ne $lastEntry.Panel) {
            try {
                $lastY = $lastEntry.Panel.Location.Y + $lastEntry.Panel.Height + 10
            } catch { $lastY = 10 }
        }
    }

    try { $btnAddAddress.Location = New-Object System.Drawing.Point(10, $lastY) } catch {}
}

function Reset-AllAddresses {
    # Clear all panels except the first one
    while ($script:addressPanels.Count -gt 1) {
        $lastPanel = $script:addressPanels[-1].Panel
        Remove-AddressPanel -Panel $lastPanel
    }
    
    # Clear first panel
    if ($script:addressPanels.Count -gt 0) {
        $script:addressPanels[0].TextBoxOriginal.Text = ""
        $script:addressPanels[0].TextBoxSkey.Text = ""
        $script:addressPanels[0].LabelSolutions.Text = "Solutions: Not checked"
        $script:addressPanels[0].LabelSolutions.ForeColor = [System.Drawing.Color]::Gray
    }
    
    # Clear destination
    $txtDestination.Text = ""
    
    # Clear log
    $script:logBox.Clear()
    Write-Log "Reset completed" "Green"
    
    # Re-enable main buttons and reset per-panel buttons
    try {
        if ($btnBatchExecute -ne $null) {
            $btnBatchExecute.Enabled = $true
            $btnBatchExecute.Text = "Execute All"
        }
        if ($btnAddAddress -ne $null) {
            $btnAddAddress.Enabled = $true
        }
        foreach ($p in $script:addressPanels) {
            if ($p.ButtonExecute -ne $null) {
                $p.ButtonExecute.Enabled = $true
                $p.ButtonExecute.Text = "Execute"
                $p.ButtonExecute.BackColor = [System.Drawing.Color]::LightGreen
            }
            if ($p.ButtonCheck -ne $null) {
                $p.ButtonCheck.Enabled = $true
                $p.ButtonCheck.Text = "Check"
            }
        }
    } catch {
        # ignore UI re-enable errors
    }
}

# ============================================
# EXECUTION FUNCTIONS
# ============================================

function Execute-SingleAddress {
    param($Panel)
    
    $panelObj = $script:addressPanels | Where-Object { $_.Panel -eq $Panel } | Select-Object -First 1
    if (-not $panelObj) { return }
    
    $originalAddr = $panelObj.TextBoxOriginal.Text.Trim()
    $destAddr = $txtDestination.Text.Trim()
    $skeyPath = $panelObj.TextBoxSkey.Text.Trim()
    
    # Validation
    if ([string]::IsNullOrWhiteSpace($originalAddr)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter Original Address!", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($destAddr)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter Destination Address!", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($skeyPath)) {
        [System.Windows.Forms.MessageBox]::Show("Please select .skey file for this address!", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    # Get statistics
    Write-Log "================================================" "Blue"
    Write-Log "Checking wallet: $originalAddr" "Blue"
    $solutions = Get-Statistics -Address $originalAddr
    $panelObj.LabelSolutions.Text = "Solutions: $solutions"
    $panelObj.LabelSolutions.ForeColor = if ($solutions -gt 0) { [System.Drawing.Color]::Green } else { [System.Drawing.Color]::Red }
    
    Write-Log "Wallet has $solutions solutions" "Blue"
    Write-Log "Will transfer to: $destAddr" "Blue"
    
    # Confirmation
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Confirm transfer $solutions solutions from:`n$originalAddr`n`nTo:`n$destAddr`n`nAre you sure?",
        "Confirm Donation",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
        Write-Log "Operation cancelled" "Orange"
        return
    }
    
    # Execute
    $script:isExecuting = $true
    $panelObj.ButtonExecute.Enabled = $false
    $panelObj.ButtonExecute.Text = "Wait..."
    
    Write-Log "Creating signature..." "Yellow"
    $signature = Create-Signature -OriginalAddress $originalAddr -DestinationAddress $destAddr -SkeyPath $skeyPath
    
    if (-not $signature) {
        Write-Log "Cannot create signature!" "SoftRed"
        $script:isExecuting = $false
        $panelObj.ButtonExecute.Text = "Execute"
        $panelObj.ButtonExecute.Enabled = $true
        return
    }
    
    Write-Log "Signature created successfully" "Green"
    Write-Log "Sending donation request..." "Yellow"
    
    $response = Execute-Donation -OriginalAddress $originalAddr -DestinationAddress $destAddr -Signature $signature
    
    if ($response) {
        $logContent = Process-Response -Response $response -OriginalAddr $originalAddr -DestAddr $destAddr
        
        # Save individual log
        $logFile = "donation_single_$(Get-Date -Format 'yyyyMMddHHmmss').txt"
        $logContent | Out-File -FilePath $logFile -Encoding UTF8
        Write-Log "Detail log: $logFile" "Blue"
    }
    
    $script:isExecuting = $false
    $panelObj.ButtonExecute.Text = "Execute"
    $panelObj.ButtonExecute.Enabled = $true
    
    Write-Log "================================================" "Blue"
}

function Execute-BatchAddresses {
    $destAddr = $txtDestination.Text.Trim()
    
    # Validation
    if ([string]::IsNullOrWhiteSpace($destAddr)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter Destination Address!", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    # Get all valid addresses
    $validAddresses = @()
    foreach ($panelObj in $script:addressPanels) {
        $addr = $panelObj.TextBoxOriginal.Text.Trim()
        $skey = $panelObj.TextBoxSkey.Text.Trim()
        
        if (-not [string]::IsNullOrWhiteSpace($addr) -and -not [string]::IsNullOrWhiteSpace($skey)) {
            $validAddresses += @{
                Address = $addr
                SkeyPath = $skey
                Panel = $panelObj
            }
        }
    }
    
    if ($validAddresses.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No valid addresses with .skey files!", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    # Summary statistics
    Write-Log "================================================" "Blue"
    Write-Log "BATCH CHECK - Total: $($validAddresses.Count) addresses" "Blue"
    
    $totalSolutions = 0
    foreach ($item in $validAddresses) {
        $solutions = Get-Statistics -Address $item.Address
        $item.Solutions = $solutions
        $totalSolutions += $solutions
        
        $item.Panel.LabelSolutions.Text = "Solutions: $solutions"
        $item.Panel.LabelSolutions.ForeColor = if ($solutions -gt 0) { [System.Drawing.Color]::Green } else { [System.Drawing.Color]::Red }
        
        Write-Log "  - $($item.Address): $solutions solutions" "Blue"
    }
    
    Write-Log "TOTAL: $totalSolutions solutions" "Blue"
    Write-Log "Will transfer to: $destAddr" "Blue"
    
    # Confirmation
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Will transfer TOTAL $totalSolutions solutions from $($validAddresses.Count) wallets`n`nTo: $destAddr`n`nAre you sure?",
        "Confirm Batch Donation",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    if ($result -ne [System.Windows.Forms.DialogResult]::Yes) {
        Write-Log "Batch operation cancelled" "Orange"
        return
    }
    
    # Execute batch
    $script:isExecuting = $true
    $btnBatchExecute.Enabled = $false
    $btnBatchExecute.Text = "Processing..."
    
    $fullLog = ""
    $successCount = 0
    $failCount = 0
    
    for ($i = 0; $i -lt $validAddresses.Count; $i++) {
        $item = $validAddresses[$i]
        $addr = $item.Address
        
        Write-Log "`n================================================" "Yellow"
        Write-Log "Processing ($($i+1)/$($validAddresses.Count)): $addr" "Yellow"
        
        $item.Panel.ButtonExecute.Enabled = $false
        $item.Panel.ButtonExecute.Text = "Wait..."
        
        # Create signature
        Write-Log "Creating signature..." "Yellow"
        $signature = Create-Signature -OriginalAddress $addr -DestinationAddress $destAddr -SkeyPath $item.SkeyPath
        
        if (-not $signature) {
            Write-Log "Signature error for $addr" "SoftRed"
            $failCount++
            $item.Panel.ButtonExecute.Text = "Failed"
            $item.Panel.ButtonExecute.BackColor = [System.Drawing.Color]::LightCoral
            $item.Panel.ButtonExecute.Enabled = $true
            continue
        }
        
        Write-Log "Signature OK, sending..." "Green"
        
        # Execute donation
        $response = Execute-Donation -OriginalAddress $addr -DestinationAddress $destAddr -Signature $signature
        
        if ($response) {
            $logContent = Process-Response -Response $response -OriginalAddr $addr -DestAddr $destAddr
            $fullLog += $logContent
            
            if ($response.status -eq "success") {
                $successCount++
                $item.Panel.ButtonExecute.Text = "Done"
                $item.Panel.ButtonExecute.BackColor = [System.Drawing.Color]::LightGreen
            } else {
                $failCount++
                $item.Panel.ButtonExecute.Text = "Error"
                $item.Panel.ButtonExecute.BackColor = [System.Drawing.Color]::Yellow
            }
        } else {
            $failCount++
            $item.Panel.ButtonExecute.Text = "Failed"
            $item.Panel.ButtonExecute.BackColor = [System.Drawing.Color]::LightCoral
        }
        
        $item.Panel.ButtonExecute.Enabled = $true
        Start-Sleep -Milliseconds 500
    }
    
    Write-Log "`n================================================" "Green"
    Write-Log "BATCH EXECUTION COMPLETED" "Green"
    Write-Log "Success: $successCount | Failed: $failCount" "Green"
    
    # Save full log
    Save-FullLog -Content $fullLog
    
    $script:isExecuting = $false
    $btnBatchExecute.Text = "Execute All"
    $btnBatchExecute.Enabled = $true
    
    # Ask to continue
    Show-ContinueDialog
}

function Show-ContinueDialog {
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Completed! Do you want to:`n`n- RESET and continue?`n- Or EXIT program?",
        "Completed",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question,
        [System.Windows.Forms.MessageBoxDefaultButton]::Button1
    )
    
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        Reset-AllAddresses
        Write-Log "Ready for new session!" "Yellow"
    } else {
        $form.Close()
    }
}

# ============================================
# GUI SETUP
# ============================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Scavenger Donation Manager v4.1 - Enhanced"
$form.Size = New-Object System.Drawing.Size(1200, 700)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "Sizable"
$form.MaximizeBox = $true
$form.MinimumSize = New-Object System.Drawing.Size(1000, 600)

# ====== SPLIT CONTAINER (Main Layout) ======
$splitContainer = New-Object System.Windows.Forms.SplitContainer
$splitContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
$splitContainer.Orientation = [System.Windows.Forms.Orientation]::Vertical
$splitContainer.SplitterDistance = 800
$splitContainer.SplitterWidth = 5
$splitContainer.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$form.Controls.Add($splitContainer)

# ====== LEFT PANEL (Address Management) ======
$leftPanel = $splitContainer.Panel1

# Title Label
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Location = New-Object System.Drawing.Point(10, 10)
$lblTitle.Size = New-Object System.Drawing.Size(780, 30)
$lblTitle.Text = "ORIGINAL ADDRESSES MANAGEMENT"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblTitle.BackColor = [System.Drawing.Color]::LightSteelBlue
$lblTitle.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$leftPanel.Controls.Add($lblTitle)

# Scrollable Container for Addresses
$addressContainer = New-Object System.Windows.Forms.Panel
$addressContainer.Location = New-Object System.Drawing.Point(10, 50)
$addressContainer.Size = New-Object System.Drawing.Size(780, 350)
$addressContainer.AutoScroll = $true
$addressContainer.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$addressContainer.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$leftPanel.Controls.Add($addressContainer)

# Add Address Button
$btnAddAddress = New-Object System.Windows.Forms.Button
$btnAddAddress.Location = New-Object System.Drawing.Point(10, 10)
$btnAddAddress.Size = New-Object System.Drawing.Size(760, 35)
$btnAddAddress.Text = "+ Add Original Address"
$btnAddAddress.BackColor = [System.Drawing.Color]::LightGreen
$btnAddAddress.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnAddAddress.Add_Click({ Add-AddressPanel })
$addressContainer.Controls.Add($btnAddAddress)

# Bottom Panel for Destination and Batch Execute
$bottomPanel = New-Object System.Windows.Forms.Panel
$bottomPanel.Location = New-Object System.Drawing.Point(10, 410)
$bottomPanel.Size = New-Object System.Drawing.Size(780, 150)
$bottomPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$bottomPanel.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$leftPanel.Controls.Add($bottomPanel)

# Destination Address Section
$lblDestination = New-Object System.Windows.Forms.Label
$lblDestination.Location = New-Object System.Drawing.Point(10, 10)
$lblDestination.Size = New-Object System.Drawing.Size(150, 20)
$lblDestination.Text = "Destination Address:"
$lblDestination.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$bottomPanel.Controls.Add($lblDestination)

$txtDestination = New-Object System.Windows.Forms.TextBox
$txtDestination.Location = New-Object System.Drawing.Point(10, 35)
$txtDestination.Size = New-Object System.Drawing.Size(760, 25)
$txtDestination.Font = New-Object System.Drawing.Font("Consolas", 9)
$txtDestination.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$bottomPanel.Controls.Add($txtDestination)

# Batch Execute Button
$btnBatchExecute = New-Object System.Windows.Forms.Button
$btnBatchExecute.Location = New-Object System.Drawing.Point(10, 75)
$btnBatchExecute.Size = New-Object System.Drawing.Size(760, 60)
$btnBatchExecute.Text = "Execute All (Batch Mode)"
$btnBatchExecute.BackColor = [System.Drawing.Color]::Orange
$btnBatchExecute.ForeColor = [System.Drawing.Color]::White
$btnBatchExecute.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$btnBatchExecute.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$btnBatchExecute.Add_Click({ Execute-BatchAddresses })
$bottomPanel.Controls.Add($btnBatchExecute)

# ====== RIGHT PANEL (Log Display) ======
$rightPanel = $splitContainer.Panel2

# Log Title
$lblLog = New-Object System.Windows.Forms.Label
$lblLog.Dock = [System.Windows.Forms.DockStyle]::Top
$lblLog.Height = 40
$lblLog.Text = "EXECUTION LOG"
$lblLog.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblLog.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblLog.BackColor = [System.Drawing.Color]::LightYellow
$rightPanel.Controls.Add($lblLog)

# Button Panel at Bottom
$logButtonPanel = New-Object System.Windows.Forms.Panel
$logButtonPanel.Dock = [System.Windows.Forms.DockStyle]::Bottom
$logButtonPanel.Height = 50
$rightPanel.Controls.Add($logButtonPanel)

# Clear Log Button
$btnClearLog = New-Object System.Windows.Forms.Button
$btnClearLog.Location = New-Object System.Drawing.Point(10, 5)
$btnClearLog.Size = New-Object System.Drawing.Size(165, 40)
$btnClearLog.Text = "Clear Log"
$btnClearLog.BackColor = [System.Drawing.Color]::LightGray
$btnClearLog.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnClearLog.Add_Click({
    $script:logBox.Clear()
    Write-Log "Log cleared" "Green"
})
$logButtonPanel.Controls.Add($btnClearLog)

# Reset Button
$btnReset = New-Object System.Windows.Forms.Button
$btnReset.Location = New-Object System.Drawing.Point(185, 5)
$btnReset.Size = New-Object System.Drawing.Size(165, 40)
$btnReset.Text = "Reset All"
$btnReset.BackColor = [System.Drawing.Color]::LightCoral
$btnReset.ForeColor = [System.Drawing.Color]::White
$btnReset.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnReset.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show(
        "Reset all addresses and log?",
        "Confirm Reset",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    
    if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
        Reset-AllAddresses
    }
})
$logButtonPanel.Controls.Add($btnReset)

# Auto-fill button: populate first panel from addr.delegated and addr.skey
$btnAutoFill = New-Object System.Windows.Forms.Button
$btnAutoFill.Location = New-Object System.Drawing.Point(360, 5)
$btnAutoFill.Size = New-Object System.Drawing.Size(165, 40)
$btnAutoFill.Text = "Auto-fill From Signer"
$btnAutoFill.BackColor = [System.Drawing.Color]::LightSkyBlue
$btnAutoFill.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$btnAutoFill.Add_Click({
    $ok = Load-FromMidnightSigner
    if (-not $ok) {
        [System.Windows.Forms.MessageBox]::Show("Auto-fill failed. Ensure 'addr.delegated' exists in the script folder.", "Auto-fill", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
    }
}.GetNewClosure())
$logButtonPanel.Controls.Add($btnAutoFill)

# Log RichTextBox (Fill remaining space) - supports per-line color
$script:logBox = New-Object System.Windows.Forms.RichTextBox
$script:logBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$script:logBox.Font = New-Object System.Drawing.Font("Consolas", 9)
$script:logBox.ReadOnly = $true
$script:logBox.Multiline = $true
$script:logBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
$script:logBox.BackColor = [System.Drawing.Color]::FromArgb(11,15,19)
$script:logBox.ForeColor = [System.Drawing.Color]::FromArgb(230,238,240)
$script:logBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$script:logBox.HideSelection = $false
$rightPanel.Controls.Add($script:logBox)

# ============================================
# INITIALIZATION
# ============================================

# Add first address panel
Add-AddressPanel

# Welcome message
Write-Log "================================================" "Blue"
Write-Log "SCAVENGER DONATION MANAGER v4.1 - ENHANCED" "Blue"
Write-Log "================================================" "Blue"
Write-Log "KEY FEATURES:" "Purple"
Write-Log "  ✓ Single origin address donation" "Blue"
Write-Log "  ✓ Multi origin address donation" "Purple"
Write-Log "  ✓ Auto sign and execute" "Green"
Write-Log "  ✓ Recovery phrase support" "Green"
Write-Log "================================================" "Blue"
Write-Log "Instructions:" "Gray"
Write-Log "  1. Enter Original Address(es)" "Gray"
Write-Log "  2. Load .skey file for EACH address" "Gray"
Write-Log "  3. Enter Destination Address" "Gray"
Write-Log "  4. Choose Execute single OR Execute All" "Gray"
Write-Log "================================================" "Blue"
Write-Log "Ready!" "Blue"

# Show form
[void]$form.ShowDialog()
