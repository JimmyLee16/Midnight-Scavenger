Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --------- THEME CONFIGURATION ---------
$primaryColor   = [System.Drawing.Color]::FromArgb(25, 135, 255)
$bgColor        = [System.Drawing.Color]::FromArgb(245, 247, 250)
$panelColor     = [System.Drawing.Color]::FromArgb(255, 255, 255)
$textColor      = [System.Drawing.Color]::FromArgb(45, 45, 48)
$accentColor    = [System.Drawing.Color]::FromArgb(0, 153, 188)
$warningColor   = [System.Drawing.Color]::FromArgb(255, 140, 0)
$errorColor     = [System.Drawing.Color]::FromArgb(220, 53, 69)
$successColor   = [System.Drawing.Color]::FromArgb(40, 167, 69)
$fontMain       = New-Object System.Drawing.Font("Segoe UI", 10)

# --------- LANGUAGE DATA ---------
$Lang = "EN"

$Text = @{
    EN = @{
        Title = "🌙 NIGHT Thaw Schedule Checker"
        AddressHint = "Enter your Cardano address here"
        CheckButton = "🔍 CHECK SCHEDULE"
        ScheduleTitle = "📋 NIGHT THAW SCHEDULE"
        NotFound = "⚠️ No thaw schedule found for this address."
        InvalidAddress = "❌ Invalid address. Please enter a valid Cardano address."
        ApiError = "❌ API Error or invalid address.`nDetails: {0}"
        ThawNo = "📌 Batch {0}: {1:N0} NIGHT"
        ThawTime = "⏰ {0}"
        TotalLabel = "💰 Total: {0:N0} NIGHT"
        BatchLabel = "📦 Batches: {0}"
        CopyButton = "📋 Copy Results"
        ClearButton = "🗑️ Clear"
        SaveButton = "💾 Save Address"
        HistoryButton = "📖 View History"
        BtnLang = "🌐 Language"
        LangSwitch = "Switched to Vietnamese 🇻🇳"
        Loading = "🔄 Checking..."
        Success = "✅ Schedule retrieved successfully!"
        SavePrompt = "Do you want to save this result to a JSON file?"
        SaveSuccess = "✅ Saved to: {0}"
        SaveError = "❌ Error saving file: {0}"
        ViewAllButton = "📊 View All"
        GoingTo = "Going to schedule..."
    }
    VN = @{
        Title = "🌙 Kiểm Tra Lịch Trả NIGHT"
        AddressHint = "Nhập địa chỉ Cardano của bạn tại đây"
        CheckButton = "🔍 KIỂM TRA LỊCH"
        ScheduleTitle = "📋 LỊCH TRẢ NIGHT"
        NotFound = "⚠️ Không tìm thấy lịch trả NIGHT cho địa chỉ này."
        InvalidAddress = "❌ Địa chỉ không hợp lệ. Vui lòng nhập địa chỉ Cardano hợp lệ."
        ApiError = "❌ Lỗi API hoặc địa chỉ không hợp lệ.`nChitiết: {0}"
        ThawNo = "📌 Đợt {0}: {1:N0} NIGHT"
        ThawTime = "⏰ {0}"
        TotalLabel = "💰 Tổng cộng: {0:N0} NIGHT"
        BatchLabel = "📦 Số đợt: {0}"
        CopyButton = "📋 Sao chép"
        ClearButton = "🗑️ Xóa"
        SaveButton = "💾 Lưu XLSX"
        HistoryButton = "📖 Xem Lịch"
        BtnLang = "🌐 Ngôn ngữ"
        LangSwitch = "Đã chuyển sang tiếng Anh 🇬🇧"
        Loading = "🔄 Đang kiểm tra..."
        Success = "✅ Lấy lịch thành công!"
        SavePrompt = "Bạn có muốn lưu kết quả này vào file JSON không?"
        SaveSuccess = "✅ Đã lưu vào: {0}"
        SaveError = "❌ Lỗi khi lưu file: {0}"
        ViewAllButton = "📊 Xem Tất Cả"
        GoingTo = "Đang thực hiện yêu cầu..."
    }
}

# --------- TRADEMARK / ATTRIBUTION ---------
$TrademarkFull = @{
    EN = "This product is made for community use.`nAuthor: Jimmy Lee`nSource: https://github.com/JimmyLee16/Midnight-Scavenger/tree/main/Night_claim_management`nContact: https://t.me/ADA_VIET"
    VN = "Đây là sản phẩm làm vì mục đích phục vụ cộng đồng.`nTác giả: Jimmy Lee`nSource: https://github.com/JimmyLee16/Midnight-Scavenger/tree/main/Night_claim_management`nLiên hệ: https://t.me/ADA_VIET"
}

$TrademarkShort = @{
    EN = "© Jimmy Lee — community tool"
    VN = "© Jimmy Lee — công cụ cộng đồng"
}

# --------- GLOBAL VARIABLES ---------
$global:currentScheduleData = $null
$global:currentAddress = ""
$global:excelFilePath = ""

# --------- MAIN FORM ---------
$form = New-Object System.Windows.Forms.Form
$form.Text = $Text[$Lang].Title
$form.Size = New-Object System.Drawing.Size(900, 700)
$form.StartPosition = "CenterScreen"
$form.BackColor = $bgColor
$form.FormBorderStyle = 'Sizable'
$form.MaximizeBox = $true
$form.Icon = $null

# --------- TITLE ---------
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 16)
$lblTitle.ForeColor = $primaryColor
$lblTitle.TextAlign = 'MiddleCenter'
$lblTitle.Size = New-Object System.Drawing.Size(750, 40)
$lblTitle.Location = New-Object System.Drawing.Point(25, 15)
$form.Controls.Add($lblTitle)

# --------- LANGUAGE BUTTON ---------
$btnLang = New-Object System.Windows.Forms.Button
$btnLang.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnLang.Size = New-Object System.Drawing.Size(50, 32)
$btnLang.Location = New-Object System.Drawing.Point(650, 15)
$btnLang.BackColor = [System.Drawing.Color]::White
$btnLang.ForeColor = $textColor
$btnLang.FlatStyle = 'Flat'
$btnLang.FlatAppearance.BorderSize = 1
$btnLang.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnLang.Text = "🌐"
$form.Controls.Add($btnLang)

