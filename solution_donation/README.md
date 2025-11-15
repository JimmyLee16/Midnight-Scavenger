# 🧰 Scavenger Donation Manager (GUI)

A lightweight Windows GUI tool for **signing and submitting Scavenger donations** using Midnight’s official API.  
Supports **single-send** and **batch mode**, with colored logs and automatic CSV/TXT export.

---

## 📦 Requirements

- Windows PC with PowerShell + WinForms  
- Place these files in the same directory:
  - `solution_transfer_manual_gui.ps1`
  - `solution_donation_manual_gui.bat`
  - `cardano-signer.exe`
- If PowerShell blocks execution:
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
⚙️ How to Run
Launch the GUI
A. Just click solution_donation_manual_gui.bat
B. Directly via ps1 file

powershell
Copy code
powershell -ExecutionPolicy Bypass -File .\solution_transfer_manual_gui.ps1

🖥️ Features
Simple, clean GUI

Select Original Address file

Select Private key (.skey / .json)

Check solution count

Execute donation per address

Batch Mode for multi-address processing

Drag & Drop file support

Colored log viewer

Auto export:

TXT (individual runs)

CSV (batch mode)

🔄 How It Works
Uses cardano-signer for local signature generation

Submits signed request to Midnight Scavenger API:

arduino
Copy code
https://scavenger.prod.gd.midnighttge.io
Batch mode processes each address sequentially and generates a summary CSV.

⚠️ Notes
Private keys never leave your machine

Review the script if you want full transparency

Common issues:

Missing cardano-signer.exe

Execution policy blocked

Invalid file paths / malformed list

🔮 Roadmap
v1.0 — Stable GUI — Done

v1.1 — Auto-resize log panel — Planned

v1.2 — Custom API endpoint — Planned

⚖️ Disclaimer
This tool is provided to the community as-is, without warranty.
Use at your own risk.

🌐 Community
👉 Cardano ADA Vietnam — https://t.me/ADA_VIET

🇻🇳 Scavenger Donation Manager (GUI)
Công cụ GUI gọn nhẹ trên Windows để ký và gửi donation Scavenger qua API chính thức của Midnight.
Hỗ trợ gửi từng địa chỉ hoặc chạy hàng loạt, có log màu và tự xuất TXT/CSV.

📦 Chuẩn bị
Máy Windows với PowerShell + WinForms

Đặt chung thư mục:

solution_transfer_manual_gui.ps1

cardano-signer.exe

Nếu bị chặn:

powershell
Copy code
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
⚙️ Cách chạy
Mở GUI
powershell
Copy code
powershell -ExecutionPolicy Bypass -File .\solution_transfer_manual_gui.ps1
🖥️ Tính năng
Giao diện đơn giản

Chọn file Original Address

Chọn Private key (.skey / .json)

Check số lượng solution

Execute donation

Batch Mode để chạy nhiều địa chỉ

Kéo–thả file

Log có màu

Xuất:

TXT cho từng lần chạy

CSV cho batch mode

🔄 Cơ chế hoạt động
Tool dùng cardano-signer để ký cục bộ

Gửi request đến API:

arduino
Copy code
https://scavenger.prod.gd.midnighttge.io
Batch xử lý tuần tự và xuất CSV tổng kết.

⚠️ Lưu ý
Private key không rời khỏi máy

Có thể tự kiểm tra code để an tâm

Lỗi thường gặp:

Thiếu cardano-signer.exe

Bị block bởi ExecutionPolicy

Sai đường dẫn / file lỗi format

🔮 Roadmap
v1.0 — GUI hoàn chỉnh — Done

v1.1 — Auto-resize panel log — Planned

v1.2 — Endpoint tùy chỉnh — Planned

⚖️ Miễn trừ trách nhiệm
Công cụ cung cấp miễn phí, không bảo đảm.
Người dùng tự chịu trách nhiệm với private key & môi trường chạy.

🌐 Cộng đồng
👉 Cardano ADA Vietnam — https://t.me/ADA_VIET

yaml
Copy code

---

Nếu bạn muốn tôi **thêm badges (shields.io)**, **ảnh screenshot GUI**, hoặc **tạo mục "Folder Structure"** thì 
