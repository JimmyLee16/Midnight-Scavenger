🧰 Scavenger Donation Manager (GUI)

A lightweight Windows GUI tool for signing and submitting Scavenger donations using Midnight’s official API.
Supports single send and batch mode, with colored logs and automatic CSV/TXT export.

📦 Requirements

Windows machine (PowerShell with WinForms).

Place these files in the same directory:

solution_transfer_manual_gui.ps1

cardano-signer.exe (from Cardano Signer repo)

If PowerShell blocks script execution:

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

⚙️ How to Run
Launch the GUI
powershell -ExecutionPolicy Bypass -File .\solution_transfer_manual_gui.ps1


The GUI will open immediately.

🖥️ Features

Clean, minimal GUI

Select Original Address file

Select Private key (.skey / .json)

Check solution count

Execute per-address donation

Batch Mode for multi-address operations

Drag & Drop support

Colored log viewer

Auto export:

TXT for single run

CSV for batch mode

🔄 How It Works

Tool uses cardano-signer to create signatures locally.

Submits request to the official Midnight Scavenger API:

https://scavenger.prod.gd.midnighttge.io


Batch mode executes everything sequentially and generates a final CSV report.

⚠️ Notes

Private keys never leave your machine.

Review the script if you need full transparency.

Common issues:

Missing cardano-signer.exe

PowerShell execution policy blocked

Wrong file paths or malformed address list

🔮 Roadmap

v1.0 — Stable GUI — Done

v1.1 — Auto-resize log panel — Planned

v1.2 — Custom API endpoint — Planned

⚖️ Disclaimer

This tool is provided for community use without warranty.
You are fully responsible for your private key and execution environment.

🌐 Community

👉 Cardano ADA Vietnam — https://t.me/ADA_VIET

🇻🇳 Scavenger Donation Manager (GUI)

Công cụ GUI gọn nhẹ trên Windows để ký và gửi donation Scavenger qua API chính thức của Midnight.
Hỗ trợ gửi từng địa chỉ hoặc gửi hàng loạt, có log màu và tự tạo file TXT/CSV.

📦 Chuẩn bị

Máy Windows có PowerShell hỗ trợ WinForms

Đặt các file sau chung một thư mục:

solution_transfer_manual_gui.ps1

cardano-signer.exe

Nếu PowerShell chặn chạy script:

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

⚙️ Cách chạy
Mở GUI
powershell -ExecutionPolicy Bypass -File .\solution_transfer_manual_gui.ps1


GUI xuất hiện ngay.

🖥️ Tính năng

Giao diện đơn giản, dễ dùng

Chọn file Original Address

Chọn file Private key (.skey / .json)

Check số lượng solution

Execute donation theo từng địa chỉ

Batch Mode để chạy hàng loạt

Hỗ trợ kéo–thả file

Log có màu

Xuất:

TXT cho từng lần chạy

CSV cho batch

🔄 Cơ chế hoạt động

Tool dùng cardano-signer để ký cục bộ.

Gửi request đến API Scavenger:

https://scavenger.prod.gd.midnighttge.io


Batch mode chạy tuần tự và xuất CSV cuối cùng.

⚠️ Lưu ý

Private key không bị gửi ra ngoài.

Nên tự kiểm tra code nếu muốn an tâm.

Lỗi thường gặp:

Thiếu cardano-signer.exe

Bị block bởi ExecutionPolicy

Sai đường dẫn hoặc format file

🔮 Roadmap

v1.0 — GUI hoàn chỉnh — Done

v1.1 — Auto-resize panel log — Planned

v1.2 — Tuỳ chỉnh endpoint — Planned

⚖️ Miễn trừ trách nhiệm

Công cụ được phát hành miễn phí, không kèm bất kỳ bảo đảm nào.
Người dùng tự chịu trách nhiệm về private key và môi trường chạy.

🌐 Cộng đồng

👉 Cardano ADA Vietnam — https://t.me/ADA_VIET
