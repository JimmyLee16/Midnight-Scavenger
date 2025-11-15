# 🧰 Scavenger Donation Manager (GUI)

A lightweight Windows GUI tool for **signing and submitting Scavenger donations** using Midnight’s official API.  
Supports **single-send** and **batch mode**

---

## 📦 Requirements

- Windows PC with PowerShell + WinForms  
- Place these files in the same directory:
  - `solution_transfer_manual_gui.ps1`
  - `solution_donation.bat`
  - `cardano-signer.exe`source (https://github.com/gitmachtl/cardano-signer/releases/tag/v1.32.0)
- If PowerShell blocks execution:
  ```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
⚙️ How to Run
Launch the GUI
A. Just click solution_donation_manual_gui.bat
B. Directly via ps1 file

powershell
Copy code
```powershell
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -File .\solution_transfer_manual_gui.ps1
```

## 🖥️ Features

- Simple, clean GUI
- Select Original Address file
- Select Private key (.skey / .json)
- Check solution count
- Execute donation per address
- Batch Mode for multi-address processing
- Drag & Drop file support

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
