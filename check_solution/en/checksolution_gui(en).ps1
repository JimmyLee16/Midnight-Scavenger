Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --------- THEME ------------
$primaryColor   = [System.Drawing.Color]::FromArgb(0, 120, 215)
$bgColor        = [System.Drawing.Color]::FromArgb(245, 247, 250)
$panelColor     = [System.Drawing.Color]::FromArgb(255, 255, 255)
$textColor      = [System.Drawing.Color]::FromArgb(45, 45, 48)
$accentColor    = [System.Drawing.Color]::FromArgb(0, 153, 188)
$fontMain       = New-Object System.Drawing.Font("Segoe UI", 10)

# --------- LANGUAGE DATA ------------
$Lang = "EN"  # default language

$Text = @{
    EN = @{
        Title = "Crypto Receipts Checker"
        DropHint = "Drag your CSV file here or click to select"
        FileInfo = ""
        ManualInput = "Or manually enter addresses (one per line):"
        StartButton = "🚀 START CHECKING"
        Ready = "Ready to check!"
        CSVError = "CSV file must contain a column named 'Address'!"
        NoAddress = "No addresses found!"
        SelectCSV = "Please select a CSV file!"
        CompletedTitle = "Completed"
        CompletedMsg = @"
✅ Completed!

📊 Total addresses checked: {0}
💰 Total Solutions: {1}
🌙 Total Night (estimated): {2:N2}
🪙 Active wallets on network: {3}
🎯 Remaining challenges: {4}
📈 Your contribution: {5:N6} % of total network

📁 Result file:
{6}

Would you like to open the file?
"@
        BtnYes = "Yes"
        BtnNo  = "No"
        BtnLang = "🌐 Language"
        LangSwitch = "Switched to Vietnamese 🇻🇳"
    }
    VN = @{
        Title = "Công Cụ Kiểm Tra Crypto Receipts"
        DropHint = "Kéo file CSV vào đây hoặc click để chọn"
        FileInfo = ""
        ManualInput = "Hoặc nhập địa chỉ thủ công (mỗi dòng 1 địa chỉ):"
        StartButton = "🚀 BẮT ĐẦU KIỂM TRA"
        Ready = "Sẵn sàng kiểm tra!"
        CSVError = "File CSV phải có cột 'Address'!"
        NoAddress = "Chưa có địa chỉ nào!"
        SelectCSV = "Vui lòng chọn file CSV!"
        CompletedTitle = "Hoàn thành"
        CompletedMsg = @"
✅ Hoàn thành!

📊 Tổng địa chỉ: {0}
💰 Tổng Solution: {1}
🌙 Tổng Night tạm tính: {2:N2}
🪙 Số ví tham gia toàn mạng: {3}
🎯 Cơ hội còn lại: {4}
📈 Đóng góp của bạn: {5:N6} % tổng mạng

📁 File kết quả:
{6}

Bạn có muốn mở file không?
"@
        BtnYes = "Có"
        BtnNo  = "Không"
        BtnLang = "🌐 Ngôn ngữ"
        LangSwitch = "Đã chuyển sang tiếng Anh 🇬🇧"
    }
}

# --------- MAIN FORM ------------
$form = New-Object System.Windows.Forms.Form
$form.Text = $Text[$Lang].Title
$form.Size = New-Object System.Drawing.Size(720, 650)
$form.StartPosition = "CenterScreen"
$form.BackColor = $bgColor
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

# --------- TITLE ------------
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 18)
$lblTitle.ForeColor = $textColor
$lblTitle.TextAlign = 'MiddleCenter'
$lblTitle.Size = New-Object System.Drawing.Size(700, 40)
$lblTitle.Location = New-Object System.Drawing.Point(10, 20)
$form.Controls.Add($lblTitle)

# --------- LANGUAGE BUTTON ------------
$btnLang = New-Object System.Windows.Forms.Button
$btnLang.Text = $Text[$Lang].BtnLang
$btnLang.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnLang.Size = New-Object System.Drawing.Size(120, 30)
$btnLang.Location = New-Object System.Drawing.Point(580, 20)
$btnLang.BackColor = [System.Drawing.Color]::White
$btnLang.ForeColor = $textColor
$btnLang.FlatStyle = 'Flat'
$btnLang.FlatAppearance.BorderSize = 1
$btnLang.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnLang)

