Add-Type -AssemblyName PresentationFramework

# === FIX WORKING DIRECTORY ===
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path


# === GUI WINDOW (KHAI BÁO TRƯỚC) ===
$window = New-Object System.Windows.Window
$window.Title = "Midnight Sign - Multi Address Tool"
$window.Width = 650
$window.Height = 520
$window.WindowStartupLocation = "CenterScreen"
$window.ResizeMode = "CanResize"


# === POPUP INPUT BOX (KHAI BÁO SAU GUI) ===
function Show-InputPopup($title, $message) {
    $inputWindow = New-Object System.Windows.Window
    $inputWindow.Title = $title
    $inputWindow.Width = 350
    $inputWindow.Height = 180
    $inputWindow.WindowStartupLocation = "CenterOwner"
    $inputWindow.ResizeMode = "NoResize"
    $inputWindow.Owner = $window

    $grid = New-Object System.Windows.Controls.Grid
    $grid.Margin = "10"
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))
    $grid.RowDefinitions.Add((New-Object System.Windows.Controls.RowDefinition))

    $lbl = New-Object System.Windows.Controls.TextBlock
    $lbl.Text = $message
    $lbl.Margin = "5"
    $lbl.FontSize = 14
    $grid.AddChild($lbl)
    [System.Windows.Controls.Grid]::SetRow($lbl, 0)

    $txt = New-Object System.Windows.Controls.TextBox
    $txt.Margin = "5"
    $txt.FontSize = 16
    $grid.AddChild($txt)
    [System.Windows.Controls.Grid]::SetRow($txt, 1)

    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = "OK"
    $btn.FontSize = 16
    $btn.Margin = "5"
    $btn.Height = 35
    $grid.AddChild($btn)
    [System.Windows.Controls.Grid]::SetRow($btn, 2)

    $btn.Add_Click({
        if ($txt.Text -match '^\d+$') {
            $inputWindow.Tag = $txt.Text
            $inputWindow.Close()
        } else {
            [System.Windows.MessageBox]::Show("Hãy nhập số hợp lệ", "Lỗi", "OK", "Error")
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
function Invoke-ScriptWithLog($scriptFile, $paramValue) {

    $logBox.AppendText("▶ Running script:`n$scriptFile`nWith param: $paramValue`n`n")

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptFile`" -N $paramValue"
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
    $count = Show-InputPopup "Nhập số lượng address" "Nhập số lượng address muốn tạo:"
    if ($count) {
        Invoke-ScriptWithLog "$ScriptDir\midnightsigninformulti.ps1" $count
    }
})

# START
$window.ShowDialog() | Out-Null
