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
        SaveButton = "💾 Save XLSX"
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

# --------- GLOBAL VARIABLES ---------
$global:currentScheduleData = $null
$global:currentAddress = ""
$global:excelFilePath = ""

# --------- MAIN FORM ---------
$form = New-Object System.Windows.Forms.Form
$form.Text = $Text[$Lang].Title
$form.Size = New-Object System.Drawing.Size(800, 700)
$form.StartPosition = "CenterScreen"
$form.BackColor = $bgColor
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
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
$btnLang.Size = New-Object System.Drawing.Size(100, 32)
$btnLang.Location = New-Object System.Drawing.Point(700, 15)
$btnLang.BackColor = [System.Drawing.Color]::White
$btnLang.ForeColor = $textColor
$btnLang.FlatStyle = 'Flat'
$btnLang.FlatAppearance.BorderSize = 1
$btnLang.Cursor = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnLang)

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
$btnSave.Size = New-Object System.Drawing.Size(155, 45)
$btnSave.Location = New-Object System.Drawing.Point(25, 595)
$btnSave.BackColor = [System.Drawing.Color]::FromArgb(102, 51, 153)
$btnSave.ForeColor = [System.Drawing.Color]::White
$btnSave.FlatStyle = 'Flat'
$btnSave.FlatAppearance.BorderSize = 0
$btnSave.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnSave.Enabled = $false
$form.Controls.Add($btnSave)
$btnSave.Add_MouseEnter({ if ($btnSave.Enabled) { $btnSave.BackColor = [System.Drawing.Color]::FromArgb(80, 30, 130) } })
$btnSave.Add_MouseLeave({ if ($btnSave.Enabled) { $btnSave.BackColor = [System.Drawing.Color]::FromArgb(102, 51, 153) } })

# --------- HISTORY BUTTON ---------
$btnHistory = New-Object System.Windows.Forms.Button
$btnHistory.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnHistory.Size = New-Object System.Drawing.Size(170, 45)
$btnHistory.Location = New-Object System.Drawing.Point(200, 595)
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
$btnViewAll.Size = New-Object System.Drawing.Size(170, 45)
$btnViewAll.Location = New-Object System.Drawing.Point(390, 595)
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
$form.Controls.Add($panelResults)

# --------- UPDATE FORM SIZE ---------
$form.Size = New-Object System.Drawing.Size(800, 740)

# --------- UPDATE LANGUAGE FUNCTION ---------
function Update-Language {
    $form.Text = $Text[$Lang].Title
    $lblTitle.Text = $Text[$Lang].Title
    $lblAddress.Text = $Text[$Lang].AddressHint
    $btnCheck.Text = $Text[$Lang].CheckButton
    $btnCopy.Text = $Text[$Lang].CopyButton
    $btnClear.Text = $Text[$Lang].ClearButton
    $btnSave.Text = $Text[$Lang].SaveButton
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
    [System.Windows.Forms.MessageBox]::Show($Text[$Lang].Success, "Info", "OK", "Information")
})

