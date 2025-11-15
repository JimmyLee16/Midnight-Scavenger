<#
===========================================
PowerShell Cardano Full Flow
Manual Step-by-Step + Auto CIP-30 Signature
Bilingual: English & Vietnamese
===========================================
#>

param(
    [switch]$ForceGenerate,
    [switch]$UseTestnet,
    [switch]$AutoMode
)

try {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
    if ($scriptPath) { Set-Location -Path $scriptPath }
} catch { }

# Language selection
Write-Host "╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║           Cardano Address Generator - Language Selection          ║" -ForegroundColor Cyan
Write-Host "║           Tạo Địa Chỉ Cardano - Chọn Ngôn Ngữ                     ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Select your language / Chọn ngôn ngữ:"
Write-Host "  [1] English"
Write-Host "  [2] Tiếng Việt"
Write-Host ""
$langChoice = Read-Host "Enter choice / Nhập lựa chọn (1 or 2)"

$script:lang = if ($langChoice -eq "2") { "vi" } else { "en" }

# Language strings
$script:strings = @{
    en = @{
        # Mode selection
        modeTitle = "Select Mode"
        modeAuto = "  [1] Auto Mode - Quick generation (for advanced users)"
        modeManual = "  [2] Manual Mode - Step-by-step with navigation"
        modePrompt = "Enter choice (1 or 2)"
        
        # Common
        yes = "Y"
        no = "N"
        continue = "Continue"
        pressEnter = "Press Enter to continue"
        
        # Menu
        menuContinue = "[C] Continue to next step (default)"
        menuRedo = "[R] Redo this step"
        menuBack = "[B] Go back to previous step"
        menuGoto = "[G] Go to specific step (1-6)"
        menuQuit = "[Q] Quit"
        menuPrompt = "Enter choice"
        stepCompleted = "Step {0}: {1} - Completed"
        whatNext = "What would you like to do next?"
        
        # Step 0: Initialize
        welcomeTitle = "Cardano Address Generator - Interactive Flow"
        usageGuide = "USAGE GUIDE:"
        usageDesc = "  • This script will guide you through 6 steps to create Cardano addresses"
        usageNav = "  • After each step, you can:"
        usageNav1 = "    - Continue to next step"
        usageNav2 = "    - Redo current step"
        usageNav3 = "    - Go back to previous step"
        usageNav4 = "    - Jump to specific step"
        stepsTitle = "STEPS:"
        step1Desc = "  1. Select network (mainnet/testnet)"
        step2Desc = "  2. Setup mnemonic phrase (seed words)"
        step3Desc = "  3. Setup passphrase (optional)"
        step4Desc = "  4. Create root key from mnemonic"
        step5Desc = "  5. Create payment key and address"
        step6Desc = "  6. Create stake key and delegated address"
        step7Desc = "  7. Sign CIP-30 message for mining registration"
        securityTitle = "⚠️  SECURITY IMPORTANT:"
        security1 = "  • This script creates files containing private keys"
        security2 = "  • Keep these files safe and DO NOT share"
        security3 = "  • Delete temporary files after use"
        security4 = "  • Passphrase is NOT saved to disk"
        checkingExe = "Checking for cardano-address executable..."
        exeNotFound = "❌ cardano-address executable not found!"
        exeDownload = "   Please download and place it in the same folder."
        exeDownloadUrl = "   Download: https://github.com/input-output-hk/cardano-addresses/releases"
        exeFound = "✓ Found: {0}"
        cliNotFound = "⚠️  cardano-cli not found at: {0}"
        cliSkip = "   Step 7 (CIP-30 signing) will be skipped."
        signerNotFound = "⚠️  cardano-signer not found at: {0}"
        signerSkip = "   Step 7 (CIP-30 signing) will be skipped."
        pressStart = "Press Enter to start"
        
        # Auto mode
        autoModeTitle = "=== Auto Mode - Quick Generation ==="
        network = "Network: {0}"
        useTestnetPrompt = "Use testnet?"
        existingPhrase = "Use existing phrase.prv?"
        generatingMnemonic = "Generated new mnemonic -> phrase.prv"
        enterPassphrase = "Enter passphrase (optional):"
        passphrasePrompt = "passphrase"
        creatingRoot = "Creating root.xsk..."
        derivingPayment = "Deriving payment: {0}"
        derivingStake = "Deriving stake: {0}"
        delegationDone = "Address delegation done ✅"
        
        # Step 1: Network
        step1Title = "STEP 1: Select Network"
        selectNetwork = "Selected network: {0}"
        useTestnet = "Use testnet? (default No = mainnet)"
        
        # Step 2: Mnemonic
        step2Title = "STEP 2: Setup Mnemonic"
        phraseExists = "phrase.prv exists. Use existing file? (No = generate new)"
        usingExisting = "Using existing {0}"
        chooseMnemonic = "Choose how to set mnemonic:"
        mnemonicManual = "  1) manual - enter mnemonic manually"
        mnemonicAuto = "  2) auto   - generate new mnemonic"
        mnemonicFile = "  3) file   - use another existing file"
        mnemonicChoice = "Enter choice (manual/auto/file)"
        enterMnemonic = "Enter mnemonic words separated by space"
        mnemonicStored = "Mnemonic stored in variable."
        enterWordCount = "Enter number of words (9,12,15,18,21,24)"
        generatingMnemonicFile = "Generating mnemonic and saving to {0}..."
        failedGenerate = "Failed to generate mnemonic."
        mnemonicSaved = "Mnemonic saved to {0}"
        enterFilePath = "Enter path to existing mnemonic file"
        copiedMnemonic = "Copied mnemonic from {0}"
        fileNotFound = "File not found: {0}"
        invalidChoice = "Invalid choice."
        
        # Step 3: Passphrase
        step3Title = "STEP 3: Setup Passphrase"
        passphraseInfo = "If you want empty passphrase press Enter. Otherwise type passphrase."
        enterPassphraseHidden = "Enter passphrase (hidden)"
        emptyPassphrase = "Empty passphrase will be used."
        passphraseSet = "Passphrase set (not saved to disk)."
        
        # Step 4: Root Key
        step4Title = "STEP 4: Create Root Key"
        failedRoot = "Failed to create root.xsk."
        rootCreated = "root.xsk created successfully."
        
        # Step 5: Payment Key
        step5Title = "STEP 5: Create Payment Key and Address"
        enterStakeAccountIndex = "Enter stake account index (0 -> 2^31-1)"
        enterPayIndex = "Enter payment key index (0 -> 2^31-1)"
        derivingPaymentPath = "Deriving payment private key (path: {0})..."
        failedPaymentKey = "Failed to derive addr.xsk"
        exportingPaymentPub = "Exporting payment public key..."
        failedPaymentPub = "Failed to export addr.xvk"
        buildingPaymentAddr = "Building payment address..."
        failedPaymentAddr = "Failed to build payment.addr"
        paymentCreated = "Payment key and address created successfully."
        paymentAddress = "Payment Address: {0}"
        
        # Step 6: Stake Key
        step6Title = "STEP 6: Create Stake Key and Delegated Address"
        enterStakeIndex = "Enter stake key index (0 -> 2^31-1)"
        derivingStakePath = "Deriving stake private key (path: {0})..."
        failedStakeKey = "Failed to derive stake.xsk"
        exportingStakePub = "Exporting stake public key..."
        failedStakePub = "Failed to export stake.xvk"
        buildingStakeAddr = "Building stake address..."
        failedStakeAddr = "Failed to build stake.addr (non-fatal)"
        stakeAddrCreated = "Stake address created."
        buildingDelegated = "Building delegated/base address..."
        stakeEmpty = "stake.xvk is empty"
        failedDelegated = "Failed to build addr.delegated"
        stakeCreated = "Stake key and delegated address created successfully."
        stakeAddress = "Stake Address: {0}"
        delegatedAddress = "Delegated Address: {0}"
        
        # Step 7: CIP-30 Signing
        step7Title = "STEP 7: Sign CIP-30 Message"
        signingMessage = "Signing CIP-30 Message..."
        convertingKey = "Converting key format..."
        failedConvert = "Failed to convert key"
        signingCIP30 = "Signing message with CIP-30..."
        failedSign = "Failed to sign message"
        signatureCreated = "Signature created successfully."
        
        # Final
        completedTitle = "COMPLETED - MINING REGISTRATION"
        finalOutput = "==== FINAL OUTPUT (COPY THIS) ===="
        recoveryPhrase = "Recovery Phrase: {0}"
        privateKey = "Private Key: {0}"
        miningAddress = "Mining Address: {0}"
        scavengerMessage = "Scavenger Message: {0}"
        signature = "Signature: {0}"
        publicKey = "Public Key: {0}"
        filesCreated = "Files created in current folder:"
        file1 = "  📄 phrase.prv      - Mnemonic phrase"
        file2 = "  🔐 root.xsk        - Root private key"
        file3 = "  🔐 addr.xsk        - Payment private key"
        file4 = "  🔓 addr.xvk        - Payment public key"
        file5 = "  💳 payment.addr    - Payment address"
        file6 = "  🔐 stake.xsk       - Stake private key"
        file7 = "  🔓 stake.xvk       - Stake public key"
        file8 = "  🎯 stake.addr      - Stake address"
        file9 = "  ⭐ addr.delegated  - Delegated address"
        file10 = "  ✍️  signature.json - CIP-30 signature"
        securityNotesTitle = "⚠️  SECURITY NOTES:"
        secNote1 = "  • .xsk files contain private keys - NEVER share"
        secNote2 = "  • Backup phrase.prv and passphrase securely"
        secNote3 = "  • Delete temporary files after use"
        secNote4 = "  • Do not store private keys online"
        
        # Errors
        stepFailed = "Step {0} failed. Please try again."
        retryStep = "Retry this step?"
        alreadyFirstStep = "Already at first step."
        invalidStepNumber = "Invalid step number."
        quitting = "Quitting..."
        gotoPrompt = "Enter step number (1-7)"
        done = "Done! ✅"
    }
    vi = @{
        # Mode selection
        modeTitle = "Chọn Chế Độ"
        modeAuto = "  [1] Chế Độ Tự Động - Tạo nhanh (cho người dùng có kinh nghiệm)"
        modeManual = "  [2] Chế Độ Thủ Công - Từng bước với điều hướng"
        modePrompt = "Nhập lựa chọn (1 hoặc 2)"
        
        # Common
        yes = "C"
        no = "K"
        continue = "Tiếp tục"
        pressEnter = "Nhấn Enter để tiếp tục"
        
        # Menu
        menuContinue = "[C] Tiếp tục bước tiếp theo (mặc định)"
        menuRedo = "[R] Làm lại bước này"
        menuBack = "[B] Quay lại bước trước"
        menuGoto = "[G] Nhảy đến bước cụ thể (1-6)"
        menuQuit = "[Q] Thoát"
        menuPrompt = "Nhập lựa chọn"
        stepCompleted = "Bước {0}: {1} - Hoàn thành"
        whatNext = "Bạn muốn làm gì tiếp theo?"
        
        # Step 0: Initialize
        welcomeTitle = "Tạo Địa Chỉ Cardano - Hướng Dẫn Tương Tác"
        usageGuide = "HƯỚNG DẪN SỬ DỤNG:"
        usageDesc = "  • Script này sẽ hướng dẫn bạn tạo địa chỉ Cardano qua 7 bước"
        usageNav = "  • Sau mỗi bước, bạn có thể:"
        usageNav1 = "    - Tiếp tục bước tiếp theo"
        usageNav2 = "    - Làm lại bước hiện tại"
        usageNav3 = "    - Quay lại bước trước"
        usageNav4 = "    - Nhảy đến bước cụ thể"
        stepsTitle = "CÁC BƯỚC:"
        step1Desc = "  1. Chọn network (mainnet/testnet)"
        step2Desc = "  2. Thiết lập mnemonic phrase"
        step3Desc = "  3. Thiết lập passphrase (tùy chọn)"
        step4Desc = "  4. Tạo root key"
        step5Desc = "  5. Tạo payment key và address"
        step6Desc = "  6. Tạo stake key và delegated address"
        step7Desc = "  7. Ký CIP-30 message cho mining"
        securityTitle = "⚠️  BẢO MẬT QUAN TRỌNG:"
        security1 = "  • Script tạo các file chứa private keys"
        security2 = "  • Giữ file an toàn, KHÔNG chia sẻ"
        security3 = "  • Xóa file tạm sau khi dùng"
        security4 = "  • Passphrase không lưu vào disk"
        checkingExe = "Đang kiểm tra cardano-address..."
        exeNotFound = "❌ Không tìm thấy cardano-address!"
        exeDownload = "   Vui lòng tải và đặt cùng thư mục."
        exeDownloadUrl = "   Tải tại: https://github.com/input-output-hk/cardano-addresses/releases"
        exeFound = "✓ Tìm thấy: {0}"
        cliNotFound = "⚠️  Không tìm thấy cardano-cli tại: {0}"
        cliSkip = "   Bước 7 (ký CIP-30) sẽ bị bỏ qua."
        signerNotFound = "⚠️  Không tìm thấy cardano-signer tại: {0}"
        signerSkip = "   Bước 7 (ký CIP-30) sẽ bị bỏ qua."
        pressStart = "Nhấn Enter để bắt đầu"
        
        # Auto mode
        autoModeTitle = "=== Chế Độ Tự Động - Tạo Nhanh ==="
        network = "Network: {0}"
        useTestnetPrompt = "Dùng testnet?"
        existingPhrase = "Dùng phrase.prv hiện có?"
        generatingMnemonic = "Đã tạo mnemonic mới -> phrase.prv"
        enterPassphrase = "Nhập passphrase (tùy chọn):"
        passphrasePrompt = "passphrase"
        creatingRoot = "Đang tạo root.xsk..."
        derivingPayment = "Đang tạo payment: {0}"
        derivingStake = "Đang tạo stake: {0}"
        delegationDone = "Tạo địa chỉ delegation xong ✅"
        
        # Step 1: Network
        step1Title = "BƯỚC 1: Chọn Network"
        selectNetwork = "Đã chọn network: {0}"
        useTestnet = "Dùng testnet? (mặc định Không = mainnet)"
        
        # Step 2: Mnemonic
        step2Title = "BƯỚC 2: Thiết Lập Mnemonic"
        phraseExists = "phrase.prv đã tồn tại. Dùng file hiện có? (Không = tạo mới)"
        usingExisting = "Đang dùng file {0}"
        chooseMnemonic = "Chọn cách thiết lập mnemonic:"
        mnemonicManual = "  1) manual - nhập thủ công"
        mnemonicAuto = "  2) auto   - tạo mới tự động"
        mnemonicFile = "  3) file   - dùng file khác"
        mnemonicChoice = "Nhập lựa chọn (manual/auto/file)"
        enterMnemonic = "Nhập các từ mnemonic cách nhau bởi dấu cách"
        mnemonicStored = "Mnemonic đã lưu vào biến."
        enterWordCount = "Nhập số từ (9,12,15,18,21,24)"
        generatingMnemonicFile = "Đang tạo mnemonic và lưu vào {0}..."
        failedGenerate = "Không thể tạo mnemonic."
        mnemonicSaved = "Mnemonic đã lưu vào {0}"
        enterFilePath = "Nhập đường dẫn file mnemonic"
        copiedMnemonic = "Đã copy mnemonic từ {0}"
        fileNotFound = "Không tìm thấy file: {0}"
        invalidChoice = "Lựa chọn không hợp lệ."
        
        # Step 3: Passphrase
        step3Title = "BƯỚC 3: Thiết Lập Passphrase"
        passphraseInfo = "Nếu muốn passphrase trống, nhấn Enter. Ngược lại nhập passphrase."
        enterPassphraseHidden = "Nhập passphrase (ẩn)"
        emptyPassphrase = "Sẽ dùng passphrase trống."
        passphraseSet = "Đã thiết lập passphrase (không lưu disk)."
        
        # Step 4: Root Key
        step4Title = "BƯỚC 4: Tạo Root Key"
        failedRoot = "Không thể tạo root.xsk."
        rootCreated = "root.xsk đã tạo thành công."
        
        # Step 5: Payment Key
        step5Title = "BƯỚC 5: Tạo Payment Key và Address"
        enterStakeAccountIndex = "Nhập stake account index (0 -> 2^31-1)"
        enterPayIndex = "Nhập payment key index (0 -> 2^31-1)"
        derivingPaymentPath = "Đang tạo payment private key (path: {0})..."
        failedPaymentKey = "Không thể tạo addr.xsk"
        exportingPaymentPub = "Đang xuất payment public key..."
        failedPaymentPub = "Không thể xuất addr.xvk"
        buildingPaymentAddr = "Đang tạo payment address..."
        failedPaymentAddr = "Không thể tạo payment.addr"
        paymentCreated = "Payment key và address đã tạo thành công."
        paymentAddress = "Payment Address: {0}"
        
        # Step 6: Stake Key
        step6Title = "BƯỚC 6: Tạo Stake Key và Delegated Address"
        enterStakeIndex = "Nhập stake key index (0 -> 2^31-1)"
        derivingStakePath = "Đang tạo stake private key (path: {0})..."
        failedStakeKey = "Không thể tạo stake.xsk"
        exportingStakePub = "Đang xuất stake public key..."
        failedStakePub = "Không thể xuất stake.xvk"
        buildingStakeAddr = "Đang tạo stake address..."
        failedStakeAddr = "Không thể tạo stake.addr (không nghiêm trọng)"
        stakeAddrCreated = "Stake address đã tạo."
        buildingDelegated = "Đang tạo delegated/base address..."
        stakeEmpty = "stake.xvk trống"
        failedDelegated = "Không thể tạo addr.delegated"
        stakeCreated = "Stake key và delegated address đã tạo thành công."
        stakeAddress = "Stake Address: {0}"
        delegatedAddress = "Delegated Address: {0}"
        
        # Step 7: CIP-30 Signing
        step7Title = "BƯỚC 7: Ký CIP-30 Message"
        signingMessage = "Đang ký CIP-30 Message..."
        convertingKey = "Đang chuyển đổi định dạng key..."
        failedConvert = "Không thể chuyển đổi key"
        signingCIP30 = "Đang ký message với CIP-30..."
        failedSign = "Không thể ký message"
        signatureCreated = "Signature đã tạo thành công."
        
        # Final
        completedTitle = "HOÀN THÀNH - ĐĂNG KÝ MINING"
        finalOutput = "==== KẾT QUẢ CUỐI CÙNG (COPY CÁI NÀY) ===="
        recoveryPhrase = "Recovery Phrase: {0}" // đây là code mẫu lưu ý khi sử dụng hãy xóa nó đi
        privateKey = "Private Key: {0}" // đây là code mẫu lưu ý khi sử dụng hãy xóa nó đi
        miningAddress = "Mining Address: {0}"
        scavengerMessage = "Scavenger Message: {0}"
        signature = "Signature: {0}"
        publicKey = "Public Key: {0}"
        filesCreated = "Các file đã tạo:"
        file1 = "  📄 phrase.prv      - Mnemonic phrase"
        file2 = "  🔐 root.xsk        - Root private key"
        file3 = "  🔐 addr.xsk        - Payment private key"
        file4 = "  🔓 addr.xvk        - Payment public key"
        file5 = "  💳 payment.addr    - Payment address"
        file6 = "  🔐 stake.xsk       - Stake private key"
        file7 = "  🔓 stake.xvk       - Stake public key"
        file8 = "  🎯 stake.addr      - Stake address"
        file9 = "  ⭐ addr.delegated  - Delegated address"
        file10 = "  ✍️  signature.json - CIP-30 signature"
        securityNotesTitle = "⚠️  LƯU Ý BẢO MẬT:"
        secNote1 = "  • File .xsk chứa private keys - TUYỆT ĐỐI KHÔNG chia sẻ"
        secNote2 = "  • Sao lưu phrase.prv và passphrase an toàn"
        secNote3 = "  • Xóa file tạm sau khi dùng"
        secNote4 = "  • Không lưu private keys online"
        
        # Errors
        stepFailed = "Bước {0} thất bại. Vui lòng thử lại."
        retryStep = "Thử lại bước này?"
        alreadyFirstStep = "Đã ở bước đầu tiên."
        invalidStepNumber = "Số bước không hợp lệ."
        quitting = "Đang thoát..."
        gotoPrompt = "Nhập số bước (1-7)"
        done = "Xong! ✅"
    }
}