# --------- CSV PANEL ------------
$panelDrop = New-Object System.Windows.Forms.Panel
$panelDrop.Size = New-Object System.Drawing.Size(620, 160)
$panelDrop.Location = New-Object System.Drawing.Point(50, 80)
$panelDrop.BackColor = $panelColor
$panelDrop.BorderStyle = 'FixedSingle'
$panelDrop.AllowDrop = $true
$form.Controls.Add($panelDrop)

$lblIcon = New-Object System.Windows.Forms.Label
$lblIcon.Text = "📂"
$lblIcon.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 52)
$lblIcon.Location = New-Object System.Drawing.Point(265, 10)
$lblIcon.Size = New-Object System.Drawing.Size(90, 80)
$lblIcon.TextAlign = 'MiddleCenter'
$panelDrop.Controls.Add($lblIcon)

$lblDrop = New-Object System.Windows.Forms.Label
$lblDrop.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$lblDrop.ForeColor = [System.Drawing.Color]::Gray
$lblDrop.TextAlign = 'MiddleCenter'
$lblDrop.Size = New-Object System.Drawing.Size(620, 40)
$lblDrop.Location = New-Object System.Drawing.Point(0, 100)
$panelDrop.Controls.Add($lblDrop)

# --------- FILE INFO ------------
$lblFileInfo = New-Object System.Windows.Forms.Label
$lblFileInfo.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
$lblFileInfo.ForeColor = $accentColor
$lblFileInfo.Size = New-Object System.Drawing.Size(620, 50)
$lblFileInfo.TextAlign = 'MiddleCenter'
$lblFileInfo.Location = New-Object System.Drawing.Point(50, 250)
$form.Controls.Add($lblFileInfo)

# --------- MANUAL INPUT ------------
$lblManual = New-Object System.Windows.Forms.Label
$lblManual.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
$lblManual.Location = New-Object System.Drawing.Point(50, 310)
$form.Controls.Add($lblManual)

$txtManual = New-Object System.Windows.Forms.TextBox
$txtManual.Multiline = $true
$txtManual.ScrollBars = 'Vertical'
$txtManual.Font = New-Object System.Drawing.Font("Consolas", 10)
$txtManual.Size = New-Object System.Drawing.Size(620, 120)
$txtManual.Location = New-Object System.Drawing.Point(50, 335)
$txtManual.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($txtManual)

# --------- PROGRESS ------------
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Size = New-Object System.Drawing.Size(620, 25)
$progressBar.Location = New-Object System.Drawing.Point(50, 475)
$progressBar.Style = 'Continuous'
$progressBar.Visible = $false
$form.Controls.Add($progressBar)

$lblProgress = New-Object System.Windows.Forms.Label
$lblProgress.Font = $fontMain
$lblProgress.ForeColor = $textColor
$lblProgress.Size = New-Object System.Drawing.Size(620, 25)
$lblProgress.Location = New-Object System.Drawing.Point(50, 505)
$lblProgress.TextAlign = 'MiddleCenter'
$lblProgress.Visible = $false
$form.Controls.Add($lblProgress)

# --------- START BUTTON ------------
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12)
$btnStart.Size = New-Object System.Drawing.Size(300, 50)
$btnStart.Location = New-Object System.Drawing.Point(210, 540)
$btnStart.BackColor = $primaryColor
$btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.FlatStyle = 'Flat'
$btnStart.FlatAppearance.BorderSize = 0
$btnStart.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnStart)
$btnStart.Add_MouseEnter({ $btnStart.BackColor = [System.Drawing.Color]::FromArgb(0, 90, 190) })
$btnStart.Add_MouseLeave({ $btnStart.BackColor = $primaryColor })

# --------- UPDATE LANGUAGE FUNCTION ------------
function Update-Language {
    $form.Text = $Text[$Lang].Title
    $lblTitle.Text = $Text[$Lang].Title
    $lblDrop.Text = $Text[$Lang].DropHint
    $lblManual.Text = $Text[$Lang].ManualInput
    $btnStart.Text = $Text[$Lang].StartButton
    $btnLang.Text = $Text[$Lang].BtnLang
}

Update-Language

# --------- LANGUAGE SWITCH EVENT ------------
$btnLang.Add_Click({
    if ($Lang -eq "EN") { $Lang = "VN" } else { $Lang = "EN" }
    Update-Language
    [System.Windows.Forms.MessageBox]::Show($Text[$Lang].LangSwitch, "Info", "OK", "Information")
})