# --------- CHECK BUTTON EVENT ---------
$btnCheck.Add_Click({
    $address = $txtAddress.Text.Trim()
    
    if ([string]::IsNullOrWhiteSpace($address)) {
        [System.Windows.Forms.MessageBox]::Show($Text[$Lang].InvalidAddress, "Error", "OK", "Error")
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

            # Batch number and amount
            $lblBatch = New-Object System.Windows.Forms.Label
            $lblBatch.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
            $lblBatch.ForeColor = $textColor
            $lblBatch.Text = [string]::Format($Text[$Lang].ThawNo, $idx, $amount)
            $lblBatch.Size = New-Object System.Drawing.Size(730, 22)
            $lblBatch.Location = New-Object System.Drawing.Point(10, $yPosition)
            $panelResults.Controls.Add($lblBatch)
            $yPosition += 25

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

        $lblStatus.Text = $Text[$Lang].Success
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

# --------- SAVE TO JSON FUNCTION ---------
function Save-ToJson($addresses) {
    try {
        # Create data structure
        $data = @{
            CreatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            Addresses = $addresses | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }
        }
        
        # Convert to JSON
        $jsonContent = $data | ConvertTo-Json -Depth 10
        
        # Save file
        $docFolder = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("MyDocuments"), "NIGHT_Schedules")
        if (-not (Test-Path $docFolder)) {
            New-Item -ItemType Directory -Path $docFolder -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $fileName = "NIGHT_Addresses_$timestamp.json"
        $filePath = [System.IO.Path]::Combine($docFolder, $fileName)
        
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
        [System.Windows.Forms.MessageBox]::Show("No data to save!", "Warning", "OK", "Warning")
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
            $lblStatus.Text = [string]::Format($Text[$Lang].SaveSuccess, (Split-Path $filePath -Leaf))
            $lblStatus.ForeColor = $successColor
            [System.Windows.Forms.MessageBox]::Show([string]::Format($Text[$Lang].SaveSuccess, $filePath), "Success", "OK", "Information")
        } catch {
            $lblStatus.Text = [string]::Format($Text[$Lang].SaveError, $_.Exception.Message)
            $lblStatus.ForeColor = $errorColor
            [System.Windows.Forms.MessageBox]::Show([string]::Format($Text[$Lang].SaveError, $_.Exception.Message), "Error", "OK", "Error")
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
        [System.Windows.Forms.MessageBox]::Show("No saved files found!", "Info", "OK", "Information")
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
        [System.Windows.Forms.MessageBox]::Show("No saved files found!", "Info", "OK", "Information")
        return
    }
    
    # Load all addresses from JSON files
    $allData = @()
    
    foreach ($file in $jsonFiles) {
        try {
            $jsonContent = Get-Content -Path $file.FullName -Encoding UTF8 | ConvertFrom-Json
            
            foreach ($address in $jsonContent.Addresses) {
                if (-not [string]::IsNullOrEmpty($address)) {
                    $allData += [PSCustomObject]@{
                        Address = $address
                        FileName = $file.Name
                        FilePath = $file.FullName
                        Modified = $file.LastWriteTime
                    }
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
    $lblInfo.Text = "📁 Folder: $docFolder"
    $lblInfo.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $lblInfo.ForeColor = [System.Drawing.Color]::Gray
    $lblInfo.AutoSize = $true
    $lblInfo.Location = New-Object System.Drawing.Point(15, 525)
    $historyForm.Controls.Add($lblInfo)
    
    $historyForm.ShowDialog() | Out-Null
}

# --------- VIEW ALL FUNCTION ---------
function Show-ViewAllWindow {
    $docFolder = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("MyDocuments"), "NIGHT_Schedules")
    
    if (-not (Test-Path $docFolder)) {
        $msg = if ($Lang -eq "EN") { "No saved files found!" } else { "Không tìm thấy file!" }
        [System.Windows.Forms.MessageBox]::Show($msg, "Info", "OK", "Information")
        return
    }
    
    # Get all JSON files
    $jsonFiles = Get-ChildItem -Path $docFolder -Filter "NIGHT_Addresses_*.json" -File | Sort-Object LastWriteTime -Descending
    
    if ($jsonFiles.Count -eq 0) {
        $msg = if ($Lang -eq "EN") { "No address files found!" } else { "Không tìm thấy file địa chỉ!" }
        [System.Windows.Forms.MessageBox]::Show($msg, "Info", "OK", "Information")
        return
    }
    
    # Get the latest file
    $latestFile = $jsonFiles[0]
    
    # Read addresses from file
    $addresses = @()
    try {
        $jsonContent = Get-Content -Path $latestFile.FullName -Encoding UTF8 | ConvertFrom-Json
        $addresses = $jsonContent.Addresses
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error reading file!", "Error", "OK", "Error")
        return
    }
    
    if ($addresses.Count -eq 0) {
        $msg = if ($Lang -eq "EN") { "No addresses found in file!" } else { "Không tìm thấy địa chỉ nào!" }
        [System.Windows.Forms.MessageBox]::Show($msg, "Info", "OK", "Information")
        return
    }
    
    # Create view window
    $viewForm = New-Object System.Windows.Forms.Form
    $viewForm.Text = if ($Lang -eq "EN") { "Select Addresses to Check" } else { "Chọn Địa Chỉ để Kiểm Tra" }
    $viewForm.Size = New-Object System.Drawing.Size(1000, 700)
    $viewForm.StartPosition = "CenterParent"
    $viewForm.BackColor = $bgColor
    $viewForm.FormBorderStyle = 'FixedDialog'
    $viewForm.MaximizeBox = $false
    
    # Top panel - File info and buttons
    $topPanel = New-Object System.Windows.Forms.Panel
    $topPanel.Size = New-Object System.Drawing.Size(970, 60)
    $topPanel.Location = New-Object System.Drawing.Point(15, 15)
    $topPanel.BackColor = $bgColor
    $viewForm.Controls.Add($topPanel)
    
    # File info label
    $lblFileInfo = New-Object System.Windows.Forms.Label
    $lblFileInfo.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $lblFileInfo.ForeColor = [System.Drawing.Color]::Gray
    $lblFileInfo.Text = "📁 File: $($latestFile.Name)"
    $lblFileInfo.AutoSize = $true
    $lblFileInfo.Location = New-Object System.Drawing.Point(0, 0)
    $topPanel.Controls.Add($lblFileInfo)
    
    # Select All button
    $btnSelectAll = New-Object System.Windows.Forms.Button
    $btnSelectAll.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $btnSelectAll.Size = New-Object System.Drawing.Size(120, 30)
    $btnSelectAll.Location = New-Object System.Drawing.Point(0, 25)
    $btnSelectAll.BackColor = [System.Drawing.Color]::FromArgb(40, 167, 69)
    $btnSelectAll.ForeColor = [System.Drawing.Color]::White
    $btnSelectAll.FlatStyle = 'Flat'
    $btnSelectAll.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnSelectAll.Text = if ($Lang -eq "EN") { "✓ Select All" } else { "✓ Chọn Tất Cả" }
    $topPanel.Controls.Add($btnSelectAll)
    
    # Deselect All button
    $btnDeselectAll = New-Object System.Windows.Forms.Button
    $btnDeselectAll.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $btnDeselectAll.Size = New-Object System.Drawing.Size(140, 30)
    $btnDeselectAll.Location = New-Object System.Drawing.Point(125, 25)
    $btnDeselectAll.BackColor = [System.Drawing.Color]::Gray
    $btnDeselectAll.ForeColor = [System.Drawing.Color]::White
    $btnDeselectAll.FlatStyle = 'Flat'
    $btnDeselectAll.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnDeselectAll.Text = if ($Lang -eq "EN") { "✗ Deselect All" } else { "✗ Bỏ Chọn Tất Cả" }
    $topPanel.Controls.Add($btnDeselectAll)
    
    # Check button
    $btnCheckSelected = New-Object System.Windows.Forms.Button
    $btnCheckSelected.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $btnCheckSelected.Size = New-Object System.Drawing.Size(150, 30)
    $btnCheckSelected.Location = New-Object System.Drawing.Point(840, 25)
    $btnCheckSelected.BackColor = $primaryColor
    $btnCheckSelected.ForeColor = [System.Drawing.Color]::White
    $btnCheckSelected.FlatStyle = 'Flat'
    $btnCheckSelected.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btnCheckSelected.Text = if ($Lang -eq "EN") { "🔍 Check Selected" } else { "🔍 Kiểm Tra" }
    $topPanel.Controls.Add($btnCheckSelected)
    
    # Checkbox list for addresses
    $checkedListBox = New-Object System.Windows.Forms.CheckedListBox
    $checkedListBox.Size = New-Object System.Drawing.Size(970, 520)
    $checkedListBox.Location = New-Object System.Drawing.Point(15, 85)
    $checkedListBox.BackColor = $panelColor
    $checkedListBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
    $checkedListBox.BorderStyle = 'FixedSingle'
    $viewForm.Controls.Add($checkedListBox)
    
    # Add addresses to checklist
    foreach ($addr in $addresses) {
        $checkedListBox.Items.Add($addr)
    }
    
    # Select All button click event
    $btnSelectAll.Add_Click({
        for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
            $checkedListBox.SetItemChecked($i, $true)
        }
    })
    
    # Deselect All button click event
    $btnDeselectAll.Add_Click({
        for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
            $checkedListBox.SetItemChecked($i, $false)
        }
    })
    
    # Check Selected button click event
    $btnCheckSelected.Add_Click({
        $selectedAddresses = @()
        for ($i = 0; $i -lt $checkedListBox.Items.Count; $i++) {
            if ($checkedListBox.GetItemChecked($i)) {
                $selectedAddresses += $checkedListBox.Items[$i]
            }
        }
        
        if ($selectedAddresses.Count -eq 0) {
            $msg = if ($Lang -eq "EN") { "Please select at least one address!" } else { "Vui lòng chọn ít nhất một địa chỉ!" }
            [System.Windows.Forms.MessageBox]::Show($msg, "Warning", "OK", "Warning")
            return
        }
        
        $viewForm.Hide()
        Show-CheckResultsWindow -selectedAddresses $selectedAddresses
        $viewForm.Close()
    })
    
    $viewForm.ShowDialog() | Out-Null
}

# --------- CHECK RESULTS WINDOW ---------
function Show-CheckResultsWindow {
    param([array]$selectedAddresses)
    
    # Create results window
    $resultsForm = New-Object System.Windows.Forms.Form
    $resultsForm.Text = if ($Lang -eq "EN") { "Check Results" } else { "Kết Quả Kiểm Tra" }
    $resultsForm.Size = New-Object System.Drawing.Size(1000, 700)
    $resultsForm.StartPosition = "CenterParent"
    $resultsForm.BackColor = $bgColor
    $resultsForm.FormBorderStyle = 'FixedDialog'
    $resultsForm.MaximizeBox = $false
    
    # Progress bar
    $progressBar = New-Object System.Windows.Forms.ProgressBar
    $progressBar.Size = New-Object System.Drawing.Size(970, 20)
    $progressBar.Location = New-Object System.Drawing.Point(15, 15)
    $progressBar.Style = 'Continuous'
    $resultsForm.Controls.Add($progressBar)
    
    # Status label
    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $lblStatus.ForeColor = [System.Drawing.Color]::Gray
    $lblStatus.Size = New-Object System.Drawing.Size(970, 20)
    $lblStatus.Location = New-Object System.Drawing.Point(15, 40)
    $resultsForm.Controls.Add($lblStatus)
    
    # Results panel
    $panelResults = New-Object System.Windows.Forms.Panel
    $panelResults.Size = New-Object System.Drawing.Size(970, 600)
    $panelResults.Location = New-Object System.Drawing.Point(15, 65)
    $panelResults.BackColor = $panelColor
    $panelResults.BorderStyle = 'FixedSingle'
    $panelResults.AutoScroll = $true
    $resultsForm.Controls.Add($panelResults)
    
    $resultsForm.Show()
    
    # Check selected addresses
    $yPosition = 15
    $totalNight = 0
    $successCount = 0
    $allResults = @()
    
    for ($i = 0; $i -lt $selectedAddresses.Count; $i++) {
        $addr = $selectedAddresses[$i]
        $progressBar.Value = [int](($i + 1) / $selectedAddresses.Count * 100)
        $lblStatus.Text = "🔍 Checking $($i+1)/$($selectedAddresses.Count): $addr"
        $resultsForm.Refresh()
        
        try {
            $url = "https://mainnet.prod.gd.midnighttge.io/thaws/$addr/schedule"
            $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 10 -UseBasicParsing
            
            $data = $response
            
            if ($data.thaws -and $data.thaws.Count -gt 0) {
                $successCount++
                $totalAmount = 0
                
                foreach ($item in $data.thaws) {
                    $amount = $item.amount / 1e6
                    $totalAmount += $amount
                }
                
                $allResults += [PSCustomObject]@{
                    Address = $addr
                    Total = $totalAmount
                    Count = $data.thaws.Count
                }
                
                $totalNight += $totalAmount
            }
        } catch {
            # Skip on error
        }
        
        Start-Sleep -Milliseconds 300
    }
    
    # Display results
    $panelResults.Controls.Clear()
    
    # Title
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 13)
    $lblTitle.ForeColor = $primaryColor
    $lblTitle.Text = if ($Lang -eq "EN") { "📊 NIGHT SCHEDULE SUMMARY" } else { "📊 TÓM TẮT LỊCH TRẢ NIGHT" }
    $lblTitle.Size = New-Object System.Drawing.Size(950, 28)
    $lblTitle.Location = New-Object System.Drawing.Point(10, $yPosition)
    $panelResults.Controls.Add($lblTitle)
    $yPosition += 35
    
    # Overall stats
    $lblStats = New-Object System.Windows.Forms.Label
    $lblStats.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11)
    $lblStats.ForeColor = $successColor
    $statsText = if ($Lang -eq "EN") {
        "✅ Checked: $($selectedAddresses.Count) | Success: $successCount | Total NIGHT: $($totalNight.ToString("N0"))"
    } else {
        "✅ Kiểm tra: $($selectedAddresses.Count) | Thành công: $successCount | Tổng NIGHT: $($totalNight.ToString("N0"))"
    }
    $lblStats.Text = $statsText
    $lblStats.Size = New-Object System.Drawing.Size(950, 25)
    $lblStats.Location = New-Object System.Drawing.Point(10, $yPosition)
    $panelResults.Controls.Add($lblStats)
    $yPosition += 30
    
    # Divider
    $lblDiv = New-Object System.Windows.Forms.Label
    $lblDiv.BorderStyle = 'FixedSingle'
    $lblDiv.Size = New-Object System.Drawing.Size(950, 1)
    $lblDiv.Location = New-Object System.Drawing.Point(10, $yPosition)
    $panelResults.Controls.Add($lblDiv)
    $yPosition += 15
    
    # Details
    foreach ($result in $allResults) {
        $lblAddr = New-Object System.Windows.Forms.Label
        $lblAddr.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
        $lblAddr.ForeColor = $textColor
        $lblAddr.Text = "📌 Address: $($result.Address)"
        $lblAddr.Size = New-Object System.Drawing.Size(950, 22)
        $lblAddr.Location = New-Object System.Drawing.Point(10, $yPosition)
        $panelResults.Controls.Add($lblAddr)
        $yPosition += 25
        
        $lblAmount = New-Object System.Windows.Forms.Label
        $lblAmount.Font = New-Object System.Drawing.Font("Segoe UI", 10)
        $lblAmount.ForeColor = $accentColor
        $lblAmount.Text = "   💰 Total: $($result.Total.ToString("N0")) NIGHT | 📦 Batches: $($result.Count)"
        $lblAmount.Size = New-Object System.Drawing.Size(950, 20)
        $lblAmount.Location = New-Object System.Drawing.Point(10, $yPosition)
        $panelResults.Controls.Add($lblAmount)
        $yPosition += 25
    }
    
    $statusMsg = if ($Lang -eq "EN") { "✅ Completed!" } else { "✅ Hoàn thành!" }
    $lblStatus.Text = $statusMsg
    $progressBar.Value = 100
}

# --------- HISTORY BUTTON EVENT ---------
$btnHistory.Add_Click({
    Show-HistoryWindow
})

# --------- VIEW ALL BUTTON EVENT ---------
$btnViewAll.Add_Click({
    Show-ViewAllWindow
})

# --------- SHOW FORM ---------
$form.ShowDialog() | Out-Null
