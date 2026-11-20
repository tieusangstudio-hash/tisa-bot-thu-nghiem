# Cài TISA BOT BẢN THỬ NGHIỆM (Nhiều máy) trên Windows, chạy SONG SONG với TISA BOT đang có:
#   thư mục riêng (mặc định %USERPROFILE%\tisa-bot-thu), cổng riêng (mặc định 7790), dữ liệu Đội Quân riêng.
#   KHÔNG đụng TISA BOT cũ (cổng 7777).
#
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/tieusangstudio-hash/tisa-bot-thu-nghiem/main/packaging/thu-nghiem/cai-ban-thu.ps1 | iex"
#
# Tự khởi động cùng Windows qua lối tắt trong thư mục Startup. Gỡ: xóa lối tắt "TISA BOT thu" trong shell:startup rồi tắt cửa sổ đang chạy.
$ErrorActionPreference = "Stop"
$Repo = if ($env:TISA_REPO) { $env:TISA_REPO } else { "tieusangstudio-hash/tisa-bot-thu-nghiem" }
$Dir = if ($env:TISA_DIR) { $env:TISA_DIR } else { Join-Path $env:USERPROFILE "tisa-bot-thu" }
$Port = if ($env:TISA_PORT) { [int]$env:TISA_PORT } else { 7790 }
$BPort = $Port + 1
if ($Port -eq 7777) { throw "Cổng 7777 là của TISA BOT đang dùng. Chọn cổng khác." }

Write-Host "== Cài TISA BOT bản thử nghiệm vào $Dir, cổng $Port"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Thiếu Git. Cài: winget install --id Git.Git -e, mở lại PowerShell rồi chạy lại." }
$Py = $null
foreach ($c in @("py -3.12", "py -3.11", "python")) {
  $parts = $c.Split(" ")
  try {
    $v = & $parts[0] $parts[1..($parts.Length - 1)] -c "import sys; print(sys.version_info >= (3, 10))" 2>$null
    if ($v -eq "True") { $Py = $parts; break }
  } catch { }
}
if (-not $Py) { throw "Cần Python 3.10 trở lên. Cài: winget install --id Python.Python.3.12 -e, mở lại PowerShell rồi chạy lại." }

if (Test-Path (Join-Path $Dir ".git")) { git -C $Dir pull -q --ff-only } else { git clone -q --depth 1 "https://github.com/$Repo.git" $Dir }
$Venv = Join-Path $Dir ".venv\Scripts\python.exe"
if (-not (Test-Path $Venv)) { & $Py[0] $Py[1..($Py.Length - 1)] -m venv (Join-Path $Dir ".venv") }
Write-Host "   Đang cài thư viện Python (vài phút lần đầu)..."
& $Venv -m pip install -q --upgrade pip | Out-Null
& $Venv -m pip install -q -r (Join-Path $Dir "requirements.txt")
New-Item -ItemType Directory -Force -Path (Join-Path $Dir "_doi-quan\home") | Out-Null

$Cmd = Join-Path $Dir "chay-ban-thu.cmd"
@"
@echo off
set TISA_PORT=$Port
set TISA_BOARD_PORT=$BPort
set DOI_QUAN_HOME=$Dir\_doi-quan\home
set DOI_QUAN_ENV=$Dir\_doi-quan\.env
set TISA_CLAUDE_AUTO_UPDATE=0
cd /d "$Dir\server"
:lap
"$Venv" -m uvicorn main:app --host 127.0.0.1 --port $Port >> "$Dir\server\tisa.log" 2>&1
timeout /t 5 /nobreak > nul
goto lap
"@ | Set-Content -Encoding ASCII $Cmd

$Startup = [Environment]::GetFolderPath("Startup")
$Lnk = Join-Path $Startup "TISA BOT thu.lnk"
$Sh = New-Object -ComObject WScript.Shell
$S = $Sh.CreateShortcut($Lnk)
$S.TargetPath = $Cmd
$S.WorkingDirectory = (Join-Path $Dir "server")
$S.WindowStyle = 7
$S.Save()
Start-Process -FilePath $Cmd -WindowStyle Minimized
Write-Host "   Đang khởi động..."
$ok = $false
for ($i = 0; $i -lt 90; $i++) {
  try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 "http://127.0.0.1:$Port/health" | Out-Null; $ok = $true; break } catch { Start-Sleep 2 }
}
if ($ok) {
  Write-Host "== XONG. Mở http://127.0.0.1:$Port/ (lần đầu tạo tài khoản quản trị), rồi vào menu Nhiều máy."
  Start-Process "http://127.0.0.1:$Port/"
} else { Write-Host "Chưa thấy TISA BOT trả lời. Xem nhật ký: $Dir\server\tisa.log" }