# --------- LANGUAGE SELECT COMBO (visible) ---------
$cmbLang = New-Object System.Windows.Forms.ComboBox
$cmbLang.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$cmbLang.Size = New-Object System.Drawing.Size(80, 32)
$cmbLang.Location = New-Object System.Drawing.Point(710, 15)
$cmbLang.DropDownStyle = 'DropDownList'
$cmbLang.Items.AddRange(@("EN","VN")) | Out-Null
$cmbLang.SelectedItem = $Lang
$cmbLang.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($cmbLang)
$cmbLang.Add_SelectedIndexChanged({
    if ($cmbLang.SelectedItem -ne $null) {
        $Lang = $cmbLang.SelectedItem.ToString()
        Update-Language
    }
})

# --------- ADDRESS INPUT SECTION ---------
$lblAddress = New-Object System.Windows.Forms.Label
$lblAddress.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
$lblAddress.ForeColor = $textColor
$lblAddress.Size = New-Object System.Drawing.Size(750, 20)
$lblAddress.Location = New-Object System.Drawing.Point(25, 65)
$form.Controls.Add($lblAddress)

$txtAddress = New-Object System.Windows.Forms.TextBox
$txtAddress.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$txtAddress.Size = New-Object System.Drawing.Size(750, 40)
$txtAddress.Location = New-Object System.Drawing.Point(25, 85)
$txtAddress.BackColor = [System.Drawing.Color]::White
$txtAddress.ForeColor = $textColor
$form.Controls.Add($txtAddress)

# --------- CHECK BUTTON ---------
$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11)
$btnCheck.Size = New-Object System.Drawing.Size(360, 45)
$btnCheck.Location = New-Object System.Drawing.Point(25, 140)
$btnCheck.BackColor = $primaryColor
$btnCheck.ForeColor = [System.Drawing.Color]::White
$btnCheck.FlatStyle = 'Flat'
$btnCheck.FlatAppearance.BorderSize = 0
$btnCheck.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnCheck)
$btnCheck.Add_MouseEnter({ $btnCheck.BackColor = [System.Drawing.Color]::FromArgb(0, 110, 220) })
$btnCheck.Add_MouseLeave({ $btnCheck.BackColor = $primaryColor })

# --------- COPY BUTTON ---------
$btnCopy = New-Object System.Windows.Forms.Button
$btnCopy.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnCopy.Size = New-Object System.Drawing.Size(170, 45)
$btnCopy.Location = New-Object System.Drawing.Point(415, 140)
$btnCopy.BackColor = $successColor
$btnCopy.ForeColor = [System.Drawing.Color]::White
$btnCopy.FlatStyle = 'Flat'
$btnCopy.FlatAppearance.BorderSize = 0
$btnCopy.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnCopy.Enabled = $false
$form.Controls.Add($btnCopy)
$btnCopy.Add_MouseEnter({ if ($btnCopy.Enabled) { $btnCopy.BackColor = [System.Drawing.Color]::FromArgb(30, 150, 60) } })
$btnCopy.Add_MouseLeave({ if ($btnCopy.Enabled) { $btnCopy.BackColor = $successColor } })

# --------- CLEAR BUTTON ---------
$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnClear.Size = New-Object System.Drawing.Size(155, 45)
$btnClear.Location = New-Object System.Drawing.Point(620, 140)
$btnClear.BackColor = [System.Drawing.Color]::Gray
$btnClear.ForeColor = [System.Drawing.Color]::White
$btnClear.FlatStyle = 'Flat'
$btnClear.FlatAppearance.BorderSize = 0
$btnClear.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnClear)
$btnClear.Add_MouseEnter({ $btnClear.BackColor = [System.Drawing.Color]::DarkGray })
$btnClear.Add_MouseLeave({ $btnClear.BackColor = [System.Drawing.Color]::Gray })

# --------- SAVE BUTTON ---------
$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnSave.Size = New-Object System.Drawing.Size(130, 45)
$btnSave.Location = New-Object System.Drawing.Point(25, 625)
$btnSave.BackColor = [System.Drawing.Color]::FromArgb(102, 51, 153)
$btnSave.ForeColor = [System.Drawing.Color]::White
$btnSave.FlatStyle = 'Flat'
$btnSave.FlatAppearance.BorderSize = 0
$btnSave.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnSave.Enabled = $false
$form.Controls.Add($btnSave)
$btnSave.Add_MouseEnter({ if ($btnSave.Enabled) { $btnSave.BackColor = [System.Drawing.Color]::FromArgb(80, 30, 130) } })
$btnSave.Add_MouseLeave({ if ($btnSave.Enabled) { $btnSave.BackColor = [System.Drawing.Color]::FromArgb(102, 51, 153) } })

# --------- GO TO MAINSITE BUTTON ---------
$btnGoToSite = New-Object System.Windows.Forms.Button
$btnGoToSite.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnGoToSite.Size = New-Object System.Drawing.Size(145, 45)
$btnGoToSite.Location = New-Object System.Drawing.Point(165, 625)
$btnGoToSite.BackColor = [System.Drawing.Color]::FromArgb(255, 102, 0)
$btnGoToSite.ForeColor = [System.Drawing.Color]::White
$btnGoToSite.FlatStyle = 'Flat'
$btnGoToSite.FlatAppearance.BorderSize = 0
$btnGoToSite.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnGoToSite)
$btnGoToSite.Add_MouseEnter({ $btnGoToSite.BackColor = [System.Drawing.Color]::FromArgb(230, 80, 0) })
$btnGoToSite.Add_MouseLeave({ $btnGoToSite.BackColor = [System.Drawing.Color]::FromArgb(255, 102, 0) })

