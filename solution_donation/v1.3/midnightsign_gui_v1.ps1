Add-Type -AssemblyName PresentationFramework

# === FIX WORKING DIRECTORY ===
if ($PSCommandPath) {
    $ScriptDir = Split-Path -Parent $PSCommandPath
} else {
    $ScriptDir = Get-Location
}


# === GUI WINDOW ===
$window = New-Object System.Windows.Window
$window.Title = "Midnight Sign - Multi Address Tool"
$window.Width = 650
$window.Height = 580
$window.WindowStartupLocation = "CenterScreen"
$window.ResizeMode = "CanResize"


# === DUAL INPUT POPUP ===
function Show-DualInputPopup($title, $message) {
    $inputWindow = New-Object System.Windows.Window
    $inputWindow.Title = $title
    $inputWindow.Width = 400
    $inputWindow.Height = 260
    $inputWindow.WindowStartupLocation = "CenterOwner"
    $inputWindow.ResizeMode = "NoResize"
    $inputWindow.Owner = $window

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = "10"
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))

    # Message label
    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text = $message
    $lbl.Margin = "5"
    $lbl.FontSize = 14
    $grid.AddChild($lbl)
    [System.Windows.Controls.Grid]::SetRow($lbl, 0)

    # External input
    $lblExternal = New-Object System.Windows.Controls.TextBlock
    $lblExternal.Text = "Số lượng External (0/$i):"
    $lblExternal.Margin = "5,10,5,2"
    $lblExternal.FontSize = 13
    $grid.AddChild($lblExternal)
    [System.Windows.Controls.Grid]::SetRow($lblExternal, 1)

    $txtExternal = New-Object System.Windows.Controls.TextBox
    $txtExternal.Margin = "5,2,5,5"
    $txtExternal.FontSize = 16
    $txtExternal.Text = "0"
    $grid.AddChild($txtExternal)
    [System.Windows.Controls.Grid]::SetRow($txtExternal, 2)

    # Internal input
    $lblInternal = New-Object System.Windows.Controls.TextBlock
    $lblInternal.Text = "Số lượng Internal (1/$i):"
    $lblInternal.Margin = "5,10,5,2"
    $lblInternal.FontSize = 13
    $grid.AddChild($lblInternal)
    [System.Windows.Controls.Grid]::SetRow($lblInternal, 3)

    $txtInternal = New-Object System.Windows.Controls.TextBox
    $txtInternal.Margin = "5,2,5,5"
    $txtInternal.FontSize = 16
    $txtInternal.Text = "0"
    $grid.AddChild($txtInternal)
    [System.Windows.Controls.Grid]::SetRow($txtInternal, 4)

    # OK button
    $btnPanel = New-Object System.Windows.Controls.StackPanel
    $btnPanel.Orientation = "Horizontal"
    $btnPanel.HorizontalAlignment = "Center"
    $btnPanel.Margin = "5,10,5,5"
    
    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = "OK"
    $btn.FontSize = 16
    $btn.Width = 120
    $btn.Height = 35
    $btnPanel.AddChild($btn)

    $grid.AddChild($btnPanel)
    [System.Windows.Controls.Grid]::SetRow($btnPanel, 5)

    $btn.Add_Click({
        $extVal = $txtExternal.Text.Trim()
        $intVal = $txtInternal.Text.Trim()
        
        if ($extVal -match '^\d+$' -and $intVal -match '^\d+$') {
            $extNum = [int]$extVal
            $intNum = [int]$intVal
            
            if ($extNum -eq 0 -and $intNum -eq 0) {
                [System.Windows.MessageBox]::Show("Ít nhất một trong hai phải lớn hơn 0!", "Lỗi", "OK", "Error")
                return
            }
            
            $inputWindow.Tag = @{
                External = $extNum
                Internal = $intNum
            }
            $inputWindow.Close()
        } else {
            [System.Windows.MessageBox]::Show("Hãy nhập số hợp lệ cho cả hai trường!", "Lỗi", "OK", "Error")
        }
    })

    $inputWindow.Content = $grid
    $inputWindow.ShowDialog() | Out-Null

    return $inputWindow.Tag
}


# === MAIN GRID ===
$grid = New-Object System.Windows.Controls.Grid
$window.Content = $grid

$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
$grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))


# === RUN SCRIPT BUTTON ===
$btnMulti = New-Object System.Windows.Controls.Button
$btnMulti.Content = "▶ Run Multi-Address Script"
$btnMulti.Margin = "10"
$btnMulti.Height = 45
$btnMulti.FontSize = 18
$grid.AddChild($btnMulti)
[System.Windows.Controls.Grid]::SetRow($btnMulti, 0)