function Get-Text($key) {
    return $script:strings[$script:lang][$key]
}

function Prompt-YesNo($msg, $defaultYes=$true) {
    $choice = Read-Host "$msg [Y/N]"
    if ([string]::IsNullOrWhiteSpace($choice)) { return $defaultYes }
    return $choice.Trim().ToUpper().StartsWith('Y')
}

function Show-StepMenu($stepName, $currentStep) {
    Write-Host "`n─────────────────────────────────────────────────────────────────────" -ForegroundColor Yellow
    Write-Host ("✓ " + (Get-Text "stepCompleted") -f $currentStep, $stepName) -ForegroundColor Green
    Write-Host "─────────────────────────────────────────────────────────────────────" -ForegroundColor Yellow
    Write-Host (Get-Text "whatNext")
    Write-Host (Get-Text "menuContinue")
    Write-Host (Get-Text "menuRedo")
    Write-Host (Get-Text "menuBack")
    Write-Host (Get-Text "menuGoto")
    Write-Host (Get-Text "menuQuit")
    
    $choice = Read-Host (Get-Text "menuPrompt")
    if ([string]::IsNullOrWhiteSpace($choice)) { return @{action='continue'} }
    
    switch ($choice.Trim().ToUpper()) {
        'C' { return @{action='continue'} }
        'R' { return @{action='redo'} }
        'B' { return @{action='back'} }
        'G' { 
            $targetStep = Read-Host (Get-Text "gotoPrompt")
            return @{action='goto'; step=[int]$targetStep}
        }
        'Q' { return @{action='quit'} }
        default { return @{action='continue'} }
    }
}