# --------- HISTORY BUTTON ---------
$btnHistory = New-Object System.Windows.Forms.Button
$btnHistory.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnHistory.Size = New-Object System.Drawing.Size(140, 45)
$btnHistory.Location = New-Object System.Drawing.Point(320, 625)
$btnHistory.BackColor = [System.Drawing.Color]::FromArgb(0, 102, 204)
$btnHistory.ForeColor = [System.Drawing.Color]::White
$btnHistory.FlatStyle = 'Flat'
$btnHistory.FlatAppearance.BorderSize = 0
$btnHistory.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnHistory)
$btnHistory.Add_MouseEnter({ $btnHistory.BackColor = [System.Drawing.Color]::FromArgb(0, 80, 180) })
$btnHistory.Add_MouseLeave({ $btnHistory.BackColor = [System.Drawing.Color]::FromArgb(0, 102, 204) })

# --------- VIEW ALL BUTTON ---------
$btnViewAll = New-Object System.Windows.Forms.Button
$btnViewAll.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnViewAll.Size = New-Object System.Drawing.Size(140, 45)
$btnViewAll.Location = New-Object System.Drawing.Point(470, 625)
$btnViewAll.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69)
$btnViewAll.ForeColor = [System.Drawing.Color]::White
$btnViewAll.FlatStyle = 'Flat'
$btnViewAll.FlatAppearance.BorderSize = 0
$btnViewAll.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnViewAll)
$btnViewAll.Add_MouseEnter({ $btnViewAll.BackColor = [System.Drawing.Color]::FromArgb(200, 30, 50) })
$btnViewAll.Add_MouseLeave({ $btnViewAll.BackColor = [System.Drawing.Color]::FromArgb(220, 53, 69) })

# --------- STATUS LABEL ---------
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblStatus.ForeColor = $textColor
$lblStatus.Size = New-Object System.Drawing.Size(750, 25)
$lblStatus.Location = New-Object System.Drawing.Point(25, 200)
$lblStatus.TextAlign = 'MiddleLeft'
$form.Controls.Add($lblStatus)

# --------- RESULTS PANEL ---------
$panelResults = New-Object System.Windows.Forms.Panel
$panelResults.Size = New-Object System.Drawing.Size(750, 340)
$panelResults.Location = New-Object System.Drawing.Point(25, 235)
$panelResults.BackColor = $panelColor
$panelResults.BorderStyle = 'FixedSingle'
$panelResults.AutoScroll = $true
$panelResults.Visible = $true
$form.Controls.Add($panelResults)

# --------- CHECKBOX LIST FOR BATCH CHECK ---------
$checkedListBox = New-Object System.Windows.Forms.CheckedListBox
$checkedListBox.Size = New-Object System.Drawing.Size(750, 340)
$checkedListBox.Location = New-Object System.Drawing.Point(25, 235)
$checkedListBox.BackColor = $panelColor
$checkedListBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$checkedListBox.BorderStyle = 'FixedSingle'
$checkedListBox.Visible = $false
$form.Controls.Add($checkedListBox)
$form.Controls.SetChildIndex($checkedListBox, 0)

# --------- BATCH CHECK BUTTONS PANEL ---------
$panelBatchButtons = New-Object System.Windows.Forms.Panel
$panelBatchButtons.Size = New-Object System.Drawing.Size(750, 60)
$panelBatchButtons.Location = New-Object System.Drawing.Point(25, 585)
$panelBatchButtons.BackColor = $panelColor
$panelBatchButtons.BorderStyle = 'FixedSingle'
$panelBatchButtons.Visible = $false
$form.Controls.Add($panelBatchButtons)
$form.Controls.SetChildIndex($panelBatchButtons, 0)

$btnSelectAll = New-Object System.Windows.Forms.Button
$btnSelectAll.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnSelectAll.Size = New-Object System.Drawing.Size(110, 38)
$btnSelectAll.Location = New-Object System.Drawing.Point(10, 10)
$btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(40, 167, 69)
$btnSelectAll.ForeColor = [System.Drawing.Color]::White
$btnSelectAll.FlatStyle = 'Flat'
$btnSelectAll.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnSelectAll.Text = if ($Lang -eq "EN") { "✓ Select All" } else { "✓ Chọn Tất Cả" }
$panelBatchButtons.Controls.Add($btnSelectAll)

$btnDeselectAll = New-Object System.Windows.Forms.Button
$btnDeselectAll.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnDeselectAll.Size = New-Object System.Drawing.Size(130, 38)
$btnDeselectAll.Location = New-Object System.Drawing.Point(125, 10)
$btnDeselectAll.BackColor = [System.Drawing.Color]::Gray
$btnDeselectAll.ForeColor = [System.Drawing.Color]::White
$btnDeselectAll.FlatStyle = 'Flat'
$btnDeselectAll.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnDeselectAll.Text = if ($Lang -eq "EN") { "✗ Deselect All" } else { "✗ Bỏ Chọn Tất Cả" }
$panelBatchButtons.Controls.Add($btnDeselectAll)

$btnCheckSelected = New-Object System.Windows.Forms.Button
$btnCheckSelected.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnCheckSelected.Size = New-Object System.Drawing.Size(140, 38)
$btnCheckSelected.Location = New-Object System.Drawing.Point(600, 10)
$btnCheckSelected.BackColor = $primaryColor
$btnCheckSelected.ForeColor = [System.Drawing.Color]::White
$btnCheckSelected.FlatStyle = 'Flat'
$btnCheckSelected.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnCheckSelected.Text = if ($Lang -eq "EN") { "🔍 Check Selected" } else { "🔍 Kiểm Tra" }
$panelBatchButtons.Controls.Add($btnCheckSelected)

$btnBackFromBatch = New-Object System.Windows.Forms.Button
$btnBackFromBatch.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$btnBackFromBatch.Size = New-Object System.Drawing.Size(90, 38)
$btnBackFromBatch.Location = New-Object System.Drawing.Point(745, 10)
$btnBackFromBatch.BackColor = [System.Drawing.Color]::Gray
$btnBackFromBatch.ForeColor = [System.Drawing.Color]::White
$btnBackFromBatch.FlatStyle = 'Flat'
$btnBackFromBatch.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnBackFromBatch.Text = if ($Lang -eq "EN") { "← Back" } else { "← Quay Lại" }
$panelBatchButtons.Controls.Add($btnBackFromBatch)

# --------- UPDATE FORM SIZE ---------
$form.Size = New-Object System.Drawing.Size(900, 700)