# --------- CSV EVENTS ------------
$panelDrop.Add_DragEnter({
    if ($_.Data.GetDataPresent([Windows.Forms.DataFormats]::FileDrop)) {
        $_.Effect = [Windows.Forms.DragDropEffects]::Copy
        $panelDrop.BackColor = [System.Drawing.Color]::FromArgb(240, 248, 255)
    }
})
$panelDrop.Add_DragLeave({ $panelDrop.BackColor = $panelColor })
$panelDrop.Add_DragDrop({
    $panelDrop.BackColor = $panelColor
    $files = $_.Data.GetData([Windows.Forms.DataFormats]::FileDrop)
    if ($files.Length -gt 0) {
        $file = $files[0]
        if ($file -match '\.csv$') { ProcessCSV $file }
        else { [System.Windows.Forms.MessageBox]::Show($Text[$Lang].SelectCSV, "Error", "OK", "Error") }
    }
})
$panelDrop.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "CSV files (*.csv)|*.csv"
    if ($dlg.ShowDialog() -eq "OK") { ProcessCSV $dlg.FileName }
})

# --------- CSV PROCESS ------------
function ProcessCSV($file) {
    try {
        $csv = Import-Csv $file
        if (-not $csv[0].PSObject.Properties.Name -contains "Address") {
            [System.Windows.Forms.MessageBox]::Show($Text[$Lang].CSVError, "Error", "OK", "Error")
            return
        }
        $global:addresses = $csv | Select-Object -ExpandProperty Address | ForEach-Object { $_.Trim() }
        $global:csvPath = $file
        $lblFileInfo.Text = "✅ " + $(if ($Lang -eq "EN") {"Selected:"} else {"Đã chọn:"}) + " $(Split-Path $file -Leaf)`n📊 $($global:addresses.Count) " + $(if ($Lang -eq "EN") {"addresses loaded"} else {"địa chỉ"})
        $lblIcon.Text = "✅"
        $lblDrop.Text = $Text[$Lang].Ready
        $lblDrop.ForeColor = $accentColor
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error reading file: $_", "Error", "OK", "Error")
    }
}

# --------- CHECK BUTTON CLICK ------------
$btnStart.Add_Click({
    $manual = $txtManual.Text -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    $addresses = @()
    if ($global:addresses.Count -gt 0) { $addresses += $global:addresses }
    if ($manual.Count -gt 0) { $addresses += $manual }

    if ($addresses.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show($Text[$Lang].NoAddress, "Warning", "OK", "Warning")
        return
    }

    $btnStart.Enabled = $false
    $progressBar.Visible = $true
    $lblProgress.Visible = $true
    $progressBar.Value = 0

    $totalReceipts = 0
    $totalNight = 0
    $rows = @()
    $count = $addresses.Count
    $wallets = 0
    $remain = 0
    $globalTotal = 0

    for ($i = 0; $i -lt $count; $i++) {
        $a = $addresses[$i]
        $progressBar.Value = [int](($i + 1) / $count * 100)
        $lblProgress.Text = "🔍 $($i+1)/$count - $a"
        $form.Refresh()
        try {
            $url = "https://scavenger.prod.gd.midnighttge.io/statistics/$a"
            $r = Invoke-RestMethod -Uri $url -UseBasicParsing -TimeoutSec 10
            $crypto = [int]$r.local.crypto_receipts
            $night = [math]::Round(($r.local.night_allocation / 1000000), 2)
            $wallets = $r.global.wallets
            $remain = $r.global.total_challenges - $r.global.challenges
            $globalTotal = $r.global.total_crypto_receipts
        } catch {
            $crypto = 0
            $night = 0
        }

        $totalReceipts += $crypto
        $totalNight += $night
        $rows += [PSCustomObject]@{
            Address         = $a
            CryptoReceipts  = $crypto
            NightAllocation = $night
        }
        Start-Sleep -Milliseconds 400
    }

    $output = Join-Path (Split-Path $global:csvPath -Parent) ("crypto_results_{0:yyyyMMdd_HHmmss}.csv" -f (Get-Date))
    $rows | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $output
    $progressBar.Visible = $false
    $lblProgress.Visible = $false

    if ($globalTotal -gt 0) {
        $ratio = [math]::Round(($totalReceipts / $globalTotal) * 100, 6)
    } else {
        $ratio = 0
    }

    $msg = [string]::Format($Text[$Lang].CompletedMsg, $count, $totalReceipts, $totalNight, $wallets, $remain, $ratio, $output)

    $res = [System.Windows.Forms.MessageBox]::Show($msg, $Text[$Lang].CompletedTitle, "YesNo", "Information")
    if ($res -eq "Yes") { Start-Process $output }
    $btnStart.Enabled = $true
})

# --------- SHOW FORM ------------
$form.ShowDialog() | Out-Null