function Step-Initialize {
    Write-Host "`n╔════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host ("║  " + (Get-Text "welcomeTitle").PadRight(66) + "║") -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    
    Write-Host ("`n" + (Get-Text "usageGuide")) -ForegroundColor Yellow
    Write-Host (Get-Text "usageDesc")
    Write-Host (Get-Text "usageNav")
    Write-Host (Get-Text "usageNav1")
    Write-Host (Get-Text "usageNav2")
    Write-Host (Get-Text "usageNav3")
    Write-Host (Get-Text "usageNav4")
    Write-Host ""
    Write-Host (Get-Text "stepsTitle") -ForegroundColor Yellow
    Write-Host (Get-Text "step1Desc")
    Write-Host (Get-Text "step2Desc")
    Write-Host (Get-Text "step3Desc")
    Write-Host (Get-Text "step4Desc")
    Write-Host (Get-Text "step5Desc")
    Write-Host (Get-Text "step6Desc")
    Write-Host (Get-Text "step7Desc")
    Write-Host ""
    Write-Host (Get-Text "securityTitle") -ForegroundColor Red
    Write-Host (Get-Text "security1")
    Write-Host (Get-Text "security2")
    Write-Host (Get-Text "security3")
    Write-Host (Get-Text "security4")
    Write-Host ""
    
    # Check cardano-address
    Write-Host (Get-Text "checkingExe") -ForegroundColor Cyan
    $exePaths = @(".\cardano-address.exe", ".\cardano-address")
    $script:cardanoExe = $null
    foreach ($p in $exePaths) {
        if (Test-Path $p) { $script:cardanoExe = $p; break }
    }
    if (-not $script:cardanoExe) {
        Write-Host ""
        Write-Error (Get-Text "exeNotFound")
        Write-Host (Get-Text "exeDownload") -ForegroundColor Yellow
        Write-Host (Get-Text "exeDownloadUrl") -ForegroundColor Yellow
        return $false
    }
    Write-Host ((Get-Text "exeFound") -f $script:cardanoExe) -ForegroundColor Green
    
    # Check cardano-cli (optional for step 7)
    $script:cliPath = ".\cardano-cli-win64\cardano-cli.exe"
    if (-not (Test-Path $script:cliPath)) {
        Write-Host ((Get-Text "cliNotFound") -f $script:cliPath) -ForegroundColor Yellow
        Write-Host (Get-Text "cliSkip") -ForegroundColor Yellow
        $script:canSign = $false
    } else {
        $script:canSign = $true
    }
    
    # Check cardano-signer (optional for step 7)
    $script:signerPath = ".\cardano-signer.exe"
    if (-not (Test-Path $script:signerPath)) {
        Write-Host ((Get-Text "signerNotFound") -f $script:signerPath) -ForegroundColor Yellow
        Write-Host (Get-Text "signerSkip") -ForegroundColor Yellow