# --------- UPDATE LANGUAGE FUNCTION ---------
function Update-Language {
    $form.Text = $Text[$Lang].Title
    $lblTitle.Text = $Text[$Lang].Title
    $lblAddress.Text = $Text[$Lang].AddressHint
    $btnCheck.Text = $Text[$Lang].CheckButton
    $btnCopy.Text = $Text[$Lang].CopyButton
    $btnClear.Text = $Text[$Lang].ClearButton
    $btnSave.Text = $Text[$Lang].SaveButton
    $btnGoToSite.Text = if ($Lang -eq "EN") { "🌐 Go to Site" } else { "🌐 Đến Trang" }
    $btnHistory.Text = $Text[$Lang].HistoryButton
    $btnViewAll.Text = $Text[$Lang].ViewAllButton
    $btnLang.Text = $Text[$Lang].BtnLang
    $txtAddress.PlaceholderText = $Text[$Lang].AddressHint
}

Update-Language

# --------- LANGUAGE SWITCH EVENT ---------
$btnLang.Add_Click({
    if ($Lang -eq "EN") { $Lang = "VN" } else { $Lang = "EN" }
    Update-Language
})

# --------- CLEAR BUTTON EVENT ---------
$btnClear.Add_Click({
    $txtAddress.Clear()
    $panelResults.Controls.Clear()
    $lblStatus.Text = ""
    $btnCopy.Enabled = $false
    $btnSave.Enabled = $false
    $global:currentScheduleData = $null
    $global:currentAddress = ""
})

# --------- COPY TO CLIPBOARD EVENT ---------
$btnCopy.Add_Click({
    $content = @()
    foreach ($ctrl in $panelResults.Controls) {
        if ($ctrl -is [System.Windows.Forms.Label]) {
            $content += $ctrl.Text
        }
    }
    $clipboardText = $content -join "`n"
    [System.Windows.Forms.Clipboard]::SetText($clipboardText)
    [System.Windows.Forms.MessageBox]::Show($Text[$Lang].Success + "`n`n" + $TrademarkFull[$Lang], "Info", "OK", "Information")
})

# --------- CHECK BUTTON EVENT ---------
$btnCheck.Add_Click({
    $address = $txtAddress.Text.Trim()
    
    if ([string]::IsNullOrWhiteSpace($address)) {
        [System.Windows.Forms.MessageBox]::Show($Text[$Lang].InvalidAddress + "`n`n" + $TrademarkFull[$Lang], "Error", "OK", "Error")
        return
    }

    $lblStatus.Text = $Text[$Lang].Loading
    $lblStatus.ForeColor = $warningColor
    $panelResults.Controls.Clear()
    $btnCheck.Enabled = $false
    $btnCopy.Enabled = $false
    $form.Refresh()

    try {
        $url = "https://mainnet.prod.gd.midnighttge.io/thaws/$address/schedule"
        $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10 -UseBasicParsing
        
        $data = $response

        if (-not $data.thaws -or $data.thaws.Count -eq 0) {
            $lblStatus.Text = $Text[$Lang].NotFound
            $lblStatus.ForeColor = $warningColor
            $btnCheck.Enabled = $true
            return
        }

        $thaws = $data.thaws
        $totalAmount = 0
        $yPosition = 10

        # --------- SCHEDULE TITLE ---------
        $lblScheduleTitle = New-Object System.Windows.Forms.Label
        $lblScheduleTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12)
        $lblScheduleTitle.ForeColor = $primaryColor
        $lblScheduleTitle.Text = $Text[$Lang].ScheduleTitle
        $lblScheduleTitle.Size = New-Object System.Drawing.Size(730, 25)
        $lblScheduleTitle.Location = New-Object System.Drawing.Point(10, $yPosition)
        $lblScheduleTitle.TextAlign = 'MiddleLeft'
        $panelResults.Controls.Add($lblScheduleTitle)
        $yPosition += 35

        # --------- ADD EACH THAW BATCH ---------
        $idx = 1
        foreach ($item in $thaws) {
            $amount = $item.amount / 1e6
            $totalAmount += $amount

            # Parse date and adjust to UTC+7 (Vietnam timezone)
            $dt = [DateTime]::Parse($item.thawing_period_start)
            $dt = $dt.AddHours(7)
            $VNDate = $dt.ToString("yyyy-MM-dd HH:mm:ss")

            # Calculate days until thaw
            $thawDateTime = [DateTime]::Parse($item.thawing_period_start)
            $daysUntil = ($thawDateTime - [DateTime]::UtcNow).Days
            if ($daysUntil -lt 0) { $daysUntil = 0 }

            # Batch number and amount
            $lblBatch = New-Object System.Windows.Forms.Label
            $lblBatch.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
            $lblBatch.ForeColor = $textColor
            $lblBatch.Text = [string]::Format($Text[$Lang].ThawNo, $idx, $amount)
            $lblBatch.Size = New-Object System.Drawing.Size(730, 22)
            $lblBatch.Location = New-Object System.Drawing.Point(10, $yPosition)
            $panelResults.Controls.Add($lblBatch)
            $yPosition += 25

            # Status and countdown (use local label to avoid clobbering global `$lblStatus`)
            $statusText = if ($item.status -eq "upcoming") { "Unclaimed" } else { "Claimed" }
            $countdownText = if ($item.status -eq "upcoming") { " | In $daysUntil days" } else { "" }
            $lblBatchStatus = New-Object System.Windows.Forms.Label
            $lblBatchStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9)
            $lblBatchStatus.ForeColor = if ($item.status -eq "upcoming") { $warningColor } else { $successColor }
            $lblBatchStatus.Text = "   🔔 $statusText$countdownText"
            $lblBatchStatus.Size = New-Object System.Drawing.Size(730, 18)
            $lblBatchStatus.Location = New-Object System.Drawing.Point(20, $yPosition)
            $panelResults.Controls.Add($lblBatchStatus)
            $yPosition += 20

            # Date and time
            $lblDate = New-Object System.Windows.Forms.Label
            $lblDate.Font = New-Object System.Drawing.Font("Segoe UI", 9)
            $lblDate.ForeColor = [System.Drawing.Color]::Gray
            $lblDate.Text = [string]::Format($Text[$Lang].ThawTime, $VNDate)
            $lblDate.Size = New-Object System.Drawing.Size(730, 20)
            $lblDate.Location = New-Object System.Drawing.Point(20, $yPosition)
            $panelResults.Controls.Add($lblDate)
            $yPosition += 25

            # Spacer
            $yPosition += 5

            $idx++
        }

        # --------- DIVIDER ---------
        $lblDivider = New-Object System.Windows.Forms.Label
        $lblDivider.BorderStyle = 'FixedSingle'
        $lblDivider.Size = New-Object System.Drawing.Size(730, 1)
        $lblDivider.Location = New-Object System.Drawing.Point(10, $yPosition)
        $panelResults.Controls.Add($lblDivider)
        $yPosition += 10

        # --------- TOTAL AMOUNT ---------
        $lblTotal = New-Object System.Windows.Forms.Label
        $lblTotal.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11)
        $lblTotal.ForeColor = $successColor
        $lblTotal.Text = [string]::Format($Text[$Lang].TotalLabel, $totalAmount)
        $lblTotal.Size = New-Object System.Drawing.Size(730, 25)
        $lblTotal.Location = New-Object System.Drawing.Point(10, $yPosition)
        $panelResults.Controls.Add($lblTotal)
        $yPosition += 30

        # --------- BATCH COUNT ---------
        $lblBatchCount = New-Object System.Windows.Forms.Label
        $lblBatchCount.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11)
        $lblBatchCount.ForeColor = $accentColor
        $lblBatchCount.Text = [string]::Format($Text[$Lang].BatchLabel, $thaws.Count)
        $lblBatchCount.Size = New-Object System.Drawing.Size(730, 25)
        $lblBatchCount.Location = New-Object System.Drawing.Point(10, $yPosition)
        $panelResults.Controls.Add($lblBatchCount)

        # Update panel layout
        $panelResults.AutoScrollPosition = New-Object System.Drawing.Point(0, 0)

        $lblStatus.Text = $Text[$Lang].Success + " - " + $TrademarkShort[$Lang]
        $lblStatus.ForeColor = $successColor
        $btnCopy.Enabled = $true
        $btnSave.Enabled = $true
        
        # Lưu dữ liệu hiện tại
        $global:currentScheduleData = $thaws
        $global:currentAddress = $address

    } catch {
        $errorMsg = $_.Exception.Message
        $lblStatus.Text = [string]::Format($Text[$Lang].ApiError, $errorMsg)
        $lblStatus.ForeColor = $errorColor
    }

    $btnCheck.Enabled = $true
})