# === LOG TEXTBOX ===
$logBox = New-Object System.Windows.Controls.TextBox
$logBox.Margin = "10"
$logBox.FontSize = 14
$logBox.VerticalScrollBarVisibility = "Visible"
$logBox.AcceptsReturn = $true
$logBox.IsReadOnly = $true
$grid.AddChild($logBox)
[System.Windows.Controls.Grid]::SetRow($logBox, 1)


# === PROCESS EXECUTION ===
function Invoke-ScriptWithLog($scriptFile, $externalCount, $internalCount) {
    $logBox.AppendText("▶ Running script:`n$scriptFile`nExternal: $externalCount | Internal: $internalCount`n`n")

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptFile`" -External $externalCount -Internal $internalCount"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $psi

    $process.add_OutputDataReceived({
        param($sender, $e)
        if ($e.Data) {
            $logBox.Dispatcher.Invoke([action]{
                $logBox.AppendText($e.Data + "`n")
                $logBox.ScrollToEnd()
            })
        }
    })
    $process.add_ErrorDataReceived({
        param($sender, $e)
        if ($e.Data) {
            $logBox.Dispatcher.Invoke([action]{
                $logBox.AppendText("ERROR: " + $e.Data + "`n")
                $logBox.ScrollToEnd()
            })
        }
    })

    $process.Start() | Out-Null
    $process.BeginOutputReadLine()
    $process.BeginErrorReadLine()
}


# === BUTTON EVENT ===
$btnMulti.Add_Click({
    $result = Show-DualInputPopup "Nhập số lượng address" "Nhập số lượng address External và Internal:"
    if ($result) {
        Invoke-ScriptWithLog "$ScriptDir\midnightsigninformulti_v1.ps1" $result.External $result.Internal

        # Background job to create summary
        Start-Job -ScriptBlock {
            param($scriptDir)
            try {
                Start-Sleep -Seconds 1

                $found = @()
                foreach ($g in Get-ChildItem -Path $scriptDir -Directory -ErrorAction SilentlyContinue) {
                    $summaryFile = Join-Path $g.FullName 'delegated_summary.txt'
                    if (Test-Path $summaryFile) {
                        try {
                            $lines = Get-Content -Path $summaryFile -ErrorAction Stop
                        } catch { continue }

                        foreach ($ln in $lines) {
                            if ([string]::IsNullOrWhiteSpace($ln)) { continue }
                            $parts = $ln -split '\|'
                            if ($parts.Count -ge 2) {
                                $walletFolder = $parts[0]
                                $addr = $parts[1]
                                $delegatedPath = Join-Path $g.FullName (Join-Path 'generated_keys' (Join-Path $walletFolder 'delegated.addr'))
                                $found += [pscustomobject]@{ File = $delegatedPath; Wallet = $walletFolder; Address = $addr }
                            }
                        }
                        continue
                    }

                    $logPath = Join-Path $g.FullName 'generation.log'
                    if (-not (Test-Path $logPath)) { continue }
                    try {
                        $lines = Get-Content -Path $logPath -ErrorAction Stop
                    } catch { continue }

                    foreach ($ln in $lines) {
                        if ($ln -match '^(?:\[.*?\]\s*)?(?:✓\s*)?Created\s+wallet_(\d+)/\s*\(delegated:\s*([^,\)]+),\s*skey:\s*([^\)]+)\)') {
                            $idx = $matches[1]
                            $addr = $matches[2].Trim()
                            $walletFolder = "wallet_$idx"
                            $delegatedPath = Join-Path $g.FullName (Join-Path 'generated_keys' (Join-Path $walletFolder 'delegated.addr'))

                            if (Test-Path $delegatedPath) {
                                try { $fileAddr = (Get-Content -Path $delegatedPath -ErrorAction Stop).Trim(); if ($fileAddr) { $addr = $fileAddr } } catch {}
                            }

                            $found += [pscustomobject]@{ File = $delegatedPath; Wallet = $walletFolder; Address = $addr }
                        }
                    }
                }

                if ($found.Count -gt 0) {
                    $outFile = Join-Path $scriptDir 'delegated_temp.txt'
                    $lines = $found | ForEach-Object { "$($_.File)|$($_.Wallet)|$($_.Address)" }
                    $lines | Out-File -FilePath $outFile -Encoding UTF8 -Force

                    $found | ForEach-Object { $_.Address } | Set-Content -Path (Join-Path $env:TEMP 'delegated_clip.txt') -Encoding UTF8
                    Get-Content (Join-Path $env:TEMP 'delegated_clip.txt') | clip
                }
            } catch {}
        } -ArgumentList $ScriptDir | Out-Null
    }
})

# START
$window.ShowDialog() | Out-Null