# --------- GET JSON FILE PATH ---------
function Get-JsonFilePath {
    $scriptPath = Split-Path -Parent $MyInvocation.ScriptName
    if ([string]::IsNullOrEmpty($scriptPath)) {
        $scriptPath = Get-Location
    }
    return [System.IO.Path]::Combine($scriptPath, "NIGHT_addresses.json")
}

# --------- SAVE TO JSON FUNCTION ---------
function Save-ToJson($addresses) {
    try {
        $filePath = Get-JsonFilePath

        # Read existing addresses if file exists (raw)
        $existingRaw = @()
        if (Test-Path $filePath) {
            try {
                $existingJson = Get-Content -Path $filePath -Encoding UTF8 | ConvertFrom-Json
                if ($null -ne $existingJson.Addresses) {
                    if ($existingJson.Addresses -is [array]) {
                        $existingRaw = $existingJson.Addresses
                    } else {
                        $existingRaw = @($existingJson.Addresses)
                    }
                }
            } catch {
                # If file is corrupted, start fresh
                $existingRaw = @()
            }
        }

        # Helper: extract plain address string from possible nested shapes
        function Get-AddrString($obj) {
            if ($null -eq $obj) { return "" }
            if ($obj -is [PSCustomObject]) {
                if ($obj.PSObject.Properties.Name -contains 'address') {
                    return Get-AddrString $obj.address
                } elseif ($obj.PSObject.Properties.Name -contains 'Address') {
                    return Get-AddrString $obj.Address
                } else {
                    return ($obj | ConvertTo-Json -Compress)
                }
            } else {
                return $obj.ToString()
            }
        }

        # Normalize existing addresses into plain strings (deduplicated)
        $existingAddresses = @()
        foreach ($e in $existingRaw) {
            $s = Get-AddrString $e
            if (-not [string]::IsNullOrWhiteSpace($s) -and ($s -notin $existingAddresses)) {
                $existingAddresses += $s
            }
        }

        # Add new addresses (avoid duplicates)
        foreach ($addr in $addresses) {
            $trimAddr = $addr.ToString().Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimAddr)) {
                if ($trimAddr -notin $existingAddresses) {
                    $existingAddresses += $trimAddr
                }
            }
        }

        # Create data structure with array of address objects (consistent shape)
        $addressObjects = @()
        $idx = 1
        foreach ($addr in $existingAddresses) {
            $addressObjects += @{ "id" = $idx; "address" = $addr }
            $idx++
        }

        $data = @{ "CreatedAt" = (Get-Date -Format "yyyy-MM-dd HH:mm:ss"); "Addresses" = $addressObjects }

        # Convert to JSON and save
        $jsonContent = $data | ConvertTo-Json -Depth 10
        $jsonContent | Out-File -FilePath $filePath -Encoding UTF8 -Force

        $global:excelFilePath = $filePath
        return $filePath

    } catch {
        throw $_
    }
}

# --------- SAVE BUTTON EVENT ---------
$btnSave.Add_Click({
    if ([string]::IsNullOrWhiteSpace($global:currentAddress)) {
        [System.Windows.Forms.MessageBox]::Show("No data to save!" + "`n`n" + $TrademarkFull[$Lang], "Warning", "OK", "Warning")
        return
    }
    
    $res = [System.Windows.Forms.MessageBox]::Show($Text[$Lang].SavePrompt, "Save Excel", "YesNo", "Question")
    
    if ($res -eq "Yes") {
        $btnSave.Enabled = $false
        $lblStatus.Text = "💾 Saving to Excel..."
        $lblStatus.ForeColor = $warningColor
        $form.Refresh()
        
        try {
            $filePath = Save-ToJson -addresses @($global:currentAddress)
            $lblStatus.Text = [string]::Format($Text[$Lang].SaveSuccess, (Split-Path $filePath -Leaf)) + " - " + $TrademarkShort[$Lang]
            $lblStatus.ForeColor = $successColor
            [System.Windows.Forms.MessageBox]::Show([string]::Format($Text[$Lang].SaveSuccess, $filePath) + "`n`n" + $TrademarkFull[$Lang], "Success", "OK", "Information")
        } catch {
            $lblStatus.Text = [string]::Format($Text[$Lang].SaveError, $_.Exception.Message)
            $lblStatus.ForeColor = $errorColor
            [System.Windows.Forms.MessageBox]::Show([string]::Format($Text[$Lang].SaveError, $_.Exception.Message) + "`n`n" + $TrademarkFull[$Lang], "Error", "OK", "Error")
        }
        
        $btnSave.Enabled = $true
    }
})

# --------- VIEW HISTORY FUNCTION ---------
function Show-HistoryWindow {
    $historyForm = New-Object System.Windows.Forms.Form
    $historyForm.Text = if ($Lang -eq "EN") { "View Schedule History" } else { "Xem Lịch Sử Kiểm Tra" }
    $historyForm.Size = New-Object System.Drawing.Size(1000, 600)
    $historyForm.StartPosition = "CenterParent"
    $historyForm.BackColor = $bgColor
    $historyForm.FormBorderStyle = 'FixedDialog'
    $historyForm.MaximizeBox = $false
    
    $docFolder = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("MyDocuments"), "NIGHT_Schedules")
    
    if (-not (Test-Path $docFolder)) {
        [System.Windows.Forms.MessageBox]::Show("No saved files found!" + "`n`n" + $TrademarkFull[$Lang], "Info", "OK", "Information")
        return
    }
    
    # Create DataGridView
    $dataGridView = New-Object System.Windows.Forms.DataGridView
    $dataGridView.Size = New-Object System.Drawing.Size(970, 500)
    $dataGridView.Location = New-Object System.Drawing.Point(15, 15)
    $dataGridView.BackColor = $panelColor
    $dataGridView.AutoGenerateColumns = $false
    $dataGridView.AllowUserToDeleteRows = $false
    $dataGridView.ReadOnly = $true
    $historyForm.Controls.Add($dataGridView)
    
    # Get all JSON files
    $jsonFiles = Get-ChildItem -Path $docFolder -Filter "*.json" -File | Sort-Object LastWriteTime -Descending
    
    if ($jsonFiles.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No saved files found!" + "`n`n" + $TrademarkFull[$Lang], "Info", "OK", "Information")
        return
    }
    
    # Load all addresses from JSON files
    $allData = @()
    
    foreach ($file in $jsonFiles) {
        try {
            $jsonContent = Get-Content -Path $file.FullName -Encoding UTF8 | ConvertFrom-Json
            
            foreach ($address in $jsonContent.Addresses) {
                try {
                    if ($address -is [PSCustomObject]) {
                        if ($address.PSObject.Properties.Name -contains 'address') {
                            $addrStr = $address.address.ToString()
                        } else {
                            $addrStr = ($address | ConvertTo-Json -Compress)
                        }
                    } else {
                        $addrStr = $address.ToString()
                    }

                    if (-not [string]::IsNullOrEmpty($addrStr)) {
                        $allData += [PSCustomObject]@{
                            Address = $addrStr
                            FileName = $file.Name
                            FilePath = $file.FullName
                            Modified = $file.LastWriteTime
                        }
                    }
                } catch {
                    # Skip malformed entries
                }
            }
        } catch {
            # Skip files that can't be opened
        }
    }
    
    # Add columns to DataGridView
    $col1 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $col1.Name = "Address"
    $col1.HeaderText = "Address"
    $col1.Width = 250
    $dataGridView.Columns.Add($col1)
    
    $col2 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $col2.Name = "FileName"
    $col2.HeaderText = "File"
    $col2.Width = 300
    $dataGridView.Columns.Add($col2)
    
    $col3 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
    $col3.Name = "Modified"
    $col3.HeaderText = "Modified"
    $col3.Width = 180
    $dataGridView.Columns.Add($col3)
    
    # Add rows
    foreach ($item in $allData) {
        $dateStr = $item.Modified.ToString("yyyy-MM-dd HH:mm:ss")
        $dataGridView.Rows.Add($item.Address, $item.FileName, $dateStr)
    }
    
    # Footer
    $lblInfo = New-Object System.Windows.Forms.Label
    $lblInfo.Text = "📁 Folder: $docFolder`n" + $TrademarkShort[$Lang]
    $lblInfo.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $lblInfo.ForeColor = [System.Drawing.Color]::Gray
    $lblInfo.AutoSize = $true
    $lblInfo.Location = New-Object System.Drawing.Point(15, 525)
    $historyForm.Controls.Add($lblInfo)
    
    $historyForm.ShowDialog() | Out-Null
}

# --------- VIEW ALL FUNCTION ---------
function Show-ViewAllWindow {
    $filePath = Get-JsonFilePath
    
    # Check if file exists
    if (-not (Test-Path $filePath)) {
        $msg = if ($Lang -eq "EN") { "No saved addresses file found!" } else { "Không tìm thấy file địa chỉ!" }
        [System.Windows.Forms.MessageBox]::Show($msg, "Info", "OK", "Information")
        return
    }
    
    # Read addresses from file (handle both object and string entries)
    $addresses = @()
    try {
        $jsonContent = Get-Content -Path $filePath -Encoding UTF8 | ConvertFrom-Json
        if ($null -ne $jsonContent.Addresses) {
            if ($jsonContent.Addresses -is [array]) {
                foreach ($item in $jsonContent.Addresses) {
                    if ($item -is [PSCustomObject]) {
                        if ($item.PSObject.Properties.Name -contains 'address') {
                            $addresses += $item.address.ToString()
                        } else {
                            # fallback: convert whole object to string (shouldn't normally happen)
                            $addresses += ($item | ConvertTo-Json -Compress)
                        }
                    } else {
                        $addresses += $item.ToString()
                    }
                }
            } else {
                # Single Addresses entry
                if ($jsonContent.Addresses -is [PSCustomObject] -and ($jsonContent.Addresses.PSObject.Properties.Name -contains 'address')) {
                    $addresses += $jsonContent.Addresses.address.ToString()
                } else {
                    $addresses += $jsonContent.Addresses.ToString()
                }
            }
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error reading file!" + "`n`n" + $TrademarkFull[$Lang], "Error", "OK", "Error")
        return
    }
    
    if ($addresses.Count -eq 0) {
        $msg = if ($Lang -eq "EN") { "No addresses found in file!" } else { "Không tìm thấy địa chỉ nào!" }
        [System.Windows.Forms.MessageBox]::Show($msg + "`n`n" + $TrademarkFull[$Lang], "Info", "OK", "Information")
        return
    }
    
    # Switch to batch check view
    $panelResults.Visible = $false
    $checkedListBox.Visible = $true
    $panelBatchButtons.Visible = $true
    $lblStatus.Text = if ($Lang -eq "EN") { "Select addresses to check" } else { "Chọn địa chỉ để kiểm tra" }
    $lblStatus.ForeColor = $textColor
    
    # Clear and load addresses
    $checkedListBox.Items.Clear()
    foreach ($addr in $addresses) {
        $checkedListBox.Items.Add($addr)
    }
}

# --------- SELECT ALL BUTTON EVENT ---------
$btnSelectAll.Add_Click({
    for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
        $checkedListBox.SetItemChecked($i, $true)
    }
})

# --------- DESELECT ALL BUTTON EVENT ---------
$btnDeselectAll.Add_Click({
    for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
        $checkedListBox.SetItemChecked($i, $false)
    }
})

# --------- CHECK SELECTED BUTTON EVENT ---------
$btnCheckSelected.Add_Click({
    $selectedAddresses = @()
    for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
        if ($checkedListBox.GetItemChecked($i)) {
            $selectedAddresses += $checkedListBox.Items[$i]
        }
    }
    
    if ($selectedAddresses.Count -eq 0) {
        $msg = if ($Lang -eq "EN") { "Please select at least one address!" } else { "Vui lòng chọn ít nhất một địa chỉ!" }
        [System.Windows.Forms.MessageBox]::Show($msg + "`n`n" + $TrademarkFull[$Lang], "Warning", "OK", "Warning")
        return
    }
    
    # Switch to results view
    $checkedListBox.Visible = $false
    $panelBatchButtons.Visible = $false
    $panelResults.Visible = $true
    $panelResults.Controls.Clear()
    
    $lblStatus.Text = $Text[$Lang].Loading
    $lblStatus.ForeColor = $warningColor
    $form.Refresh()
    
    # Check selected addresses
    $yPosition = 15
    $totalNight = 0
    $successCount = 0
    $allResults = @()
    
    for ($i = 0; $i -lt $selectedAddresses.Count; $i++) {
        $addr = $selectedAddresses[$i].Trim()
        $form.Refresh()
        [System.Windows.Forms.Application]::DoEvents()
        
        try {
            $url = "https://mainnet.prod.gd.midnighttge.io/thaws/$addr/schedule"
            $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10 -UseBasicParsing
            
            if ($response -and $response.thaws -and $response.thaws.Count -gt 0) {
                $successCount++
                $totalAmount = 0
                $thawDetails = @()
                
                foreach ($item in $response.thaws) {
                    $amount = [decimal]$item.amount / 1e6
                    $totalAmount += $amount
                    
                    # Parse date and compute status/countdown
                    $thawDateTime = [DateTime]::Parse($item.thawing_period_start)
                    $dt = $thawDateTime.AddHours(7)
                    $VNDate = $dt.ToString("yyyy-MM-dd HH:mm:ss")

                    $daysUntil = ($thawDateTime - [DateTime]::UtcNow).Days
                    if ($daysUntil -lt 0) { $daysUntil = 0 }

                    $statusText = if ($item.status -eq "upcoming") { "Unclaimed" } else { "Claimed" }

                    $thawDetails += @{
                        Amount = $amount
                        Date = $VNDate
                        Status = $statusText
                        DaysUntil = $daysUntil
                    }
                }
                
                $allResults += [PSCustomObject]@{
                    Address = $addr
                    Total = $totalAmount
                    Count = $response.thaws.Count
                    Details = $thawDetails
                }
                
                $totalNight += $totalAmount
            }
        } catch {
            # Skip on error
        }
        
        Start-Sleep -Milliseconds 300
    }
    
    # Display results in panelResults
    # Title
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 12)
    $lblTitle.ForeColor = $primaryColor
    $lblTitle.Text = if ($Lang -eq "EN") { "📊 NIGHT SCHEDULE SUMMARY" } else { "📊 TÓM TẮT LỊCH TRẢ NIGHT" }
    $lblTitle.Size = New-Object System.Drawing.Size(730, 25)
    $lblTitle.Location = New-Object System.Drawing.Point(10, $yPosition)
    $lblTitle.TextAlign = 'MiddleLeft'
    $panelResults.Controls.Add($lblTitle)
    $yPosition += 30
    
    # Overall stats
    $lblStats = New-Object System.Windows.Forms.Label
    $lblStats.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
    $lblStats.ForeColor = $successColor
    $statsText = if ($Lang -eq "EN") {
        "✅ Checked: $($selectedAddresses.Count) | Success: $successCount | Total NIGHT: $($totalNight.ToString("N0"))"
    } else {
        "✅ Kiểm tra: $($selectedAddresses.Count) | Thành công: $successCount | Tổng NIGHT: $($totalNight.ToString("N0"))"
    }
    $lblStats.Text = $statsText
    $lblStats.Size = New-Object System.Drawing.Size(730, 20)
    $lblStats.Location = New-Object System.Drawing.Point(10, $yPosition)
    $panelResults.Controls.Add($lblStats)
    $yPosition += 25
    
    # Divider
    $lblDiv = New-Object System.Windows.Forms.Label
    $lblDiv.BorderStyle = 'FixedSingle'
    $lblDiv.Size = New-Object System.Drawing.Size(730, 1)
    $lblDiv.Location = New-Object System.Drawing.Point(10, $yPosition)
    $panelResults.Controls.Add($lblDiv)
    $yPosition += 10
    
    # Details for each address
        foreach ($result in $allResults) {
        # Address header
        $lblAddr = New-Object System.Windows.Forms.Label
        $lblAddr.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
        $lblAddr.ForeColor = $textColor
        $lblAddr.Text = "📌 $($result.Address)"
        $lblAddr.Size = New-Object System.Drawing.Size(730, 20)
        $lblAddr.Location = New-Object System.Drawing.Point(10, $yPosition)
        $panelResults.Controls.Add($lblAddr)
        $yPosition += 22
        
        # Total and batch count
        $lblAmount = New-Object System.Windows.Forms.Label
        $lblAmount.Font = New-Object System.Drawing.Font("Segoe UI", 9)
        $lblAmount.ForeColor = $accentColor
        $lblAmount.Text = "   💰 Total: $($result.Total.ToString("N0")) NIGHT | 📦 Batches: $($result.Count)"
        $lblAmount.Size = New-Object System.Drawing.Size(730, 18)
        $lblAmount.Location = New-Object System.Drawing.Point(10, $yPosition)
        $panelResults.Controls.Add($lblAmount)
        $yPosition += 20
        
        # Thaw details
        $batchNum = 1
        foreach ($detail in $result.Details) {
            $lblDetail = New-Object System.Windows.Forms.Label
            $lblDetail.Font = New-Object System.Drawing.Font("Segoe UI", 8)
            $lblDetail.ForeColor = [System.Drawing.Color]::Gray
            $lblDetail.Text = "      Batch $batchNum`: $($detail.Amount.ToString("N0")) NIGHT - $($detail.Date)"
            $lblDetail.Size = New-Object System.Drawing.Size(730, 16)
            $lblDetail.Location = New-Object System.Drawing.Point(10, $yPosition)
            $panelResults.Controls.Add($lblDetail)
            $yPosition += 18

            # Status & countdown label (similar to single-address view)
            $lblStatusSmall = New-Object System.Windows.Forms.Label
            $lblStatusSmall.Font = New-Object System.Drawing.Font("Segoe UI", 8)
            $lblStatusSmall.ForeColor = if ($detail.Status -eq 'Unclaimed') { $warningColor } else { $successColor }
            $countdownText = if ($detail.Status -eq 'Unclaimed') { " | In $($detail.DaysUntil) days" } else { "" }
            $lblStatusSmall.Text = "   🔔 $($detail.Status)$countdownText"
            $lblStatusSmall.Size = New-Object System.Drawing.Size(730, 14)
            $lblStatusSmall.Location = New-Object System.Drawing.Point(20, $yPosition)
            $panelResults.Controls.Add($lblStatusSmall)
            $yPosition += 16

            $batchNum++
        }
        
        $yPosition += 8
    }
    
    $panelResults.AutoScrollPosition = New-Object System.Drawing.Point(0, 0)
    $lblStatus.Text = if ($Lang -eq "EN") { "✅ Completed!" } else { "✅ Hoàn thành!" }
    $lblStatus.ForeColor = $successColor
})

# --------- BACK FROM BATCH BUTTON EVENT ---------
$btnBackFromBatch.Add_Click({
    $panelResults.Visible = $true
    $checkedListBox.Visible = $false
    $panelBatchButtons.Visible = $false
    $panelResults.Controls.Clear()
    $lblStatus.Text = ""
    $lblStatus.ForeColor = $textColor
})

# --------- HISTORY BUTTON EVENT ---------
$btnHistory.Add_Click({
    Show-HistoryWindow
})

# --------- VIEW ALL BUTTON EVENT ---------
$btnViewAll.Add_Click({
    Show-ViewAllWindow
})

# --------- GO TO MAINSITE BUTTON EVENT ---------
$btnGoToSite.Add_Click({
    Start-Process "https://redeem.midnight.gd/"
})

# --------- TRADEMARK POPUP (shown at startup) ---------
function Show-TrademarkPopup {
    $tmForm = New-Object System.Windows.Forms.Form
    $tmForm.Text = if ($Lang -eq "EN") { "About / Attribution" } else { "Giới thiệu / Ghi nguồn" }
    $tmForm.Size = New-Object System.Drawing.Size(520, 300)
    $tmForm.StartPosition = "CenterScreen"
    $tmForm.FormBorderStyle = 'FixedDialog'
    $tmForm.MaximizeBox = $false
    $tmForm.MinimizeBox = $false
    $tmForm.BackColor = $bgColor

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $lbl.ForeColor = $textColor
    $lbl.Location = New-Object System.Drawing.Point(12, 12)
    $lbl.Size = New-Object System.Drawing.Size(484, 200)
    $lbl.Text = $TrademarkFull[$Lang]
    $lbl.AutoEllipsis = $true
    $lbl.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
    $tmForm.Controls.Add($lbl)

    $btnText = if ($Lang -eq "EN") { "Let's go" } else { "Tiếp tục" }
    $btnGo = New-Object System.Windows.Forms.Button
    $btnGo.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $btnGo.Size = New-Object System.Drawing.Size(120, 36)
    $btnGo.Location = New-Object System.Drawing.Point(188, 220)
    $btnGo.Text = $btnText
    $btnGo.BackColor = $primaryColor
    $btnGo.ForeColor = [System.Drawing.Color]::White
    $btnGo.FlatStyle = 'Flat'
    $btnGo.FlatAppearance.BorderSize = 0
    $btnGo.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnGo.Add_Click({ $tmForm.Close() })
    $tmForm.Controls.Add($btnGo)

    # Make the popup modal and top-most so user sees it first
    $tmForm.TopMost = $true
    $tmForm.ShowDialog() | Out-Null
}

# Show trademark popup, then main form
Show-TrademarkPopup
$form.ShowDialog() | Out-Null
